
-- Drop the restrictive check constraint and replace with comprehensive one
ALTER TABLE public.ledger_transactions DROP CONSTRAINT IF EXISTS ledger_transactions_transaction_type_check;

ALTER TABLE public.ledger_transactions ADD CONSTRAINT ledger_transactions_transaction_type_check
CHECK (transaction_type = ANY (ARRAY[
  'recharge', 'credit', 'refund',
  'chat_charge', 'chat_earning',
  'audio_call_charge', 'audio_call_earning',
  'video_call_charge', 'video_call_earning',
  'group_call_charge', 'group_call_earning',
  'gift_charge', 'gift_earning',
  'earning', 'debit', 'withdrawal',
  'opening_balance', 'monthly_closing'
]));

-- Now retroactively bill today's unbilled sessions
SELECT public.process_call_billing('call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775805648731', 'audio');
SELECT public.process_call_billing('call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775805371052', 'video');
SELECT public.process_call_billing('call_0b933372-7f04-4397-9aae-0e8be4730702_04cad57a-2647-457e-beb4-9a5c60fbbe44_1775804729859', 'video');
