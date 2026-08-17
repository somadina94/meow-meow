import { classifyError } from "@/lib/errors";
import { useState, useEffect, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { toast } from 'sonner';
import { Users, Video, Radio, Loader2, RefreshCw, Globe } from 'lucide-react';
import { cn } from '@/lib/utils';
import { getFlowerImage } from '@/assets/flowers';
import { PrivateGroupCallWindow } from './PrivateGroupCallWindow';
import { MAX_PARTICIPANTS } from '@/hooks/usePrivateGroupCall';

interface PrivateGroup {
  id: string; owner_id: string; name: string; description: string | null;
  min_gift_amount: number; access_type: string; is_active: boolean; is_live: boolean;
  stream_id: string | null; participant_count: number; current_host_id: string | null;
  current_host_name: string | null; owner_language: string | null; updated_at: string;
  created_at: string;
}

/** A live "row" rendered in the list — one per active host. */
interface LiveHostRow {
  group: PrivateGroup;
  host_id: string;
  host_name: string;
  host_number: number | null;
  host_language: string | null;
  participant_count: number;
}

interface AvailableGroupsSectionProps {
  currentUserId: string; userName: string; userPhoto: string | null;
}

const MIN_BALANCE_MINUTES = 5;
const RATE_PER_MINUTE = 4;

export function AvailableGroupsSection({ currentUserId, userName, userPhoto }: AvailableGroupsSectionProps) {
  const [rows, setRows] = useState<LiveHostRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeRow, setActiveRow] = useState<LiveHostRow | null>(null);
  const [activeGroupStream, setActiveGroupStream] = useState<MediaStream | null>(null);
  const [joiningKey, setJoiningKey] = useState<string | null>(null);
  const [walletBalance, setWalletBalance] = useState(0);

  const activeRowRef = useRef(activeRow);
  activeRowRef.current = activeRow;

  useEffect(() => {
    fetchRows();
    fetchWalletBalance();
    const channel = supabase
      .channel('available-groups-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'group_active_hosts' }, () => fetchRows())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'private_groups' }, () => fetchRows())
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'wallet_transactions', filter: `user_id=eq.${currentUserId}` }, () => {
        fetchWalletBalance();
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [currentUserId]);

  const fetchRows = async () => {
    try {
      const { data: hosts, error: hErr } = await supabase
        .from('group_active_hosts')
        .select('group_id, host_id, host_name, host_language, participant_count')
        .eq('is_active', true);
      if (hErr) throw hErr;

      const list = (hosts as any[]) || [];
      if (list.length === 0) { setRows([]); return; }

      const groupIds = Array.from(new Set(list.map(h => h.group_id)));
      const hostIds = Array.from(new Set(list.map(h => h.host_id)));
      const [{ data: groups }, { data: hostProfiles }] = await Promise.all([
        supabase.from('private_groups').select('*').in('id', groupIds),
        supabase.from('profiles').select('id, host_number').in('id', hostIds),
      ]);

      const groupMap = new Map<string, PrivateGroup>();
      (groups as any[] || []).forEach(g => groupMap.set(g.id, g));
      const hostNumberMap = new Map<string, number | null>();
      (hostProfiles as any[] || []).forEach(p => hostNumberMap.set(p.id, p.host_number ?? null));

      const built: LiveHostRow[] = list
        .map(h => {
          const g = groupMap.get(h.group_id);
          if (!g) return null;
          return {
            group: g,
            host_id: h.host_id,
            host_name: h.host_name || 'Host',
            host_number: hostNumberMap.get(h.host_id) ?? null,
            host_language: h.host_language || null,
            participant_count: h.participant_count || 0,
          } as LiveHostRow;
        })
        .filter((x): x is LiveHostRow => x !== null)
        .sort((a, b) => a.group.name.localeCompare(b.group.name));

      setRows(built);

      // If host I joined ended their session, drop me
      if (activeRowRef.current) {
        const stillLive = list.some(h => h.host_id === activeRowRef.current!.host_id && h.group_id === activeRowRef.current!.group.id);
        if (!stillLive) {
          toast.info('Host ended the live session');
          setActiveRow(null);
        }
      }
    } catch (error) {
      console.error('Error fetching live hosts:', error);
      toast.error('Groups unavailable', { description: 'Unable to load live hosts. Please refresh.' });
    } finally { setIsLoading(false); }
  };

  const fetchWalletBalance = async () => {
    try {
      // Use canonical SoT RPC (wallet_transactions), not legacy wallets.balance column
      const { data } = await supabase.rpc('get_men_wallet_balance', { p_user_id: currentUserId });
      if (data) {
        const bd = data as Record<string, number>;
        setWalletBalance(Number(bd.balance) || 0);
      }
    } catch (err) { console.error('[AvailableGroups] fetchWalletBalance error:', err); }
  };

  const handleJoinHost = async (row: LiveHostRow) => {
    const minBalance = RATE_PER_MINUTE * MIN_BALANCE_MINUTES;
    if (walletBalance < minBalance) {
      toast.error(`Insufficient balance. You need at least ₹${minBalance} (${MIN_BALANCE_MINUTES} minutes) to join.`);
      return;
    }
    if (row.participant_count >= MAX_PARTICIPANTS) {
      toast.error(`This host's room is full (max ${MAX_PARTICIPANTS} participants)`);
      return;
    }

    const key = `${row.group.id}:${row.host_id}`;
    setJoiningKey(key);
    let preStream: MediaStream | null = null;
    try {
      preStream = await navigator.mediaDevices.getUserMedia({
        video: false,
        audio: { echoCancellation: true, noiseSuppression: true },
      });
      preStream.getAudioTracks().forEach(t => { t.enabled = false; });
    } catch (mediaErr) {
      console.error('[AvailableGroups] Pre-acquire audio failed:', mediaErr);
      toast.error('Could not access microphone. Please allow access.');
      setJoiningKey(null); return;
    }

    try {
      // Atomic join (existing RPC keeps participant_count consistent)
      const { data: joinResult, error: joinError } = await supabase.rpc('join_group_atomic', {
        p_group_id: row.group.id, p_user_id: currentUserId, p_max_participants: MAX_PARTICIPANTS,
      });
      if (joinError) throw joinError;
      const result = joinResult as { success: boolean; error?: string; host_id?: string };
      if (!result.success) {
        toast.error(result.error || 'Could not join group');
        preStream.getTracks().forEach(t => t.stop());
        setJoiningKey(null);
        return;
      }
      // joined_host_id is now set atomically inside join_group_atomic RPC.
      // Defensive sync in case the host changed between fetch and join.
      if (result.host_id && result.host_id !== row.host_id) {
        console.warn('[AvailableGroups] Host changed during join:', row.host_id, '→', result.host_id);
      }

      setActiveGroupStream(preStream);
      setActiveRow(row);
    } catch (error: any) {
      preStream.getTracks().forEach(t => t.stop());
      toast.error('Could not join host', { description: classifyError(error, 'join the host').message });
    } finally { setJoiningKey(null); }
  };

  const handleLeaveGroup = async () => {
    if (activeRow) {
      if (activeGroupStream) { activeGroupStream.getTracks().forEach(t => t.stop()); setActiveGroupStream(null); }
      const groupId = activeRow.group.id;
      try {
        const { error } = await supabase.rpc('leave_group_atomic', { p_group_id: groupId, p_user_id: currentUserId });
        if (error) {
          console.warn('[AvailableGroups] leave_group_atomic RPC failed, fallback:', error);
          await supabase.from('group_memberships').update({ has_access: false, joined_host_id: null })
            .eq('group_id', groupId).eq('user_id', currentUserId);
        }
      } catch (e) { console.error('[AvailableGroups] Leave group error:', e); }
      fetchRows();
    }
    setActiveRow(null);
  };

  if (isLoading) return <div className="animate-pulse h-32 bg-muted/30 rounded-lg" />;

  const minBalance = RATE_PER_MINUTE * MIN_BALANCE_MINUTES;
  const hasEnoughBalance = walletBalance >= minBalance;

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center justify-between bg-primary text-primary-foreground px-4 py-2.5 rounded-t-xl -mx-1">
        <h3 className="text-sm font-semibold flex items-center gap-2">
          <Video className="h-4 w-4" />
          Live Hosts
        </h3>
        <div className="flex items-center gap-2">
          <Badge className="bg-primary-foreground/20 text-primary-foreground border-0 text-[10px] h-5">
            {rows.length} Live
          </Badge>
          <button onClick={() => { setIsLoading(true); fetchRows(); fetchWalletBalance(); }} className="hover:bg-primary-foreground/10 rounded-full p-1.5 transition-colors">
            <RefreshCw className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      {/* Balance warning */}
      {!hasEnoughBalance && (
        <div className="flex items-center gap-2 px-3 py-2 bg-red-50 dark:bg-red-950/30 rounded-lg text-xs text-red-700 dark:text-red-300 border border-red-200 dark:border-red-800">
          <span>⚠️</span>
          <span>Need at least ₹{minBalance} to join. Please recharge.</span>
        </div>
      )}

      {/* Empty state */}
      {rows.length === 0 && (
        <div className="py-10 text-center bg-card rounded-xl border border-border/60">
          <div className="w-14 h-14 rounded-full bg-muted mx-auto mb-3 flex items-center justify-center">
            <Video className="h-7 w-7 text-muted-foreground/50" />
          </div>
          <p className="text-sm font-medium text-muted-foreground">No live hosts right now</p>
          <p className="text-xs text-muted-foreground/70 mt-1">Hosts will appear when they go live in a group</p>
        </div>
      )}

      {/* One row per live host */}
      {rows.length > 0 && (
        <div className="divide-y divide-border/50 bg-card rounded-xl overflow-hidden border border-border/60">
          {rows.map((row) => {
            const isFull = row.participant_count >= MAX_PARTICIPANTS;
            const key = `${row.group.id}:${row.host_id}`;
            const isJoining = joiningKey === key;

            return (
              <div
                key={key}
                className="flex items-center gap-3 px-3 py-3 transition-colors hover:bg-muted/40"
              >
                {/* Avatar with live ring */}
                <div className="relative shrink-0">
                  <div className="w-11 h-11 rounded-full overflow-hidden ring-2 ring-accent bg-muted">
                    <img
                      src={getFlowerImage(row.group.name)}
                      alt={row.group.name}
                      width={44}
                      height={44}
                      loading="lazy"
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-accent rounded-full flex items-center justify-center">
                    <Radio className="h-2 w-2 text-accent-foreground animate-pulse" />
                  </div>
                </div>

                {/* Info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <span className="font-semibold text-sm text-foreground truncate">{row.group.name}</span>
                    <Badge className="bg-accent text-accent-foreground text-[9px] h-4 px-1.5 border-0 shrink-0">
                      LIVE
                    </Badge>
                    {row.host_language && (
                      <Badge variant="outline" className="text-[9px] h-4 px-1.5 shrink-0 gap-0.5">
                        <Globe className="h-2 w-2" /> {row.host_language}
                      </Badge>
                    )}
                  </div>
                  <p className="text-xs text-primary font-medium truncate mt-0.5">
                    📹 {row.host_number ? `Host #${row.host_number} · ` : ''}{row.host_name}
                  </p>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="text-[10px] text-muted-foreground flex items-center gap-0.5">
                      <Users className="h-2.5 w-2.5" /> {row.participant_count}/{MAX_PARTICIPANTS}
                    </span>
                    <span className="text-[10px] text-muted-foreground">
                      💰 ₹{RATE_PER_MINUTE}/min
                    </span>
                  </div>
                </div>

                {/* Join button */}
                <div className="shrink-0">
                  <Button
                    size="sm"
                    className={cn(
                      "h-8 text-xs rounded-full px-4 gap-1",
                      isFull || !hasEnoughBalance
                        ? "bg-muted text-muted-foreground cursor-not-allowed"
                        : "bg-accent hover:bg-accent/80 text-accent-foreground"
                    )}
                    onClick={() => handleJoinHost(row)}
                    disabled={!hasEnoughBalance || isFull || isJoining}
                  >
                    {isJoining ? <Loader2 className="h-3 w-3 animate-spin" /> : <Video className="h-3 w-3" />}
                    {isFull ? 'Full' : !hasEnoughBalance ? `₹${minBalance}+` : isJoining ? '...' : 'Join'}
                  </Button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {activeRow && (
        <PrivateGroupCallWindow
          group={activeRow.group}
          currentUserId={currentUserId}
          userName={userName}
          userPhoto={userPhoto}
          preAcquiredStream={activeGroupStream}
          onClose={handleLeaveGroup}
          isOwner={false}
        />
      )}
    </div>
  );
}
