CREATE OR REPLACE FUNCTION public.get_unified_pricing()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_p RECORD;
BEGIN
  SELECT * INTO v_p FROM public.chat_pricing WHERE is_active = true LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'chat_man_rate',4,'chat_woman_rate',2,
      'audio_man_rate',6,'audio_woman_rate',3,
      'video_man_rate',8,'video_woman_rate',4,
      'group_man_rate',4,'group_woman_rate',2,
      'gift_woman_pct',50,'tip_woman_pct',50,
      'withdrawal_fee_pct',5,'min_withdrawal_amount',5000,
      'currency','INR'
    );
  END IF;
  RETURN jsonb_build_object(
    'chat_man_rate',         COALESCE(v_p.rate_per_minute,4),
    'chat_woman_rate',       COALESCE(v_p.women_earning_rate,2),
    'audio_man_rate',        COALESCE(v_p.audio_rate_per_minute,6),
    'audio_woman_rate',      COALESCE(v_p.audio_women_earning_rate,3),
    'video_man_rate',        COALESCE(v_p.video_rate_per_minute,8),
    'video_woman_rate',      COALESCE(v_p.video_women_earning_rate,4),
    'group_man_rate',        COALESCE(v_p.group_call_rate_per_minute,4),
    'group_woman_rate',      COALESCE(v_p.group_call_women_earning_rate,2),
    'gift_woman_pct',        COALESCE(v_p.gift_women_percent,50),
    'tip_woman_pct',         50,
    'withdrawal_fee_pct',    COALESCE(v_p.withdrawal_fee_percent,5),
    'min_withdrawal_amount', COALESCE(v_p.min_withdrawal_balance,5000),
    'currency',              COALESCE(v_p.currency,'INR')
  );
END;
$$;