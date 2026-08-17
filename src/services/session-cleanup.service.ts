/**
 * Session Cleanup Service
 *
 * Centralized cleanup for all active sessions when a user logs out or times out.
 * Each operation is attempted independently so one failure doesn't block others.
 */

import { supabase } from '@/integrations/supabase/client';

async function tryUpdate(label: string, query: PromiseLike<{ error: unknown }>): Promise<void> {
  try {
    const { error } = await query;
    if (error) console.warn(`[SessionCleanup] ${label}:`, error);
  } catch (err) {
    console.warn(`[SessionCleanup] ${label} threw:`, err);
  }
}

export async function cleanupAllUserSessions(userId: string): Promise<void> {
  if (!userId) {
    console.warn('[SessionCleanup] No userId provided, skipping cleanup');
    return;
  }

  const now = new Date().toISOString();

  await Promise.allSettled([
    // 1. End all active chat sessions (man or woman)
    tryUpdate('end active chats', supabase
      .from('active_chat_sessions')
      .update({ status: 'ended', ended_at: now, end_reason: 'user_logout' })
      .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`)
      .eq('status', 'active')),

    // 2. End paused/billing-paused chat sessions
    tryUpdate('end paused chats', supabase
      .from('active_chat_sessions')
      .update({ status: 'ended', ended_at: now, end_reason: 'user_logout' })
      .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`)
      .in('status', ['paused', 'billing_paused'])),

    // 3. End all active video call sessions
    tryUpdate('end video calls', supabase
      .from('video_call_sessions')
      .update({ status: 'ended', ended_at: now, end_reason: 'user_logout' })
      .or(`man_user_id.eq.${userId},woman_user_id.eq.${userId}`)
      .eq('status', 'active')),

    // 4. Stop any live private groups hosted by this user
    tryUpdate('stop live groups', supabase
      .from('private_groups')
      .update({
        is_live: false,
        stream_id: null,
        current_host_id: null,
        current_host_name: null,
        participant_count: 0,
      })
      .eq('current_host_id', userId)
      .eq('is_live', true)),

    // 5. Remove user from group memberships
    tryUpdate('remove group memberships', supabase
      .from('group_memberships')
      .delete()
      .eq('user_id', userId)),

    // 6. Set user offline (upsert so it works even if row doesn't exist)
    tryUpdate('set offline', supabase
      .from('user_status')
      .upsert({
        user_id: userId,
        is_online: false,
        status_text: 'offline',
        last_seen: now,
      }, { onConflict: 'user_id' })),

    // 7. Set women availability to unavailable
    tryUpdate('set unavailable', supabase
      .from('women_availability')
      .update({ is_available: false, is_available_for_calls: false })
      .eq('user_id', userId)),
  ]);

  console.log(`[SessionCleanup] Cleanup complete for user ${userId}`);
}
