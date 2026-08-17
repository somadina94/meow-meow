import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';

/**
 * Hook to fetch unread counts for admin broadcast messages and admin chat messages.
 * Provides real-time updates via Supabase channels.
 */
export function useAdminUnreadCounts(userId: string | null) {
  const [unreadMessages, setUnreadMessages] = useState(0);
  const [unreadChat, setUnreadChat] = useState(0);

  const fetchCounts = async () => {
    if (!userId) return;

    try {
      // Unread admin broadcast/direct messages
      const [broadcastRes, directRes] = await Promise.all([
        supabase
          .from('admin_broadcast_messages')
          .select('id', { count: 'exact', head: true })
          .eq('is_broadcast', true)
          .eq('is_read', false),
        supabase
          .from('admin_broadcast_messages')
          .select('id', { count: 'exact', head: true })
          .eq('recipient_id', userId)
          .eq('is_broadcast', false)
          .eq('is_read', false),
      ]);

      setUnreadMessages((broadcastRes.count ?? 0) + (directRes.count ?? 0));

      // Unread admin chat messages (from admin role)
      const chatRes = await supabase
        .from('admin_user_messages')
        .select('id', { count: 'exact', head: true })
        .eq('target_user_id', userId)
        .eq('sender_role', 'admin')
        .eq('is_read', false);

      setUnreadChat(chatRes.count ?? 0);
    } catch {
      // Silently handle
    }
  };

  useEffect(() => {
    if (!userId) return;
    fetchCounts();

    // Subscribe to real-time changes
    const broadcastChannel = supabase
      .channel('admin-unread-broadcast')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'admin_broadcast_messages',
      }, () => fetchCounts())
      .subscribe();

    const chatChannel = supabase
      .channel('admin-unread-chat')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'admin_user_messages',
        filter: `target_user_id=eq.${userId}`,
      }, () => fetchCounts())
      .subscribe();

    return () => {
      supabase.removeChannel(broadcastChannel);
      supabase.removeChannel(chatChannel);
    };
  }, [userId]);

  return { unreadMessages, unreadChat, refetch: fetchCounts };
}
