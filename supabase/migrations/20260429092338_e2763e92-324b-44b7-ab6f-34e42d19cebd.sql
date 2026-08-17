-- Live test: 5-minute private group call between
--   pendyala436@gmail.com (man, ₹166.34) and rani.k@gmail.com (host woman)
-- Inserts 5 debit rows for the man (₹4 each = ₹20) and 5 credit rows for the woman (₹1 each = ₹5)
-- via the canonical bill_session_minute RPC.
DO $$
DECLARE
  v_session uuid := gen_random_uuid();
  v_result jsonb;
  i int;
BEGIN
  FOR i IN 0..4 LOOP
    v_result := public.bill_session_minute(
      v_session,
      'private_group_call',
      1.0,
      'b65285ea-8299-4399-9473-5a295a6634af'::uuid,  -- pendyala436 (man)
      '27e69d5d-8325-44a3-9b14-65defc4c18af'::uuid,  -- rani.k (woman host)
      1,
      i
    );
    RAISE NOTICE 'Minute %: %', i, v_result;
  END LOOP;
END $$;