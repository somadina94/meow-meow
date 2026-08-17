
-- Debug: try billing directly without exception handler
DO $$
DECLARE
  v_session record;
  v_wallet_id uuid;
  v_balance numeric;
BEGIN
  SELECT * INTO v_session FROM public.video_call_sessions
  WHERE call_id = 'call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775624407648';
  
  RAISE NOTICE 'Session status: %, started: %, ended: %, minutes: %', 
    v_session.status, v_session.started_at, v_session.ended_at, v_session.total_minutes;
  
  -- Try the wallet lookup
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets WHERE user_id = v_session.man_user_id FOR UPDATE;
  
  RAISE NOTICE 'Man wallet: %, balance: %', v_wallet_id, v_balance;
  
  -- Try direct update
  UPDATE public.wallets SET balance = balance - 1, updated_at = now()
  WHERE id = v_wallet_id;
  
  -- Undo
  UPDATE public.wallets SET balance = balance + 1, updated_at = now()
  WHERE id = v_wallet_id;
  
  RAISE NOTICE 'Wallet update succeeded!';
END;
$$;
