import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';

export interface IncomingCallEvent {
  callId: string;
  callType: 'audio' | 'video';
  callerUserId: string;
  callerName: string;
  callerPhoto: string | null;
}

export const useIncomingCallListener = (
  currentUserId: string | null,
  userGender: 'male' | 'female',
  _viewerLanguage?: string | null,
) => {
  const [incomingCall, setIncomingCall] = useState<IncomingCallEvent | null>(null);

  useEffect(() => {
    if (!currentUserId || userGender !== 'female') return;

    const channel = supabase.channel(`incoming:${currentUserId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'video_call_sessions',
        filter: `woman_user_id=eq.${currentUserId}`,
      }, async (payload) => {
        const row = payload.new as any;
        if (row.status !== 'ringing') return;

        // DB trigger already enforced same-language. Do not hide the ring
        // behind a second client-side language fetch (stale male/female_profiles
        // used to drop Hindi–Hindi calls silently).
        const { data: profile } = await supabase
          .from('male_profiles')
          .select('full_name, photo_url')
          .eq('user_id', row.man_user_id)
          .maybeSingle();

        setIncomingCall({
          callId: row.call_id,
          callType: (row.call_type as 'audio' | 'video') || 'video',
          callerUserId: row.man_user_id,
          callerName: profile?.full_name || 'Unknown',
          callerPhoto: profile?.photo_url || null,
        });
      })
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [currentUserId, userGender]);

  const clearIncomingCall = () => setIncomingCall(null);

  return { incomingCall, clearIncomingCall };
};
