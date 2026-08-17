/**
 * AdminLiveMessenger — /admin/messenger
 * Three tabs: Online (men | women columns) · Chats (active threads) · TL (Team Lead women)
 * Clicking a user opens an AdminSideChat dialog. Calls to any user are free
 * because bill_session_minute / bill_group_chat_minute bypass admin participants.
 */
import { useEffect, useMemo, useState } from 'react';
import AdminNav from '@/components/AdminNav';
import { useAdminAccess } from '@/hooks/useAdminAccess';
import { supabase } from '@/integrations/supabase/client';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog';
import { AdminSideChat } from '@/components/AdminSideChat';
import { Users, Crown, Shield, Search, MessageSquare, Loader2 } from 'lucide-react';

interface OnlineUser {
  user_id: string;
  full_name: string;
  gender: string | null;
  photo_url: string | null;
  last_seen: string | null;
}

interface Thread {
  user_id: string;
  full_name: string;
  gender: string | null;
  last_message: string;
  last_time: string;
  unread: number;
}

interface TLUser {
  user_id: string;
  full_name: string;
  photo_url: string | null;
}

function UserRow({ u, unread, onClick }: { u: { full_name: string; photo_url?: string | null; gender?: string | null }, unread?: number, onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-muted/60 transition-colors text-left"
    >
      <div className="w-9 h-9 rounded-full overflow-hidden bg-primary/15 flex items-center justify-center shrink-0">
        {u.photo_url ? <img src={u.photo_url} alt="" className="w-full h-full object-cover" /> : <Users className="w-4 h-4 text-primary" />}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate">{u.full_name}</p>
        <p className="text-[10px] text-muted-foreground capitalize">{u.gender ?? '—'}</p>
      </div>
      {typeof unread === 'number' && unread > 0 && (
        <Badge className="bg-[#25D366] text-white border-0 text-[10px]">{unread}</Badge>
      )}
    </button>
  );
}

