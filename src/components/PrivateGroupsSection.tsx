import { classifyError } from "@/lib/errors";
import { useState, useEffect, useRef, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { toast } from 'sonner';
import { Users, Video, MessageCircle, Radio, Square, RefreshCw, Globe } from 'lucide-react';
import { PrivateGroupCallWindow } from './PrivateGroupCallWindow';
import { MAX_PARTICIPANTS } from '@/hooks/usePrivateGroupCall';
import { INDIAN_LANGUAGES } from '@/data/supportedLanguages';
import { cn } from '@/lib/utils';
import { getFlowerImage } from '@/assets/flowers';

const TIP_INFO = 'Tips are optional — 50% reaches host.';
const MAX_HOSTS_PER_GROUP = 3;

interface PrivateGroup {
  id: string; name: string; description: string | null; min_gift_amount: number;
  access_type: string; is_active: boolean; is_live: boolean; stream_id: string | null;
  participant_count: number; created_at: string; current_host_id: string | null;
  current_host_name: string | null; owner_id: string; owner_language: string | null;
  updated_at: string;
}

interface ActiveHost {
  group_id: string;
  host_id: string;
  host_name: string;
  host_language: string | null;
  participant_count: number;
}

interface PrivateGroupsSectionProps {
  currentUserId: string; userName: string; userPhoto: string | null;
}

export function PrivateGroupsSection({ currentUserId, userName, userPhoto }: PrivateGroupsSectionProps) {
  const [groups, setGroups] = useState<PrivateGroup[]>([]);
  const [activeHosts, setActiveHosts] = useState<ActiveHost[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeGroup, setActiveGroup] = useState<PrivateGroup | null>(null);
  const [activeGroupStream, setActiveGroupStream] = useState<MediaStream | null>(null);
  const [goingLive, setGoingLive] = useState<string | null>(null);

  // Language picker state
  const [pickerGroup, setPickerGroup] = useState<PrivateGroup | null>(null);
  const [pickedLanguage, setPickedLanguage] = useState<string>('');

  useEffect(() => {
    fetchAll();
    const channel = supabase
      .channel('private-groups-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'private_groups' }, fetchAll)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'group_active_hosts' }, fetchAll)
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  const fetchAll = async () => {
    try {
      const [{ data: gData, error: gErr }, { data: hData }] = await Promise.all([
        supabase.from('private_groups').select('*').eq('is_active', true)
          .order('is_live', { ascending: false }).order('name', { ascending: true }),
        supabase.from('group_active_hosts').select('group_id,host_id,host_name,host_language,participant_count')
          .eq('is_active', true),
      ]);
      if (gErr) throw gErr;
      setGroups((gData as any[]) || []);
      setActiveHosts((hData as any[]) || []);
    } catch (error) {
      console.error('Error fetching groups:', error);
      toast.error('Groups unavailable', { description: 'Unable to load your groups. Please refresh the page.' });
    } finally { setIsLoading(false); }
  };

  const myActiveHostSession = useMemo(
    () => activeHosts.find(h => h.host_id === currentUserId) || null,
    [activeHosts, currentUserId]
  );

  const hostCountByGroup = useMemo(() => {
    const map = new Map<string, number>();
    activeHosts.forEach(h => map.set(h.group_id, (map.get(h.group_id) || 0) + 1));
    return map;
  }, [activeHosts]);

  const openLanguagePicker = async (group: PrivateGroup) => {
    const { data: freshHost } = await supabase
      .from('group_active_hosts')
      .select('group_id,host_id,host_name,host_language,participant_count')
      .eq('host_id', currentUserId)
      .eq('is_active', true)
      .maybeSingle();

    if (freshHost && freshHost.group_id !== group.id) {
      toast.error('You are already hosting another group. Stop that first.');
      fetchAll();
      return;
    }
    if (freshHost?.group_id === group.id) {
      setActiveGroup({ ...group, is_live: true, current_host_id: currentUserId, current_host_name: userName, owner_language: freshHost.host_language });
      fetchAll();
      return;
    }
    if ((hostCountByGroup.get(group.id) || 0) >= MAX_HOSTS_PER_GROUP) {
      toast.error(`This group already has ${MAX_HOSTS_PER_GROUP} live hosts. Try another.`);
      return;
    }
    setPickedLanguage(INDIAN_LANGUAGES[0]?.name || 'Hindi');
    setPickerGroup(group);
  };

  const handleGoLive = async () => {
    if (!pickerGroup || !pickedLanguage) return;
    const group = pickerGroup;
    setGoingLive(group.id);
    setPickerGroup(null);

    let preStream: MediaStream | null = null;
    try {
      preStream = await navigator.mediaDevices.getUserMedia({
        video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 }, facingMode: 'user' },
        audio: { echoCancellation: true, noiseSuppression: true, sampleRate: 48000 },
      });
    } catch (mediaErr) {
      console.error('[PrivateGroups] Pre-acquire media failed:', mediaErr);
      toast.error('Could not access camera/microphone. Please allow access.');
      setGoingLive(null);
      return;
    }

    try {
      // Ensure host is a member too
      await supabase.from('group_memberships').upsert({
        group_id: group.id, user_id: currentUserId, has_access: true, gift_amount_paid: 0,
        joined_host_id: currentUserId,
      }, { onConflict: 'group_id,user_id' });

      setActiveGroupStream(preStream);
      setActiveGroup({ ...group, is_live: true, current_host_id: currentUserId, current_host_name: userName, owner_language: pickedLanguage });
      // Fetch host number for display
      const { data: meProf } = await supabase.from('profiles').select('host_number').eq('id', currentUserId).maybeSingle();
      const hostNum = (meProf as any)?.host_number;
      toast.success(`You are live in ${group.name} (${pickedLanguage})${hostNum ? ` — Host #${hostNum}` : ''}`);
    } catch (error: any) {
      preStream.getTracks().forEach(t => t.stop());
      toast.error('Unable to go live', { description: classifyError(error, 'start the live stream').message });
    } finally { setGoingLive(null); }
  };

  const handleStopLive = async (group: PrivateGroup) => {
    if (activeGroupStream) { activeGroupStream.getTracks().forEach(t => t.stop()); setActiveGroupStream(null); }
    try {
      const { error } = await supabase.rpc('stop_host_session', { p_group_id: group.id });
      if (error) throw error;
      toast.success(`Stopped live in ${group.name}`);
      fetchAll();
    } catch (error: any) {
      toast.error('Unable to stop', { description: classifyError(error, 'stop the stream').message });
      fetchAll();
    }
  };

  if (isLoading) {
    return <div className="animate-pulse h-32 bg-muted/30 rounded-lg" />;
  }

  const liveCount = activeHosts.length;

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center justify-between bg-primary text-primary-foreground px-4 py-2.5 rounded-t-xl -mx-1">
        <h3 className="text-sm font-semibold flex items-center gap-2">
          <Users className="h-4 w-4" />
          Private Groups
        </h3>
        <div className="flex items-center gap-2">
          <Badge className="bg-primary-foreground/20 text-primary-foreground border-0 text-[10px] h-5">
            {liveCount} Live
          </Badge>
          <button onClick={() => { setIsLoading(true); fetchAll(); }} className="hover:bg-primary-foreground/10 rounded-full p-1.5 transition-colors">
            <RefreshCw className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>

      {/* Tip info banner */}
      <div className="flex items-center gap-2 px-3 py-2 bg-accent/15 rounded-lg text-[11px] text-foreground border border-accent/30">
        <span className="text-sm">💰</span>
        <span>{TIP_INFO}</span>
      </div>

      {/* Group list */}
      <div className="divide-y divide-border/50 bg-card rounded-xl overflow-hidden border border-border/60">
        {groups.length === 0 && (
          <div className="py-8 text-center text-muted-foreground">
            <Users className="h-10 w-10 mx-auto mb-3 opacity-40" />
            <p className="text-sm">No groups available</p>
          </div>
        )}
        {groups.map((group) => {
          const hostCount = hostCountByGroup.get(group.id) || 0;
          const isLive = hostCount > 0;
          const myHostInThisGroup = activeHosts.find(h => h.group_id === group.id && h.host_id === currentUserId);
          const isMyHost = !!myHostInThisGroup;
          const groupFull = hostCount >= MAX_HOSTS_PER_GROUP;
          const canGoLive = !myActiveHostSession && !groupFull;

          return (
            <div
              key={group.id}
              className={cn(
                "flex items-center gap-3 px-3 py-3 transition-colors hover:bg-muted/40",
                isLive && "bg-accent/10"
              )}
            >
              <div className={cn(
                "w-11 h-11 rounded-full overflow-hidden shrink-0 bg-muted",
                isLive && "ring-2 ring-accent"
              )}>
                <img
                  src={getFlowerImage(group.name)}
                  alt={group.name}
                  width={44}
                  height={44}
                  loading="lazy"
                  className="w-full h-full object-cover"
                />
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className="font-semibold text-sm text-foreground truncate">{group.name}</span>
                  {isLive && (
                    <Badge className="bg-accent text-accent-foreground text-[9px] h-4 px-1.5 border-0 gap-0.5 shrink-0">
                      <Radio className="h-2 w-2 animate-pulse" /> LIVE
                    </Badge>
                  )}
                </div>
                <div className="flex items-center gap-2 mt-0.5">
                  {isMyHost ? (
                    <span className="text-xs text-primary font-medium truncate">
                      📹 You are hosting{myHostInThisGroup?.host_language ? ` · ${myHostInThisGroup.host_language}` : ''}
                    </span>
                  ) : isLive ? (
                    <span className="text-xs text-muted-foreground truncate">
                      {hostCount} host{hostCount > 1 ? 's' : ''} live
                    </span>
                  ) : (
                    <span className="text-xs text-muted-foreground">Offline</span>
                  )}
                </div>
                <div className="flex items-center gap-1.5 mt-1">
                  <span className="text-[10px] text-muted-foreground flex items-center gap-0.5">
                    <Users className="h-2.5 w-2.5" /> {group.participant_count}/{MAX_PARTICIPANTS}
                  </span>
                  <span className="text-[10px] text-muted-foreground flex items-center gap-0.5">
                    <MessageCircle className="h-2.5 w-2.5" /> Chat
                  </span>
                  <span className="text-[10px] text-muted-foreground flex items-center gap-0.5">
                    <Video className="h-2.5 w-2.5" /> Video
                  </span>
                </div>
              </div>

              <div className="shrink-0">
                {isMyHost ? (
                  <div className="flex flex-col gap-1">
                    <Button
                      size="sm"
                      className="h-7 text-[11px] bg-primary hover:bg-primary/80 text-primary-foreground gap-1"
                      onClick={() => setActiveGroup(group)}
                    >
                      Open
                    </Button>
                    <Button
                      size="sm"
                      variant="destructive"
                      className="h-7 text-[11px] gap-1"
                      onClick={() => handleStopLive(group)}
                    >
                      <Square className="h-3 w-3" /> Stop
                    </Button>
                  </div>
                ) : canGoLive ? (
                  <Button
                    size="sm"
                    className="h-8 text-xs bg-accent hover:bg-accent/80 text-accent-foreground gap-1 rounded-full px-4"
                    disabled={goingLive === group.id}
                    onClick={() => openLanguagePicker(group)}
                  >
                    <Radio className="h-3 w-3" />
                    {goingLive === group.id ? '...' : 'Go Live'}
                  </Button>
                ) : groupFull ? (
                  <span className="text-[10px] text-muted-foreground italic">Full ({MAX_HOSTS_PER_GROUP}/{MAX_HOSTS_PER_GROUP})</span>
                ) : myActiveHostSession ? (
                  <span className="text-[10px] text-muted-foreground italic">Hosting elsewhere</span>
                ) : null}
              </div>
            </div>
          );
        })}
      </div>

      {/* Language picker dialog */}
      <Dialog open={!!pickerGroup} onOpenChange={(o) => !o && setPickerGroup(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Globe className="h-4 w-4 text-primary" />
              Pick your hosting language
            </DialogTitle>
            <DialogDescription>
              Members will see this language so they can join hosts who speak theirs.
            </DialogDescription>
          </DialogHeader>
          <div className="max-h-[280px] overflow-y-auto -mx-2 px-2">
            <div className="grid grid-cols-2 gap-2">
              {INDIAN_LANGUAGES.map((lang) => (
                <button
                  key={lang.code}
                  type="button"
                  onClick={() => setPickedLanguage(lang.name)}
                  className={cn(
                    "px-3 py-2 rounded-lg border text-sm text-left transition-colors",
                    pickedLanguage === lang.name
                      ? "border-primary bg-primary/10 text-primary font-medium"
                      : "border-border hover:bg-muted"
                  )}
                >
                  {lang.name}
                </button>
              ))}
            </div>
          </div>
          <div className="flex gap-2 pt-2">
            <Button variant="outline" className="flex-1" onClick={() => setPickerGroup(null)}>Cancel</Button>
            <Button className="flex-1" disabled={!pickedLanguage} onClick={handleGoLive}>
              <Radio className="h-3.5 w-3.5 mr-1" /> Go Live
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {activeGroup && (
        <PrivateGroupCallWindow
          group={activeGroup}
          currentUserId={currentUserId}
          userName={userName}
          userPhoto={userPhoto}
          preAcquiredStream={activeGroupStream}
          onClose={() => {
            const groupToStop = activeGroup;
            setActiveGroup(null);
            setActiveGroupStream(null);
            if (groupToStop) handleStopLive(groupToStop);
          }}
          isOwner={true}
        />
      )}
    </div>
  );
}
