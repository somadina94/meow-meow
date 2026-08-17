
CREATE OR REPLACE FUNCTION public.get_analytics_summary(p_start_date timestamptz, p_end_date timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_totals jsonb;
  v_chart jsonb;
  v_gender jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM profiles),
    'active_users', (SELECT count(*) FROM user_status WHERE is_online = true),
    'total_matches', (SELECT count(*) FROM matches),
    'new_users_today', (SELECT count(*) FROM profiles WHERE created_at >= date_trunc('day', now()) AND created_at < date_trunc('day', now()) + interval '1 day'),
    'messages_count', (SELECT count(*) FROM chat_messages WHERE created_at >= p_start_date AND created_at <= p_end_date),
    'men_recharges', COALESCE((SELECT sum(credit) FROM ledger_transactions WHERE transaction_type = 'recharge' AND credit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'men_spent', COALESCE((SELECT sum(debit) FROM ledger_transactions WHERE transaction_type IN ('chat_debit','video_debit','audio_debit','group_call_debit','gift_debit') AND debit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'women_earnings', COALESCE((SELECT sum(credit) FROM ledger_transactions WHERE transaction_type IN ('chat_earning','video_earning','audio_earning','group_call_earning','gift_earning') AND credit > 0 AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'women_withdrawals', COALESCE((SELECT sum(amount) FROM withdrawal_requests WHERE status = 'completed' AND created_at >= p_start_date AND created_at <= p_end_date), 0),
    'avg_session_minutes', COALESCE((SELECT avg(total_minutes) FROM active_chat_sessions WHERE created_at >= p_start_date AND created_at <= p_end_date), 0)
  ) INTO v_totals;

  SELECT jsonb_build_object(
    'male', (SELECT count(*) FROM profiles WHERE lower(gender) = 'male'),
    'female', (SELECT count(*) FROM profiles WHERE lower(gender) = 'female'),
    'other', (SELECT count(*) FROM profiles WHERE gender IS NULL OR lower(gender) NOT IN ('male','female'))
  ) INTO v_gender;

  SELECT COALESCE(jsonb_agg(row_data ORDER BY bucket), '[]'::jsonb)
  INTO v_chart
  FROM (
    SELECT
      d.bucket,
      jsonb_build_object(
        'date', to_char(d.bucket, 'Mon DD'),
        'users', COALESCE(u.cnt, 0),
        'activeUsers', COALESCE(au.cnt, 0),
        'matches', COALESCE(m.cnt, 0),
        'messages', COALESCE(msg.cnt, 0),
        'revenue', COALESCE(r.recharges, 0) - COALESCE(w.withdrawals, 0)
      ) AS row_data
    FROM generate_series(
      date_trunc('day', p_start_date),
      date_trunc('day', p_end_date),
      '1 day'::interval
    ) AS d(bucket)
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM profiles
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) u ON true
    LEFT JOIN LATERAL (
      SELECT count(DISTINCT sender_id) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) au ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM matches
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) m ON true
    LEFT JOIN LATERAL (
      SELECT count(*) AS cnt FROM chat_messages
      WHERE created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) msg ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(credit), 0) AS recharges FROM ledger_transactions
      WHERE transaction_type = 'recharge' AND credit > 0
        AND created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) r ON true
    LEFT JOIN LATERAL (
      SELECT COALESCE(sum(amount), 0) AS withdrawals FROM withdrawal_requests
      WHERE status = 'completed'
        AND created_at >= d.bucket AND created_at < d.bucket + interval '1 day'
    ) w ON true
  ) sub;

  v_result := jsonb_build_object(
    'totals', v_totals,
    'gender', v_gender,
    'chart', v_chart
  );

  RETURN v_result;
END;
$$;