export default function AdminLiveMessenger() {
  const { isLoading, isAdmin, adminEmail } = useAdminAccess();
  const [adminId, setAdminId] = useState<string | null>(null);
  const [tab, setTab] = useState<'online' | 'chats' | 'tl'>('online');
  const [search, setSearch] = useState('');

  const [online, setOnline] = useState<OnlineUser[]>([]);
  const [threads, setThreads] = useState<Thread[]>([]);
  const [tls, setTls] = useState<TLUser[]>([]);
  const [loading, setLoading] = useState(true);

  const [active, setActive] = useState<{ id: string; name: string } | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setAdminId(data.user?.id ?? null));
  }, []);

  const loadOnline = async () => {
    const { data: statusRows } = await supabase
      .from('user_status')
      .select('user_id, last_seen')
      .eq('is_online', true)
      .limit(500);
    const ids = (statusRows ?? []).map(r => r.user_id);
    if (!ids.length) { setOnline([]); return; }
    const { data: profs } = await supabase
      .from('profiles')
      .select('user_id, full_name, gender, photo_url')
      .in('user_id', ids);
    const byId = new Map((profs ?? []).map((p: any) => [p.user_id, p]));
    setOnline((statusRows ?? []).map(s => {
      const p: any = byId.get(s.user_id) ?? {};
      return {
        user_id: s.user_id,
        full_name: p.full_name ?? 'User',
        gender: p.gender ?? null,
        photo_url: p.photo_url ?? null,
        last_seen: s.last_seen ?? null,
      };
    }));
  };

  const loadThreads = async () => {
    const { data } = await supabase
      .from('admin_user_messages')
      .select('target_user_id, sender_role, message, created_at, is_read')
      .eq('target_group', 'direct')
      .order('created_at', { ascending: false })
      .limit(500);
    const grouped = new Map<string, Thread>();
    for (const m of (data ?? []) as any[]) {
      const uid = m.target_user_id as string;
      if (!uid) continue;
      const cur = grouped.get(uid);
      const unreadInc = m.sender_role === 'user' && !m.is_read ? 1 : 0;
      if (!cur) {
        grouped.set(uid, {
          user_id: uid, full_name: 'User', gender: null,
          last_message: m.message, last_time: m.created_at, unread: unreadInc,
        });
      } else {
        cur.unread += unreadInc;
      }
    }
    const ids = Array.from(grouped.keys());
    if (ids.length) {
      const { data: profs } = await supabase
        .from('profiles').select('user_id, full_name, gender').in('user_id', ids);
      for (const p of (profs ?? []) as any[]) {
        const t = grouped.get(p.user_id);
        if (t) { t.full_name = p.full_name ?? 'User'; t.gender = p.gender ?? null; }
      }
    }
    setThreads(Array.from(grouped.values()).sort((a, b) => b.last_time.localeCompare(a.last_time)));
  };

  const loadTL = async () => {
    const { data: roleRows } = await supabase
      .from('user_service_roles')
      .select('user_id')
      .eq('role', 'tl_role');
    const ids = Array.from(new Set((roleRows ?? []).map(r => r.user_id)));
    if (!ids.length) { setTls([]); return; }
    const { data: profs } = await supabase
      .from('profiles').select('user_id, full_name, photo_url, gender').in('user_id', ids);
    setTls((profs ?? []).map((p: any) => ({ user_id: p.user_id, full_name: p.full_name ?? 'User', photo_url: p.photo_url ?? null })));
  };

  useEffect(() => {
    if (!isAdmin) return;
    setLoading(true);
    Promise.all([loadOnline(), loadThreads(), loadTL()]).finally(() => setLoading(false));
    const iv = setInterval(loadOnline, 20_000);
    const ch = supabase
      .channel('admin-messenger-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'admin_user_messages' }, () => loadThreads())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_service_roles' }, () => loadTL())
      .subscribe();
    return () => { clearInterval(iv); supabase.removeChannel(ch); };
  }, [isAdmin]);

  const q = search.trim().toLowerCase();
  const filter = <T extends { full_name: string }>(arr: T[]) =>
    !q ? arr : arr.filter(x => x.full_name.toLowerCase().includes(q));

  const men = useMemo(() => filter(online.filter(o => o.gender === 'male')), [online, q]);
  const women = useMemo(() => filter(online.filter(o => o.gender === 'female')), [online, q]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <Loader2 className="w-6 h-6 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <AdminNav>
      <div className="space-y-4">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold flex items-center gap-2">
            <MessageSquare className="w-5 h-5 text-primary" /> Live Messenger
          </h1>
          <p className="text-xs text-muted-foreground">Admin free chat & calls · {adminEmail}</p>
        </div>

        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name…"
            className="pl-9"
          />
        </div>

        <Tabs value={tab} onValueChange={(v) => setTab(v as any)}>
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="online" className="text-xs">
              Online <Badge variant="secondary" className="ml-1 text-[10px]">{online.length}</Badge>
            </TabsTrigger>
            <TabsTrigger value="chats" className="text-xs">
              Chats <Badge variant="secondary" className="ml-1 text-[10px]">{threads.length}</Badge>
            </TabsTrigger>
            <TabsTrigger value="tl" className="text-xs">
              TL <Badge variant="secondary" className="ml-1 text-[10px]">{tls.length}</Badge>
            </TabsTrigger>
          </TabsList>

          <TabsContent value="online" className="mt-3">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div className="border border-border rounded-xl bg-card overflow-hidden">
                <div className="px-3 py-2 border-b border-border bg-muted/40 text-xs font-semibold flex items-center gap-1.5">
                  <Users className="w-3.5 h-3.5" /> Men Online ({men.length})
                </div>
                <ScrollArea className="h-[55vh]">
                  <div className="p-1.5 space-y-1">
                    {men.length === 0 ? (
                      <p className="text-center text-xs text-muted-foreground py-6">No men online</p>
                    ) : men.map(u => (
                      <UserRow key={u.user_id} u={u} onClick={() => setActive({ id: u.user_id, name: u.full_name })} />
                    ))}
                  </div>
                </ScrollArea>
              </div>
              <div className="border border-border rounded-xl bg-card overflow-hidden">
                <div className="px-3 py-2 border-b border-border bg-muted/40 text-xs font-semibold flex items-center gap-1.5">
                  <Crown className="w-3.5 h-3.5" /> Women Online ({women.length})
                </div>
                <ScrollArea className="h-[55vh]">
                  <div className="p-1.5 space-y-1">
                    {women.length === 0 ? (
                      <p className="text-center text-xs text-muted-foreground py-6">No women online</p>
                    ) : women.map(u => (
                      <UserRow key={u.user_id} u={u} onClick={() => setActive({ id: u.user_id, name: u.full_name })} />
                    ))}
                  </div>
                </ScrollArea>
              </div>
            </div>
          </TabsContent>

          <TabsContent value="chats" className="mt-3">
            <div className="border border-border rounded-xl bg-card overflow-hidden">
              <ScrollArea className="h-[60vh]">
                <div className="p-1.5 space-y-1">
                  {loading ? (
                    <div className="flex justify-center py-8"><Loader2 className="w-5 h-5 animate-spin text-primary" /></div>
                  ) : filter(threads).length === 0 ? (
                    <p className="text-center text-xs text-muted-foreground py-6">No active chats</p>
                  ) : filter(threads).map(t => (
                    <button key={t.user_id} onClick={() => setActive({ id: t.user_id, name: t.full_name })}
                      className="w-full flex items-start gap-3 px-3 py-2 rounded-lg hover:bg-muted/60 text-left">
                      <div className="w-9 h-9 rounded-full bg-primary/15 flex items-center justify-center shrink-0">
                        <Users className="w-4 h-4 text-primary" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <p className="text-sm font-medium truncate">{t.full_name}</p>
                          <span className="text-[10px] text-muted-foreground shrink-0">
                            {new Date(t.last_time).toLocaleDateString()}
                          </span>
                        </div>
                        <p className="text-xs text-muted-foreground truncate">{t.last_message}</p>
                      </div>
                      {t.unread > 0 && <Badge className="bg-[#25D366] text-white border-0 text-[10px]">{t.unread}</Badge>}
                    </button>
                  ))}
                </div>
              </ScrollArea>
            </div>
          </TabsContent>

          <TabsContent value="tl" className="mt-3">
            <div className="border border-border rounded-xl bg-card overflow-hidden">
              <div className="px-3 py-2 border-b border-border bg-muted/40 text-xs font-semibold flex items-center gap-1.5">
                <Shield className="w-3.5 h-3.5" /> Team Lead Women ({tls.length})
              </div>
              <ScrollArea className="h-[55vh]">
                <div className="p-1.5 space-y-1">
                  {filter(tls).length === 0 ? (
                    <p className="text-center text-xs text-muted-foreground py-6">
                      No TL assigned. Use User Management → Service Roles → “Team Lead (TL)”.
                    </p>
                  ) : filter(tls).map(u => (
                    <UserRow key={u.user_id} u={{ ...u, gender: 'female' }} onClick={() => setActive({ id: u.user_id, name: u.full_name })} />
                  ))}
                </div>
              </ScrollArea>
            </div>
          </TabsContent>
        </Tabs>
      </div>

      <Dialog open={!!active} onOpenChange={(v) => !v && setActive(null)}>
        <DialogContent className="sm:max-w-lg p-0 overflow-hidden">
          <DialogTitle className="sr-only">Chat with {active?.name ?? 'user'}</DialogTitle>
          {active && adminId && (
            <AdminSideChat adminId={adminId} targetUserId={active.id} targetUserName={active.name} />
          )}
        </DialogContent>
      </Dialog>
    </AdminNav>
  );
}
