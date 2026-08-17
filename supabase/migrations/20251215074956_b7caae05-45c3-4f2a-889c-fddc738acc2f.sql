-- =====================================================
-- PERFORMANCE OPTIMIZATION INDEXES (Fixed)
-- =====================================================

-- =====================================================
-- PROFILES TABLE - Most frequently accessed
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_gender_online ON public.profiles(gender, last_active_at DESC) WHERE account_status = 'active';
CREATE INDEX IF NOT EXISTS idx_profiles_country_state ON public.profiles(country, state);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_approval ON public.profiles(approval_status) WHERE gender = 'female';

-- =====================================================
-- CHAT MESSAGES - High volume reads
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id ON public.chat_messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON public.chat_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_unread ON public.chat_messages(receiver_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);

-- =====================================================
-- ACTIVE CHAT SESSIONS - Real-time queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_status ON public.active_chat_sessions(status, last_activity_at DESC);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_man ON public.active_chat_sessions(man_user_id, status);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_woman ON public.active_chat_sessions(woman_user_id, status);
CREATE INDEX IF NOT EXISTS idx_active_chat_sessions_chat_id ON public.active_chat_sessions(chat_id);

-- =====================================================
-- WALLET & TRANSACTIONS - Financial queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON public.wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet ON public.wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_status ON public.wallet_transactions(status) WHERE status = 'pending';

-- =====================================================
-- WOMEN EARNINGS - Dashboard queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_women_earnings_user_id ON public.women_earnings(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_women_earnings_type ON public.women_earnings(earning_type, created_at DESC);

-- =====================================================
-- MATCHES - Discovery queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_matches_user_id ON public.matches(user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user ON public.matches(matched_user_id, status);
CREATE INDEX IF NOT EXISTS idx_matches_created_at ON public.matches(created_at DESC);

-- =====================================================
-- USER STATUS - Real-time presence
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_status_online ON public.user_status(is_online, last_seen DESC) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_user_status_user_id ON public.user_status(user_id);

-- =====================================================
-- FEMALE PROFILES - Approval workflow
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_female_profiles_user_id ON public.female_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_female_profiles_approval ON public.female_profiles(approval_status, account_status);
CREATE INDEX IF NOT EXISTS idx_female_profiles_active ON public.female_profiles(last_active_at DESC) WHERE approval_status = 'approved' AND account_status = 'active';

-- =====================================================
-- VIDEO CALL SESSIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_status ON public.video_call_sessions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_man ON public.video_call_sessions(man_user_id, status);
CREATE INDEX IF NOT EXISTS idx_video_call_sessions_woman ON public.video_call_sessions(woman_user_id, status);

-- =====================================================
-- USER LANGUAGES - Matching queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_languages_user_id ON public.user_languages(user_id);
CREATE INDEX IF NOT EXISTS idx_user_languages_code ON public.user_languages(language_code);

-- =====================================================
-- USER PHOTOS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_photos_user_id ON public.user_photos(user_id, is_primary DESC);

-- =====================================================
-- GIFTS & TRANSACTIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_gift_transactions_sender ON public.gift_transactions(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_receiver ON public.gift_transactions(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gifts_active ON public.gifts(is_active, sort_order);

-- =====================================================
-- TUTORIAL & ONBOARDING
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_tutorial_progress_user_id ON public.tutorial_progress(user_id);

-- =====================================================
-- USER ROLES - Auth checks
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id, role);

-- =====================================================
-- GROUPS & MEMBERSHIPS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_group_memberships_user ON public.group_memberships(user_id, has_access);
CREATE INDEX IF NOT EXISTS idx_group_memberships_group ON public.group_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_group ON public.group_messages(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_private_groups_owner ON public.private_groups(owner_id, is_active);
CREATE INDEX IF NOT EXISTS idx_private_groups_active_live ON public.private_groups(is_active, is_live);

-- =====================================================
-- NOTIFICATIONS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- =====================================================
-- WITHDRAWAL REQUESTS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user ON public.withdrawal_requests(user_id, status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_pending ON public.withdrawal_requests(status) WHERE status = 'pending';

-- =====================================================
-- AUDIT LOGS - Admin queries
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON public.audit_logs(admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource_type, created_at DESC);

-- =====================================================
-- PLATFORM METRICS
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_platform_metrics_date ON public.platform_metrics(metric_date DESC);

-- =====================================================
-- ATTENDANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON public.attendance(user_id, attendance_date);

-- =====================================================
-- ANALYZE TABLES for query planner
-- =====================================================
ANALYZE public.profiles;
ANALYZE public.chat_messages;
ANALYZE public.active_chat_sessions;
ANALYZE public.wallets;
ANALYZE public.wallet_transactions;
ANALYZE public.matches;
ANALYZE public.user_status;
ANALYZE public.female_profiles;
ANALYZE public.women_earnings;
ANALYZE public.gifts;
ANALYZE public.gift_transactions;