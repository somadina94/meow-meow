
-- Trigger billing for the recent video call
DO $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT public.process_call_billing(
    'call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775624407648',
    'video'
  ) INTO v_result;
  RAISE NOTICE 'Billing result: %', v_result;
END;
$$;
