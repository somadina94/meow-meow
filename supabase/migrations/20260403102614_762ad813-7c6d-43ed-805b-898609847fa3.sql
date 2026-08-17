
SELECT atomic_wallet_credit(
  '0b933372-7f04-4397-9aae-0e8be4730702'::uuid,
  100.00
);

INSERT INTO ledger_transactions (user_id, transaction_type, credit, debit, description, reference_id)
VALUES (
  '0b933372-7f04-4397-9aae-0e8be4730702',
  'recharge',
  100.00,
  0.00,
  'Admin manual credit: ₹100 added to wallet',
  'admin-manual-' || gen_random_uuid()::text
);
