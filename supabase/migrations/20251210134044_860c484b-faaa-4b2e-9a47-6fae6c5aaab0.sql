-- Clean up test/seed data from all transaction tables

-- Delete test wallet transactions (seeded free credits)
DELETE FROM wallet_transactions 
WHERE description ILIKE '%Test account%' 
   OR description ILIKE '%Free credits%'
   OR description ILIKE '%seed%';

-- Delete any test chat sessions where man and woman are the same user (self-chat)
DELETE FROM active_chat_sessions 
WHERE man_user_id = woman_user_id;

-- Delete test video call sessions
DELETE FROM video_call_sessions 
WHERE man_user_id = woman_user_id;

-- Clean up any orphaned women_earnings records
DELETE FROM women_earnings 
WHERE description ILIKE '%super user%' 
   OR description ILIKE '%test%';

-- Clean up any test shift_earnings
DELETE FROM shift_earnings 
WHERE description ILIKE '%test%';

-- Clean up gift transactions with no valid sender/receiver profiles
DELETE FROM gift_transactions gt
WHERE NOT EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = gt.sender_id)
   OR NOT EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = gt.receiver_id);