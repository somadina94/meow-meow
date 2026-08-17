-- Clean up all non-super user data from the app
-- Super users are: female1-15@meow-meow.com, male1-15@meow-meow.com, admin1-15@meow-meow.com

-- First, get all non-super user IDs from auth.users
-- We'll delete from all related tables

-- Delete from women_earnings (references active_chat_sessions)
DELETE FROM public.women_earnings
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE public.is_super_user(email)
);

-- Delete from shift_earnings (references shifts)
DELETE FROM public.shift_earnings
WHERE user_id NOT IN (
  SELECT id FROM auth.users WHERE public.is_super_user(email)
);

-- Delete from active_chat_sessions
DELETE FROM public.active_chat_sessions
WHERE man_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR woman_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from video_call_sessions
DELETE FROM public.video_call_sessions
WHERE man_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR woman_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from chat_messages
DELETE FROM public.chat_messages
WHERE sender_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR receiver_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from moderation_reports
DELETE FROM public.moderation_reports
WHERE reporter_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR reported_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from gift_transactions
DELETE FROM public.gift_transactions
WHERE sender_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR receiver_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from wallet_transactions (references wallets)
DELETE FROM public.wallet_transactions
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from wallets
DELETE FROM public.wallets
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from shifts
DELETE FROM public.shifts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from scheduled_shifts
DELETE FROM public.scheduled_shifts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from attendance
DELETE FROM public.attendance
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from absence_records
DELETE FROM public.absence_records
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from women_availability
DELETE FROM public.women_availability
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from women_shift_assignments
DELETE FROM public.women_shift_assignments
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from chat_wait_queue
DELETE FROM public.chat_wait_queue
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from matches
DELETE FROM public.matches
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR matched_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_friends
DELETE FROM public.user_friends
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR friend_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_blocks
DELETE FROM public.user_blocks
WHERE blocked_by NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email))
   OR blocked_user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_warnings
DELETE FROM public.user_warnings
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from policy_violation_alerts
DELETE FROM public.policy_violation_alerts
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from notifications
DELETE FROM public.notifications
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from processing_logs
DELETE FROM public.processing_logs
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from tutorial_progress
DELETE FROM public.tutorial_progress
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_consent
DELETE FROM public.user_consent
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_languages
DELETE FROM public.user_languages
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_photos
DELETE FROM public.user_photos
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_settings
DELETE FROM public.user_settings
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_status
DELETE FROM public.user_status
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from user_roles (keep super user roles)
DELETE FROM public.user_roles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from password_reset_tokens
DELETE FROM public.password_reset_tokens
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from withdrawal_requests
DELETE FROM public.withdrawal_requests
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from female_profiles
DELETE FROM public.female_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from male_profiles
DELETE FROM public.male_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Delete from profiles
DELETE FROM public.profiles
WHERE user_id NOT IN (SELECT id FROM auth.users WHERE public.is_super_user(email));

-- Also clear sample data tables completely
TRUNCATE TABLE public.sample_users CASCADE;
TRUNCATE TABLE public.sample_men CASCADE;
TRUNCATE TABLE public.sample_women CASCADE;