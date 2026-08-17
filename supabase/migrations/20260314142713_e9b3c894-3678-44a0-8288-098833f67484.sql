
-- ============================================================
-- 1. PROTECT ADMIN ACCOUNTS FROM DELETION
-- Prevent deletion of admin1-15@meow-meow.com at database level
-- ============================================================

-- Function to check if a user is a protected admin (by email pattern)
CREATE OR REPLACE FUNCTION public.is_protected_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = p_user_id
      AND email ~ '^admin([1-9]|1[0-5])@meow-meow\.com$'
  );
$$;

-- Trigger function to prevent deletion of protected admin profiles
CREATE OR REPLACE FUNCTION public.prevent_admin_profile_deletion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_protected_admin(OLD.user_id) THEN
    RAISE EXCEPTION 'Cannot delete protected admin account (admin1-15@meow-meow.com)';
  END IF;
  RETURN OLD;
END;
$$;

-- Apply trigger to profiles table
DROP TRIGGER IF EXISTS trg_prevent_admin_profile_deletion ON public.profiles;
CREATE TRIGGER trg_prevent_admin_profile_deletion
  BEFORE DELETE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_admin_profile_deletion();

-- Apply trigger to user_roles table
DROP TRIGGER IF EXISTS trg_prevent_admin_role_deletion ON public.user_roles;
CREATE TRIGGER trg_prevent_admin_role_deletion
  BEFORE DELETE ON public.user_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_admin_profile_deletion();

-- ============================================================
-- 2. ADD MISSING ADMIN RLS POLICIES
-- ============================================================

-- profiles: admin DELETE policy
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'admin_profiles_delete') THEN
    CREATE POLICY admin_profiles_delete ON public.profiles
      FOR DELETE TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- profiles: admin UPDATE policy
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'admin_profiles_update_all') THEN
    CREATE POLICY admin_profiles_update_all ON public.profiles
      FOR UPDATE TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- profiles: admin SELECT all policy
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'admin_profiles_select_all') THEN
    CREATE POLICY admin_profiles_select_all ON public.profiles
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- wallet_transactions: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'wallet_transactions' AND policyname = 'admin_wallet_transactions_select') THEN
    CREATE POLICY admin_wallet_transactions_select ON public.wallet_transactions
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- wallets: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'wallets' AND policyname = 'admin_wallets_select') THEN
    CREATE POLICY admin_wallets_select ON public.wallets
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- withdrawal_requests: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'withdrawal_requests' AND policyname = 'admin_withdrawal_requests_select') THEN
    CREATE POLICY admin_withdrawal_requests_select ON public.withdrawal_requests
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- withdrawal_requests: admin UPDATE (to process withdrawals)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'withdrawal_requests' AND policyname = 'admin_withdrawal_requests_update') THEN
    CREATE POLICY admin_withdrawal_requests_update ON public.withdrawal_requests
      FOR UPDATE TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- women_earnings: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'women_earnings' AND policyname = 'admin_women_earnings_select') THEN
    CREATE POLICY admin_women_earnings_select ON public.women_earnings
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- admin_revenue_transactions: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_revenue_transactions' AND policyname = 'admin_revenue_transactions_select') THEN
    CREATE POLICY admin_revenue_transactions_select ON public.admin_revenue_transactions
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- admin_settings: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_settings' AND policyname = 'admin_settings_all') THEN
    ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
    CREATE POLICY admin_settings_all ON public.admin_settings
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- admin_user_messages: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_user_messages' AND policyname = 'admin_user_messages_admin_all') THEN
    ALTER TABLE public.admin_user_messages ENABLE ROW LEVEL SECURITY;
    CREATE POLICY admin_user_messages_admin_all ON public.admin_user_messages
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- admin_user_messages: users can view their own messages
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_user_messages' AND policyname = 'admin_user_messages_user_select') THEN
    CREATE POLICY admin_user_messages_user_select ON public.admin_user_messages
      FOR SELECT TO authenticated
      USING (auth.uid() = target_user_id OR target_group = 'all');
  END IF;
END $$;

