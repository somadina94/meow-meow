-- Clean ALL wallet transactions to reset to zero
DELETE FROM wallet_transactions;

-- Reset all wallet balances to zero
UPDATE wallets SET balance = 0, updated_at = now();

-- Clean all chat sessions
DELETE FROM active_chat_sessions;

-- Clean all video call sessions  
DELETE FROM video_call_sessions;

-- Clean all women earnings
DELETE FROM women_earnings;

-- Clean all shift earnings
DELETE FROM shift_earnings;

-- Clean all gift transactions
DELETE FROM gift_transactions;

-- Clean all withdrawal requests
DELETE FROM withdrawal_requests;

-- Reset platform metrics
-- DELETE FROM platform_metrics;