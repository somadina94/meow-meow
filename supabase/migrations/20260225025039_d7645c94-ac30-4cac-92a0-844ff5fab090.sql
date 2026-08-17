-- Fix duplicate billing race condition: Remove duplicate wallet_transaction and women_earnings entries
-- The duplicate was caused by two concurrent heartbeats at 2026-02-25 02:44:05

-- 1. Delete the duplicate wallet_transaction (the second one created at 02:44:05.651874)
DELETE FROM wallet_transactions WHERE id = 'db2aa558-7827-44e1-a299-c901b821fa93';

-- 2. Refund the duplicate charge to the man's wallet (₹5.58)
UPDATE wallets SET balance = balance + 5.58 WHERE id = '551dd8b4-59ea-4404-9410-11df121b1800';

-- 3. Delete the duplicate women_earnings entry (the second one created at 02:44:05.884137)
DELETE FROM women_earnings WHERE id = 'bee3193b-6eea-4352-999a-add357d36191';
