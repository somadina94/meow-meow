-- Fix recursive RLS checks on user_roles by introducing a SECURITY DEFINER helper
-- and replacing self-referential policy expressions.

-- 1) Create role enum if missing (safe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'app_role'
  ) THEN
    CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');
  END IF;
END $$;

-- 2) Create helper function (SECURITY DEFINER avoids RLS recursion)
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  );
$$;

-- 3) Ensure authenticated users can execute function
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO anon;

-- 4) Replace recursive user_roles admin policy with function-based policy
DROP POLICY IF EXISTS user_roles_admin_select_all ON public.user_roles;

CREATE POLICY user_roles_admin_select_all
ON public.user_roles
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::public.app_role));

-- Keep own-read policy for users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename='user_roles'
      AND policyname='user_roles_select_own'
  ) THEN
    CREATE POLICY user_roles_select_own
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
  END IF;
END $$;

-- 5) Auto-rewrite other policies that recursively query public.user_roles
DO $$
DECLARE
  p RECORD;
  new_qual text;
  new_check text;
  cmd_clause text;
  role_list text;
  permissive_clause text;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname, cmd, roles, permissive, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (coalesce(qual,'') ILIKE '%from user_roles%'
           OR coalesce(with_check,'') ILIKE '%from user_roles%')
      AND NOT (tablename = 'user_roles' AND policyname = 'user_roles_select_own')
  LOOP
    new_qual := p.qual;
    new_check := p.with_check;

    -- Replace common recursive pattern with definer function call
    IF new_qual IS NOT NULL THEN
      new_qual := regexp_replace(
        new_qual,
        'EXISTS \( SELECT 1\s+FROM user_roles[^\)]*role = ''admin''::app_role\)\)',
        'public.has_role(auth.uid(), ''admin''::public.app_role)',
        'gi'
      );
      new_qual := regexp_replace(
        new_qual,
        'EXISTS \( SELECT 1\s+FROM public\.user_roles[^\)]*role = ''admin''::app_role\)\)',
        'public.has_role(auth.uid(), ''admin''::public.app_role)',
        'gi'
      );
    END IF;

    IF new_check IS NOT NULL THEN
      new_check := regexp_replace(
        new_check,
        'EXISTS \( SELECT 1\s+FROM user_roles[^\)]*role = ''admin''::app_role\)\)',
        'public.has_role(auth.uid(), ''admin''::public.app_role)',
        'gi'
      );
      new_check := regexp_replace(
        new_check,
        'EXISTS \( SELECT 1\s+FROM public\.user_roles[^\)]*role = ''admin''::app_role\)\)',
        'public.has_role(auth.uid(), ''admin''::public.app_role)',
        'gi'
      );
    END IF;

    -- If regex missed due formatting, hard-fallback to function for admin-only policies
    IF p.policyname ILIKE '%admin%' THEN
      IF new_qual IS NOT NULL AND new_qual ILIKE '%from user_roles%' THEN
        new_qual := 'public.has_role(auth.uid(), ''admin''::public.app_role)';
      END IF;
      IF new_check IS NOT NULL AND new_check ILIKE '%from user_roles%' THEN
        new_check := 'public.has_role(auth.uid(), ''admin''::public.app_role)';
      END IF;
    END IF;

    -- Build command and role clause
    cmd_clause := CASE
      WHEN p.cmd = 'ALL' THEN 'FOR ALL'
      ELSE 'FOR ' || p.cmd
    END;

    SELECT string_agg(quote_ident(r), ', ')
    INTO role_list
    FROM unnest(p.roles) AS r;

    IF role_list IS NULL THEN
      role_list := 'public';
    END IF;

    permissive_clause := CASE WHEN p.permissive = 'PERMISSIVE' THEN 'AS PERMISSIVE' ELSE 'AS RESTRICTIVE' END;

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', p.policyname, p.schemaname, p.tablename);

    IF new_qual IS NOT NULL AND new_check IS NOT NULL THEN
      EXECUTE format(
        'CREATE POLICY %I ON %I.%I %s %s TO %s USING (%s) WITH CHECK (%s)',
        p.policyname, p.schemaname, p.tablename, permissive_clause, cmd_clause, role_list, new_qual, new_check
      );
    ELSIF new_qual IS NOT NULL THEN
      EXECUTE format(
        'CREATE POLICY %I ON %I.%I %s %s TO %s USING (%s)',
        p.policyname, p.schemaname, p.tablename, permissive_clause, cmd_clause, role_list, new_qual
      );
    ELSIF new_check IS NOT NULL THEN
      EXECUTE format(
        'CREATE POLICY %I ON %I.%I %s %s TO %s WITH CHECK (%s)',
        p.policyname, p.schemaname, p.tablename, permissive_clause, cmd_clause, role_list, new_check
      );
    END IF;
  END LOOP;
END $$;