-- backup_logs: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'backup_logs' AND policyname = 'admin_backup_logs_all') THEN
    ALTER TABLE public.backup_logs ENABLE ROW LEVEL SECURITY;
    CREATE POLICY admin_backup_logs_all ON public.backup_logs
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- language_limits: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'language_limits' AND policyname = 'admin_language_limits_select') THEN
    CREATE POLICY admin_language_limits_select ON public.language_limits
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- user_status: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_status' AND policyname = 'admin_user_status_select') THEN
    CREATE POLICY admin_user_status_select ON public.user_status
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- video_call_sessions: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'video_call_sessions' AND policyname = 'admin_video_call_sessions_select') THEN
    CREATE POLICY admin_video_call_sessions_select ON public.video_call_sessions
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- women_kyc: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'women_kyc' AND policyname = 'admin_women_kyc_all') THEN
    CREATE POLICY admin_women_kyc_all ON public.women_kyc
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- user_roles: admin SELECT (in case previous migration failed)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_roles' AND policyname = 'admin_user_roles_select') THEN
    CREATE POLICY admin_user_roles_select ON public.user_roles
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- user_roles: users can read own role
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_roles' AND policyname = 'users_read_own_role') THEN
    CREATE POLICY users_read_own_role ON public.user_roles
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- admin_broadcast_messages: admin INSERT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'admin_broadcast_messages' AND policyname = 'admin_broadcast_insert') THEN
    CREATE POLICY admin_broadcast_insert ON public.admin_broadcast_messages
      FOR INSERT TO authenticated
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- platform_metrics: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'platform_metrics' AND policyname = 'admin_platform_metrics_select') THEN
    CREATE POLICY admin_platform_metrics_select ON public.platform_metrics
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- chat_messages: admin SELECT (for monitoring)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_messages' AND policyname = 'admin_chat_messages_select') THEN
    CREATE POLICY admin_chat_messages_select ON public.chat_messages
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- language_groups: admin ALL (for managing groups)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'language_groups' AND policyname = 'admin_language_groups_all') THEN
    CREATE POLICY admin_language_groups_all ON public.language_groups
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- chat_pricing: admin UPDATE
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'chat_pricing' AND policyname = 'admin_chat_pricing_update') THEN
    CREATE POLICY admin_chat_pricing_update ON public.chat_pricing
      FOR UPDATE TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- gifts: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gifts' AND policyname = 'admin_gifts_all') THEN
    CREATE POLICY admin_gifts_all ON public.gifts
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- legal_documents: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'legal_documents' AND policyname = 'admin_legal_documents_all') THEN
    CREATE POLICY admin_legal_documents_all ON public.legal_documents
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- gift_transactions: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'gift_transactions' AND policyname = 'admin_gift_transactions_select') THEN
    CREATE POLICY admin_gift_transactions_select ON public.gift_transactions
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- matches: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'matches' AND policyname = 'admin_matches_select') THEN
    CREATE POLICY admin_matches_select ON public.matches
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- users_wallet: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users_wallet' AND policyname = 'admin_users_wallet_select') THEN
    CREATE POLICY admin_users_wallet_select ON public.users_wallet
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- wallet_recharges: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'wallet_recharges' AND policyname = 'admin_wallet_recharges_select') THEN
    CREATE POLICY admin_wallet_recharges_select ON public.wallet_recharges
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- system_metrics: admin SELECT
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'system_metrics' AND policyname = 'admin_system_metrics_select') THEN
    CREATE POLICY admin_system_metrics_select ON public.system_metrics
      FOR SELECT TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- system_alerts: admin ALL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'system_alerts' AND policyname = 'admin_system_alerts_all') THEN
    CREATE POLICY admin_system_alerts_all ON public.system_alerts
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;

-- user_roles: admin INSERT/UPDATE/DELETE
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_roles' AND policyname = 'admin_user_roles_manage') THEN
    CREATE POLICY admin_user_roles_manage ON public.user_roles
      FOR ALL TO authenticated
      USING (public.has_role(auth.uid(), 'admin'::public.app_role))
      WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));
  END IF;
END $$;
