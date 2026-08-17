-- Insert group tip test data: Rahul tips ₹10 Rose gift to Rani (host), Rani gets ₹5 (50%)

-- 1. Debit Rahul's wallet (full ₹10)
INSERT INTO public.wallet_transactions (wallet_id, user_id, type, amount, description, status)
VALUES (
  '551dd8b4-59ea-4404-9410-11df121b1800',
  'b426b99c-e7d8-4b87-ba3f-ee83002fedbf',
  'debit',
  10.00,
  'Group tip: 🌹 Rose (to host)',
  'completed'
);

-- 2. Credit Rani (host) with 50% = ₹5
INSERT INTO public.women_earnings (user_id, amount, earning_type, description)
VALUES (
  'cd6e623c-2d2a-4cc2-8705-e0ae5b3277a3',
  5.00,
  'gift',
  'Group tip received (50%): 🌹 Rose'
);

-- 3. Gift transaction record
INSERT INTO public.gift_transactions (sender_id, receiver_id, gift_id, price_paid, currency, message, status)
VALUES (
  'b426b99c-e7d8-4b87-ba3f-ee83002fedbf',
  'cd6e623c-2d2a-4cc2-8705-e0ae5b3277a3',
  '9bc0b3b1-d0ab-4e48-b84b-cc3fa2baba9a',
  10.00,
  'INR',
  'Group tip in Rose room',
  'completed'
);