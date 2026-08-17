UPDATE public.ledger_transactions SET transaction_type='chat_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Chat earning%';

UPDATE public.ledger_transactions SET transaction_type='video_call_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Video earning%';

UPDATE public.ledger_transactions SET transaction_type='group_call_earning'
 WHERE transaction_type='earning' AND description ILIKE 'Group call earning%';