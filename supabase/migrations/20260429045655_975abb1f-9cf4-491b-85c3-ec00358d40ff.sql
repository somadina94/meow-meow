
INSERT INTO public.wallet_transactions (
  wallet_id, user_id, type, transaction_type, session_type,
  amount, balance_after, description, reference_id, idempotency_key, status, created_at
)
SELECT
  w.id, wr.user_id, 'credit', 'recharge', 'wallet',
  wr.amount,
  wr.amount,
  CASE wr.payment_gateway
    WHEN 'admin_credit' THEN 'Admin credit ₹' || wr.amount
    ELSE 'Wallet recharge ₹' || wr.amount || ' via ' || wr.payment_gateway
  END,
  COALESCE(wr.gateway_transaction_id, wr.id::text),
  'recharge|' || wr.user_id::text || '|' || COALESCE(wr.gateway_transaction_id, wr.id::text),
  'completed',
  wr.created_at
FROM public.wallet_recharges wr
JOIN public.wallets w ON w.user_id = wr.user_id
WHERE wr.status = 'success'
ON CONFLICT (idempotency_key) DO NOTHING;
