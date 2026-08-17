import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { toast } from 'sonner';
import { format } from 'date-fns';
import { Megaphone, Trash2, Plus, Loader2, Power, PowerOff } from 'lucide-react';
import { cn } from '@/lib/utils';
import { ScrollingAnnouncementsBar } from './ScrollingAnnouncementsBar';

type Target = 'all' | 'all_men' | 'all_women' | 'indian_men' | 'indian_women';

interface Announcement {
  id: string;
  message: string;
  target_group: Target;
  is_active: boolean;
  created_at: string;
}

const TARGETS: { key: Target; label: string }[] = [
  { key: 'all', label: 'All Users' },
  { key: 'all_men', label: 'All Men' },
  { key: 'all_women', label: 'All Women' },
  { key: 'indian_men', label: 'Indian Men' },
  { key: 'indian_women', label: 'Indian Women' },
];

export const ScrollingAnnouncementsManager = () => {
  const [items, setItems] = useState<Announcement[]>([]);
  const [message, setMessage] = useState('');
  const [target, setTarget] = useState<Target>('all');
  const [loading, setLoading] = useState(false);
  const [adding, setAdding] = useState(false);

  const load = async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('scrolling_announcements')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) toast.error('Failed to load', { description: error.message });
    setItems((data as Announcement[]) || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
    const ch = supabase
      .channel('scrolling-admin-rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'scrolling_announcements' }, load)
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, []);

  const add = async () => {
    const text = message.trim();
    if (!text) return;
    setAdding(true);
    const { data: { session } } = await supabase.auth.getSession();
    const { error } = await supabase.from('scrolling_announcements').insert({
      message: text,
      target_group: target,
      created_by: session?.user?.id ?? null,
    });
    setAdding(false);
    if (error) {
      toast.error('Failed to add', { description: error.message });
      return;
    }
    setMessage('');
    toast.success('Scrolling announcement added');
  };

  const remove = async (id: string) => {
    if (!confirm('Delete this scrolling announcement?')) return;
    const { error } = await supabase.from('scrolling_announcements').delete().eq('id', id);
    if (error) {
      toast.error('Delete failed', { description: error.message });
      return;
    }
    toast.success('Deleted');
  };

  const removeAll = async () => {
    if (items.length === 0) return;
    if (!confirm(`Delete ALL ${items.length} scrolling announcements? This cannot be undone.`)) return;
    const { error } = await supabase
      .from('scrolling_announcements')
      .delete()
      .not('id', 'is', null);
    if (error) {
      toast.error('Delete all failed', { description: error.message });
      return;
    }
    toast.success('All scrolling announcements deleted');
  };

  const removeInactive = async () => {
    const oldCount = items.filter(i => !i.is_active).length;
    if (oldCount === 0) {
      toast.info('No disabled announcements to clear');
      return;
    }
    if (!confirm(`Delete ${oldCount} disabled (old) announcements?`)) return;
    const { error } = await supabase
      .from('scrolling_announcements')
      .delete()
      .eq('is_active', false);
    if (error) {
      toast.error('Cleanup failed', { description: error.message });
      return;
    }
    toast.success(`Deleted ${oldCount} old announcements`);
  };

  const toggle = async (a: Announcement) => {
    const { error } = await supabase
      .from('scrolling_announcements')
      .update({ is_active: !a.is_active })
      .eq('id', a.id);
    if (error) toast.error('Failed', { description: error.message });
  };

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <Megaphone className="h-4 w-4 text-primary" />
            Live Preview (what users see)
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="rounded-lg border overflow-hidden">
            <ScrollingAnnouncementsBar />
          </div>
          {items.filter(i => i.is_active).length === 0 && (
            <p className="text-xs text-muted-foreground mt-2">No active scrolling announcements.</p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <Plus className="h-4 w-4 text-primary" />
            Add Scrolling Announcement
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap gap-2">
            {TARGETS.map(t => (
              <Button
                key={t.key}
                size="sm"
                variant={target === t.key ? 'default' : 'outline'}
                onClick={() => setTarget(t.key)}
              >
                {t.label}
              </Button>
            ))}
          </div>
          <Textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="e.g. Outage scheduled tonight 10pm – 11pm IST. Apologies for inconvenience."
            rows={3}
            maxLength={500}
          />
          <div className="flex items-center justify-between">
            <span className="text-xs text-muted-foreground">{message.length}/500 · New messages append to the scroll</span>
            <Button onClick={add} disabled={!message.trim() || adding}>
              {adding ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Plus className="h-4 w-4 mr-2" />}
              Add Scrolling
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-3 flex-row items-center justify-between gap-2 flex-wrap">
          <CardTitle className="text-base">All Scrolling Announcements ({items.length})</CardTitle>
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={removeInactive} disabled={items.filter(i => !i.is_active).length === 0}>
              <Trash2 className="h-3.5 w-3.5 mr-1" />
              Clear Disabled
            </Button>
            <Button size="sm" variant="destructive" onClick={removeAll} disabled={items.length === 0}>
              <Trash2 className="h-3.5 w-3.5 mr-1" />
              Delete All
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex justify-center py-6"><Loader2 className="h-6 w-6 animate-spin text-muted-foreground" /></div>
          ) : items.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-6">No scrolling announcements yet.</p>
          ) : (
            <ScrollArea className="max-h-[420px]">
              <div className="space-y-2">
                {items.map(a => (
                  <div
                    key={a.id}
                    className={cn(
                      'flex items-start gap-3 p-3 rounded-lg border',
                      a.is_active ? 'bg-primary/5 border-primary/30' : 'bg-muted/30 border-border opacity-70'
                    )}
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-2 mb-1">
                        <Badge variant={a.is_active ? 'default' : 'secondary'} className="text-[10px]">
                          {a.is_active ? 'Active' : 'Disabled'}
                        </Badge>
                        <Badge variant="outline" className="text-[10px]">
                          {TARGETS.find(t => t.key === a.target_group)?.label || a.target_group}
                        </Badge>
                        <span className="text-[10px] text-muted-foreground">
                          {format(new Date(a.created_at), 'MMM dd, hh:mm a')}
                        </span>
                      </div>
                      <p className="text-sm break-words whitespace-pre-wrap">{a.message}</p>
                    </div>
                    <div className="flex flex-col gap-1 shrink-0">
                      <Button size="icon" variant="ghost" className="h-7 w-7" onClick={() => toggle(a)} title={a.is_active ? 'Disable' : 'Enable'}>
                        {a.is_active ? <PowerOff className="h-4 w-4" /> : <Power className="h-4 w-4" />}
                      </Button>
                      <Button size="icon" variant="ghost" className="h-7 w-7 text-destructive hover:text-destructive" onClick={() => remove(a.id)} title="Delete">
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </ScrollArea>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default ScrollingAnnouncementsManager;
