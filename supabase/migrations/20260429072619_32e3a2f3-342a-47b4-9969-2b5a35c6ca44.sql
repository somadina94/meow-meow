-- Fix video call billing: trigger should check wallet_transactions, not row totals
CREATE OR REPLACE FUNCTION public.trg_video_call_ended()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_minutes numeric;
  v_session_type text;
  v_result jsonb;
  v_already_billed boolean;
BEGIN
  IF NEW.status IN ('ended', 'completed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);

    IF NEW.started_at IS NOT NULL
       AND NEW.ended_at IS NOT NULL
       AND EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) > 0
    THEN
      -- Check if this session already has a wallet_transactions row (true source of truth)
      SELECT EXISTS (
        SELECT 1 FROM public.wallet_transactions
         WHERE session_id = NEW.id
           AND transaction_type IN ('session_charge','session_earning')
        UNION ALL
        SELECT 1 FROM public.wallet_transactions_archive
         WHERE session_id = NEW.id
           AND transaction_type IN ('session_charge','session_earning')
      ) INTO v_already_billed;

      IF NOT v_already_billed THEN
        v_minutes := ROUND(EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at)) / 60.0, 4);
        v_session_type := CASE COALESCE(NEW.call_type, 'video')
                            WHEN 'audio' THEN 'audio_call'
                            WHEN 'video' THEN 'video_call'
                            ELSE 'video_call'
                          END;

        v_result := public.bill_session_minute(
          p_session_id   => NEW.id,
          p_session_type => v_session_type,
          p_minutes      => v_minutes,
          p_man_id       => NEW.man_user_id,
          p_woman_id     => NEW.woman_user_id,
          p_man_count    => 1,
          p_minute_index => NULL
        );

        IF (v_result->>'success')::boolean IS TRUE THEN
          UPDATE public.video_call_sessions
             SET total_minutes = v_minutes,
                 total_earned  = COALESCE((v_result->>'earned')::numeric, 0)
           WHERE id = NEW.id;
        END IF;
      END IF;
    END IF;
  ELSIF NEW.status IN ('declined', 'missed') AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM public.revert_busy_to_online(NEW.man_user_id);
    PERFORM public.revert_busy_to_online(NEW.woman_user_id);
  END IF;
  RETURN NEW;
END;
$function$;

-- Backfill missed video/audio call billings for completed sessions
DO $$
DECLARE
  r RECORD;
  v_minutes numeric;
  v_stype text;
BEGIN
  FOR r IN
    SELECT v.*
      FROM public.video_call_sessions v
     WHERE v.status IN ('ended','completed')
       AND v.started_at IS NOT NULL
       AND v.ended_at IS NOT NULL
       AND EXTRACT(EPOCH FROM (v.ended_at - v.started_at)) > 0
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions w
          WHERE w.session_id = v.id
            AND w.transaction_type IN ('session_charge','session_earning')
       )
       AND NOT EXISTS (
         SELECT 1 FROM public.wallet_transactions_archive a
          WHERE a.session_id = v.id
            AND a.transaction_type IN ('session_charge','session_earning')
       )
  LOOP
    v_minutes := ROUND(EXTRACT(EPOCH FROM (r.ended_at - r.started_at)) / 60.0, 4);
    v_stype := CASE COALESCE(r.call_type, 'video')
                 WHEN 'audio' THEN 'audio_call'
                 ELSE 'video_call'
               END;
    PERFORM public.bill_session_minute(
      p_session_id   => r.id,
      p_session_type => v_stype,
      p_minutes      => v_minutes,
      p_man_id       => r.man_user_id,
      p_woman_id     => r.woman_user_id,
      p_man_count    => 1,
      p_minute_index => NULL
    );
  END LOOP;
END $$;