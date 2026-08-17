DO $$
DECLARE v_chat int; v_video int; v_group int;
BEGIN
  UPDATE public.ledger_transactions SET transaction_type='chat_earning'
   WHERE transaction_type='earning' AND description ~* '^chat earning';
  GET DIAGNOSTICS v_chat = ROW_COUNT;

  UPDATE public.ledger_transactions SET transaction_type='video_call_earning'
   WHERE transaction_type='earning' AND description ~* '^video earning';
  GET DIAGNOSTICS v_video = ROW_COUNT;

  UPDATE public.ledger_transactions SET transaction_type='group_call_earning'
   WHERE transaction_type='earning' AND description ~* '^group call earning';
  GET DIAGNOSTICS v_group = ROW_COUNT;

  RAISE NOTICE 'Backfill counts — chat:% video:% group:%', v_chat, v_video, v_group;
END $$;