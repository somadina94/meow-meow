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
  userGender: 'male' | 'female'
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

        // Fetch caller profile from male_profiles
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
