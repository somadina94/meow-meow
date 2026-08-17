
-- Allow authenticated users to read female_profiles for browsing
CREATE POLICY "Authenticated users can browse female profiles"
  ON public.female_profiles FOR SELECT
  USING (auth.uid() IS NOT NULL AND account_status = 'active');

-- Allow authenticated users to read male_profiles for browsing
CREATE POLICY "Authenticated users can browse male profiles"
  ON public.male_profiles FOR SELECT
  USING (auth.uid() IS NOT NULL AND account_status = 'active');
