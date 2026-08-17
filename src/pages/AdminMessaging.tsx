import { useState, useEffect, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAdminAccess } from "@/hooks/useAdminAccess";
import AdminNav from '@/components/AdminNav';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { toast } from 'sonner';
import { format } from 'date-fns';
import {
  Send, Users, MessageSquare, Globe, Search, RefreshCw, Trash2,
  UserCheck, Crown, Loader2, Mail, Inbox, Shield, Megaphone
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { ScrollingAnnouncementsManager } from '@/components/ScrollingAnnouncementsManager';

type TargetGroup = 'all' | 'indian_women' | 'world_women' | 'indian_men' | 'world_men';

interface Message {
  id: string;
  admin_id: string;
  target_group: string;
  target_user_id: string | null;
  sender_role: string;
  sender_id: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

interface UserProfile {
  user_id: string;
  full_name: string;
  gender: string;
  country: string;
  is_indian: boolean;
}

interface InboxThread {
  user_id: string;
  user_name: string;
  gender: string;
  is_indian: boolean;
  last_message: string;
  last_time: string;
  unread_count: number;
}

const GROUP_CONFIG: { key: TargetGroup; label: string; icon: React.ReactNode; color: string }[] = [
  { key: 'all', label: 'All Users', icon: <Users className="h-4 w-4" />, color: 'bg-primary/10 text-primary' },
  { key: 'indian_women', label: 'Indian Women', icon: <Crown className="h-4 w-4" />, color: 'bg-primary/10 text-primary' },
  { key: 'world_women', label: 'World Women', icon: <Globe className="h-4 w-4" />, color: 'bg-primary/10 text-primary' },
  { key: 'indian_men', label: 'Indian Men', icon: <UserCheck className="h-4 w-4" />, color: 'bg-primary/10 text-primary' },
  { key: 'world_men', label: 'World Men', icon: <Globe className="h-4 w-4" />, color: 'bg-primary/10 text-primary' },
];

const AdminMessaging = () => {
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [activeTab, setActiveTab] = useState<'inbox' | 'broadcast' | 'chat' | 'scrolling'>('inbox');
  const [selectedGroup, setSelectedGroup] = useState<TargetGroup>('all');
  const [broadcastMessage, setBroadcastMessage] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [adminId, setAdminId] = useState<string | null>(null);

  // Inbox state
  const [inboxThreads, setInboxThreads] = useState<InboxThread[]>([]);
  const [selectedThread, setSelectedThread] = useState<InboxThread | null>(null);
  const [threadMessages, setThreadMessages] = useState<Message[]>([]);
  const [inboxReply, setInboxReply] = useState('');

  // Chat state
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<UserProfile[]>([]);
  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const [chatMessage, setChatMessage] = useState('');
  const [chatMessages, setChatMessages] = useState<Message[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);
  const inboxEndRef = useRef<HTMLDivElement>(null);
  const selectedThreadRef = useRef(selectedThread);
  selectedThreadRef.current = selectedThread;
  const selectedUserRef = useRef(selectedUser);
  selectedUserRef.current = selectedUser;

  useEffect(() => {
    loadAdmin();
    fetchBroadcastMessages();
    fetchInboxThreads();

    // #4: Realtime subscription instead of polling — use refs to avoid stale closures
    const channel = supabase
      .channel('admin-messaging-rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'admin_user_messages' }, () => {
        fetchBroadcastMessages();
        fetchInboxThreads();
        if (selectedThreadRef.current) fetchThreadMessages(selectedThreadRef.current.user_id);
        if (selectedUserRef.current) fetchChatMessages(selectedUserRef.current.user_id);
      })
      .subscribe((status) => {
        // FIX #17: Error handler for channel
        if (status === 'CHANNEL_ERROR') {
          console.warn('[AdminMessaging] Realtime channel error, will auto-reconnect');
        }
      });

    return () => { supabase.removeChannel(channel); };
  }, []);

  useEffect(() => {
    if (selectedUser) fetchChatMessages(selectedUser.user_id);
  }, [selectedUser]);

  useEffect(() => {
    if (selectedThread) fetchThreadMessages(selectedThread.user_id);
  }, [selectedThread]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatMessages]);

  useEffect(() => {
    inboxEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [threadMessages]);

  const loadAdmin = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user) setAdminId(session.user.id);
  };

  const fetchInboxThreads = async () => {
    setIsLoading(true);
    try {
      // Get all user-sent messages (sender_role = 'user')
      const { data: userMessages } = await supabase
        .from('admin_user_messages')
        .select('*')
        .eq('sender_role', 'user')
        .not('target_user_id', 'is', null)
        .order('created_at', { ascending: false })
        .limit(500);

      if (!userMessages || userMessages.length === 0) {
        setInboxThreads([]);
        setIsLoading(false);
        return;
      }

      // Group by user
      const userIds = [...new Set(userMessages.map(m => m.sender_id))];

      // Fetch profiles
      const { data: profiles } = await supabase
        .from('profiles')
        .select('user_id, full_name, gender, is_indian')
        .in('user_id', userIds);

      const profileMap = new Map((profiles as any[] || []).map(p => [p.user_id, p]));

      const threads: InboxThread[] = userIds.map(uid => {
        const userMsgs = userMessages.filter(m => m.sender_id === uid);
        const profile = profileMap.get(uid) as any;
        const unread = userMsgs.filter(m => !m.is_read).length;
        return {
          user_id: uid as string,
          user_name: profile?.full_name || 'Unknown User',
          gender: profile?.gender || 'Unknown',
          is_indian: profile?.is_indian || false,
          last_message: userMsgs[0]?.message || '',
          last_time: userMsgs[0]?.created_at || '',
          unread_count: unread,
        };
      });

      // Sort: unread first, then by time
      threads.sort((a, b) => {
        if (a.unread_count > 0 && b.unread_count === 0) return -1;
        if (b.unread_count > 0 && a.unread_count === 0) return 1;
        return new Date(b.last_time).getTime() - new Date(a.last_time).getTime();
      });

      setInboxThreads(threads);
    } catch {
      toast.error('Failed to load inbox');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchThreadMessages = async (userId: string) => {
    const { data } = await supabase
      .from('admin_user_messages')
      .select('*')
      .eq('target_user_id', userId)
      .order('created_at', { ascending: true })
      .limit(200);

    if (data) setThreadMessages(data as Message[]);

    // Mark user messages as read
    await supabase
      .from('admin_user_messages')
      .update({ is_read: true })
      .eq('target_user_id', userId)
      .eq('sender_role', 'user')
      .eq('is_read', false);

    // Update thread unread
    setInboxThreads(prev => prev.map(t =>
      t.user_id === userId ? { ...t, unread_count: 0 } : t
    ));
  };

  const sendInboxReply = async () => {
    if (!inboxReply.trim() || !adminId || !selectedThread) return;
    setIsSending(true);
    try {
      const { error } = await supabase.from('admin_user_messages').insert({
        admin_id: adminId,
        target_group: 'direct',
        target_user_id: selectedThread.user_id,
        sender_role: 'admin',
        sender_id: adminId,
        message: inboxReply.trim(),
      });
      if (error) throw error;
      setInboxReply('');
      fetchThreadMessages(selectedThread.user_id);
    } catch (err: any) {
      toast.error(err.message || 'Failed to send');
    } finally {
      setIsSending(false);
    }
  };

  const fetchBroadcastMessages = async () => {
    const { data, error } = await supabase
      .from('admin_user_messages')
      .select('*')
      .is('target_user_id', null)
      .order('created_at', { ascending: false })
      .limit(100);

    if (error) {
      console.error('[AdminMessaging] broadcast fetch failed:', error);
      toast.error('Failed to load broadcasts', { description: error.message });
      return;
    }
    if (data) setMessages(data as Message[]);
  };

  const fetchChatMessages = async (userId: string) => {
    const { data, error } = await supabase
      .from('admin_user_messages')
      .select('*')
      .eq('target_user_id', userId)
      .order('created_at', { ascending: true })
      .limit(200);

    if (error) {
      console.error('[AdminMessaging] chat fetch failed:', error);
      return;
    }
    if (data) setChatMessages(data as Message[]);
  };

  const sendBroadcast = async () => {
    if (!broadcastMessage.trim() || !adminId) return;
    setIsSending(true);
    try {
      const { error } = await supabase.from('admin_user_messages').insert({
        admin_id: adminId,
        target_group: selectedGroup,
        sender_role: 'admin',
        sender_id: adminId,
        message: broadcastMessage.trim(),
      });
      if (error) throw error;
      toast.success(`Message sent to ${GROUP_CONFIG.find(g => g.key === selectedGroup)?.label}`);
      setBroadcastMessage('');
      fetchBroadcastMessages();
    } catch (err: any) {
      toast.error(err.message || 'Failed to send');
    } finally {
      setIsSending(false);
    }
  };

  const sendChatMessage = async () => {
    if (!chatMessage.trim() || !adminId || !selectedUser) return;
    setIsSending(true);
    try {
      const { error } = await supabase.from('admin_user_messages').insert({
        admin_id: adminId,
        target_group: 'direct',
        target_user_id: selectedUser.user_id,
        sender_role: 'admin',
        sender_id: adminId,
        message: chatMessage.trim(),
      });
      if (error) throw error;
      setChatMessage('');
      fetchChatMessages(selectedUser.user_id);
    } catch (err: any) {
      toast.error(err.message || 'Failed to send');
    } finally {
      setIsSending(false);
    }
  };

  const searchUsers = async () => {
    const q = searchQuery.trim();
    if (!q) return;
    setIsSearching(true);
    try {
      // Sanitize for PostgREST .or() — strip chars that would break filter syntax
      const safe = q.replace(/[,()*\\]/g, ' ').replace(/%/g, '').slice(0, 80);
      const { data, error } = await supabase
        .from('profiles')
        .select('user_id, full_name, gender, country, is_indian')
        .or(`full_name.ilike.%${safe}%,email.ilike.%${safe}%`)
        .limit(20);

      if (error) throw error;
      setSearchResults((data as UserProfile[]) || []);
    } catch (err: any) {
      console.error('[AdminMessaging] search failed:', err);
      toast.error('Search failed', { description: err?.message || 'Try a different query' });
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  };

  const deleteMessage = async (id: string) => {
    const { error } = await supabase.from('admin_user_messages').delete().eq('id', id);
    if (error) {
      toast.error('Delete failed', { description: error.message });
      return;
    }
    setMessages(prev => prev.filter(m => m.id !== id));
    setChatMessages(prev => prev.filter(m => m.id !== id));
    setThreadMessages(prev => prev.filter(m => m.id !== id));
    toast.success('Message deleted');
  };

  const getGroupLabel = (group: string) => GROUP_CONFIG.find(g => g.key === group)?.label || group;

  const totalUnread = inboxThreads.reduce((sum, t) => sum + t.unread_count, 0);

  if (adminLoading || !isAdmin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <AdminNav>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <Mail className="h-6 w-6 text-primary" />
              Admin Messaging
            </h1>
            <p className="text-sm text-muted-foreground mt-1">
              Inbox, broadcast to groups, or chat directly. Messages auto-delete after 1 week.
            </p>
          </div>
          <Badge variant="outline" className="text-xs">
            Auto-cleanup: 7 days
          </Badge>
        </div>

        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as 'inbox' | 'broadcast' | 'chat' | 'scrolling')}>
          <TabsList className="grid w-full grid-cols-2 sm:grid-cols-4 max-w-2xl h-auto">
            <TabsTrigger value="inbox" className="gap-2">
              <Inbox className="h-4 w-4" />
              Inbox
              {totalUnread > 0 && (
                <Badge variant="destructive" className="text-xs px-1.5 py-0 ml-1">{totalUnread}</Badge>
              )}
            </TabsTrigger>
            <TabsTrigger value="broadcast" className="gap-2">
              <Users className="h-4 w-4" />
              Broadcast
            </TabsTrigger>
            <TabsTrigger value="chat" className="gap-2">
              <MessageSquare className="h-4 w-4" />
              Direct Chat
            </TabsTrigger>
            <TabsTrigger value="scrolling" className="gap-2">
              <Megaphone className="h-4 w-4" />
              Scrolling
            </TabsTrigger>
          </TabsList>

          {/* INBOX TAB */}
          <TabsContent value="inbox" className="space-y-4 mt-4">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
              {/* Thread list */}
              <Card className="lg:col-span-1">
                <CardHeader className="pb-3 flex-row items-center justify-between">
                  <CardTitle className="text-base">User Messages</CardTitle>
                  <Button variant="ghost" size="icon" className="h-8 w-8" onClick={fetchInboxThreads}>
                    <RefreshCw className="h-4 w-4" />
                  </Button>
                </CardHeader>
                <CardContent>
                  {isLoading ? (
                    <div className="flex items-center justify-center py-8">
                      <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                    </div>
                  ) : inboxThreads.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Inbox className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">No user messages yet</p>
                    </div>
                  ) : (
                    <ScrollArea className="h-[400px]">
                      <div className="space-y-1">
                        {inboxThreads.map((thread) => (
                          <button
                            key={thread.user_id}
                            onClick={() => setSelectedThread(thread)}
                            className={cn(
                              'w-full flex items-start gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors text-left',
                              selectedThread?.user_id === thread.user_id
                                ? 'bg-primary/10 border border-primary/30'
                                : 'hover:bg-muted'
                            )}
                          >
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2">
                                <p className="font-medium truncate">{thread.user_name}</p>
                                {thread.unread_count > 0 && (
                                  <Badge variant="destructive" className="text-xs px-1.5 py-0">{thread.unread_count}</Badge>
                                )}
                              </div>
                              <p className="text-xs text-muted-foreground truncate">{thread.last_message}</p>
                              <p className="text-xs text-muted-foreground mt-0.5">
                                {thread.gender} · {thread.is_indian ? 'Indian' : 'World'} · {thread.last_time && format(new Date(thread.last_time), 'MMM dd, hh:mm a')}
                              </p>
                            </div>
                          </button>
                        ))}
                      </div>
                    </ScrollArea>
                  )}
                </CardContent>
              </Card>

              {/* Thread chat */}
              <Card className="lg:col-span-2">
                <CardHeader className="pb-3 flex-row items-center justify-between">
                  <CardTitle className="text-base flex items-center gap-2">
                    <MessageSquare className="h-4 w-4" />
                    {selectedThread ? (
                      <span>Chat with {selectedThread.user_name}</span>
                    ) : (
                      <span>Select a conversation</span>
                    )}
                  </CardTitle>
                  {selectedThread && (
                    <Badge variant="outline" className="text-xs">
                      {selectedThread.gender} · {selectedThread.is_indian ? 'Indian' : 'World'}
                    </Badge>
                  )}
                </CardHeader>
                <CardContent>
                  {!selectedThread ? (
                    <div className="text-center py-16 text-muted-foreground">
                      <Inbox className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">Select a user conversation from the left</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      <ScrollArea className="h-[300px] rounded-lg bg-muted/30 p-3">
                        <div className="space-y-2">
                          {threadMessages.length === 0 && (
                            <p className="text-center text-sm text-muted-foreground py-8">No messages</p>
                          )}
                          {threadMessages.map((msg) => (
                            <div
                              key={msg.id}
                              className={cn(
                                'max-w-[80%] p-2.5 rounded-lg text-sm',
                                msg.sender_role === 'admin'
                                  ? 'ml-auto bg-primary text-primary-foreground'
                                  : 'mr-auto bg-muted'
                              )}
                            >
                              <div className="flex items-center gap-1 mb-0.5">
                                {msg.sender_role === 'admin' ? (
                                  <span className="text-xs font-semibold flex items-center gap-1">
                                    <Shield className="h-3 w-3" /> Admin
                                  </span>
                                ) : (
                                  <span className="text-xs font-semibold">{selectedThread.user_name}</span>
                                )}
                              </div>
                              <p>{msg.message}</p>
                              <div className="flex items-center justify-between mt-1">
                                <span className="text-xs opacity-70">
                                  {format(new Date(msg.created_at), 'hh:mm a')}
                                </span>
                                <Button variant="ghost" size="icon" className="h-5 w-5 opacity-60 hover:opacity-100" onClick={() => deleteMessage(msg.id)}>
                                  <Trash2 className="h-3 w-3" />
                                </Button>
                              </div>
                            </div>
                          ))}
                          <div ref={inboxEndRef} />
                        </div>
                      </ScrollArea>

                      <div className="flex gap-2">
                        <Textarea
                          value={inboxReply}
                          onChange={(e) => setInboxReply(e.target.value)}
                          placeholder="Reply to user..."
                          rows={2}
                          className="resize-none flex-1"
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) {
                              e.preventDefault();
                              sendInboxReply();
                            }
                          }}
                        />
                        <Button
                          size="icon"
                          className="h-auto"
                          onClick={sendInboxReply}
                          disabled={!inboxReply.trim() || isSending}
                        >
                          {isSending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                        </Button>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* BROADCAST TAB */}
          <TabsContent value="broadcast" className="space-y-4 mt-4">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
              <Card className="lg:col-span-1">
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Compose Broadcast</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Target Group</label>
                    <div className="grid grid-cols-1 gap-2">
                      {GROUP_CONFIG.map((group) => (
                        <button
                          key={group.key}
                          onClick={() => setSelectedGroup(group.key)}
                          className={cn(
                            'flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all border',
                            selectedGroup === group.key
                              ? 'border-primary bg-primary/10 text-primary shadow-sm'
                              : 'border-border hover:bg-muted text-muted-foreground'
                          )}
                        >
                          {group.icon}
                          {group.label}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Message</label>
                    <Textarea
                      value={broadcastMessage}
                      onChange={(e) => setBroadcastMessage(e.target.value)}
                      placeholder="Type your broadcast message..."
                      rows={4}
                      className="resize-none"
                    />
                  </div>
                  <Button className="w-full gap-2" onClick={sendBroadcast} disabled={!broadcastMessage.trim() || isSending}>
                    {isSending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                    Send to {GROUP_CONFIG.find(g => g.key === selectedGroup)?.label}
                  </Button>
                </CardContent>
              </Card>

              <Card className="lg:col-span-2">
                <CardHeader className="pb-3 flex-row items-center justify-between">
                  <CardTitle className="text-base">Sent Broadcasts</CardTitle>
                  <Button variant="ghost" size="icon" className="h-8 w-8" onClick={fetchBroadcastMessages}>
                    <RefreshCw className="h-4 w-4" />
                  </Button>
                </CardHeader>
                <CardContent>
                  {messages.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Mail className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">No broadcasts sent yet</p>
                    </div>
                  ) : (
                    <ScrollArea className="h-[400px]">
                      <div className="space-y-3">
                        {messages.map((msg) => (
                          <div key={msg.id} className="p-3 rounded-lg bg-muted/50 border border-border/50">
                            <div className="flex items-center justify-between mb-1">
                              <Badge variant="secondary" className="text-xs">{getGroupLabel(msg.target_group)}</Badge>
                              <div className="flex items-center gap-2">
                                <span className="text-xs text-muted-foreground">{format(new Date(msg.created_at), 'MMM dd, hh:mm a')}</span>
                                <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => deleteMessage(msg.id)}>
                                  <Trash2 className="h-3 w-3 text-destructive" />
                                </Button>
                              </div>
                            </div>
                            <p className="text-sm">{msg.message}</p>
                          </div>
                        ))}
                      </div>
                    </ScrollArea>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* DIRECT CHAT TAB */}
          <TabsContent value="chat" className="space-y-4 mt-4">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
              <Card className="lg:col-span-1">
                <CardHeader className="pb-3">
                  <CardTitle className="text-base">Find User</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex gap-2">
                    <Input
                      placeholder="Search by name..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && searchUsers()}
                    />
                    <Button size="icon" onClick={searchUsers} disabled={isSearching}>
                      {isSearching ? <Loader2 className="h-4 w-4 animate-spin" /> : <Search className="h-4 w-4" />}
                    </Button>
                  </div>
                  <ScrollArea className="h-[350px]">
                    <div className="space-y-1">
                      {searchResults.map((user) => (
                        <button
                          key={user.user_id}
                          onClick={() => setSelectedUser(user)}
                          className={cn(
                            'w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors text-left',
                            selectedUser?.user_id === user.user_id
                              ? 'bg-primary/10 text-primary border border-primary/30'
                              : 'hover:bg-muted text-foreground'
                          )}
                        >
                          <div className="flex-1 min-w-0">
                            <p className="font-medium truncate">{user.full_name || 'Unknown'}</p>
                            <p className="text-xs text-muted-foreground">
                              {user.gender} · {user.is_indian ? 'Indian' : 'World'} · {user.country || 'N/A'}
                            </p>
                          </div>
                          <Badge variant="outline" className="text-xs shrink-0">
                            {user.gender?.toLowerCase() === 'female' ? '♀' : '♂'}
                          </Badge>
                        </button>
                      ))}
                      {searchResults.length === 0 && searchQuery && !isSearching && (
                        <p className="text-center text-sm text-muted-foreground py-4">No users found</p>
                      )}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>

              <Card className="lg:col-span-2">
                <CardHeader className="pb-3 flex-row items-center justify-between">
                  <CardTitle className="text-base flex items-center gap-2">
                    <MessageSquare className="h-4 w-4" />
                    {selectedUser ? <span>Chat with {selectedUser.full_name}</span> : <span>Select a user to chat</span>}
                  </CardTitle>
                  {selectedUser && (
                    <Badge variant="outline" className="text-xs">
                      {selectedUser.gender} · {selectedUser.is_indian ? 'Indian' : 'World'}
                    </Badge>
                  )}
                </CardHeader>
                <CardContent>
                  {!selectedUser ? (
                    <div className="text-center py-16 text-muted-foreground">
                      <MessageSquare className="h-10 w-10 mx-auto mb-2 opacity-40" />
                      <p className="text-sm">Search and select a user to start chatting</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      <ScrollArea className="h-[300px] rounded-lg bg-muted/30 p-3">
                        <div className="space-y-2">
                          {chatMessages.length === 0 && (
                            <p className="text-center text-sm text-muted-foreground py-8">No messages yet</p>
                          )}
                          {chatMessages.map((msg) => (
                            <div
                              key={msg.id}
                              className={cn(
                                'max-w-[80%] p-2.5 rounded-lg text-sm',
                                msg.sender_role === 'admin'
                                  ? 'ml-auto bg-primary text-primary-foreground'
                                  : 'mr-auto bg-muted'
                              )}
                            >
                              <p>{msg.message}</p>
                              <div className="flex items-center justify-between mt-1">
                                <span className="text-xs opacity-70">{format(new Date(msg.created_at), 'hh:mm a')}</span>
                                {msg.sender_role === 'admin' && (
                                  <Button variant="ghost" size="icon" className="h-5 w-5 opacity-60 hover:opacity-100" onClick={() => deleteMessage(msg.id)}>
                                    <Trash2 className="h-3 w-3" />
                                  </Button>
                                )}
                              </div>
                            </div>
                          ))}
                          <div ref={chatEndRef} />
                        </div>
                      </ScrollArea>
                      <div className="flex gap-2">
                        <Textarea
                          value={chatMessage}
                          onChange={(e) => setChatMessage(e.target.value)}
                          placeholder="Type a message..."
                          rows={2}
                          className="resize-none flex-1"
                          onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) {
                              e.preventDefault();
                              sendChatMessage();
                            }
                          }}
                        />
                        <Button size="icon" className="h-auto" onClick={sendChatMessage} disabled={!chatMessage.trim() || isSending}>
                          {isSending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                        </Button>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </TabsContent>
          <TabsContent value="scrolling" className="mt-4">
            <ScrollingAnnouncementsManager />
          </TabsContent>
        </Tabs>
      </div>
    </AdminNav>
  );
};

export default AdminMessaging;
