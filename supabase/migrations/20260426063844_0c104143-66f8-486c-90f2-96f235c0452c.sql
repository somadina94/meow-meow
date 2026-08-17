
-- Admin INSERT/DELETE on profile sub-tables (needed for Switch Gender and Delete User)
CREATE POLICY "admin_female_profiles_insert_all"
  ON public.female_profiles FOR INSERT
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "admin_female_profiles_delete_all"
  ON public.female_profiles FOR DELETE
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "admin_male_profiles_insert_all"
  ON public.male_profiles FOR INSERT
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "admin_male_profiles_delete_all"
  ON public.male_profiles FOR DELETE
  USING (public.has_role(auth.uid(), 'admin'));

-- Admin DELETE policies on user-owned tables (needed by Delete User cleanup)
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'user_languages','user_photos','user_consent','tutorial_progress',
    'notifications','user_friends','user_blocks','matches',
    'wallets','ledger_transactions'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = t AND relnamespace = 'public'::regnamespace) THEN
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        'admin_delete_all_' || t, t
      );
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR DELETE USING (public.has_role(auth.uid(), ''admin''))',
        'admin_delete_all_' || t, t
      );
    END IF;
  END LOOP;
END $$;
