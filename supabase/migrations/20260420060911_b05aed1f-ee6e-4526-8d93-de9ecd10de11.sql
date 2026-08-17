
-- 1. Create the service_role enum
DO $$ BEGIN
  CREATE TYPE public.service_role AS ENUM ('chat_role', 'audio_role', 'video_role', 'group_role', 'all_role');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. Create user_service_roles table
CREATE TABLE IF NOT EXISTS public.user_service_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role public.service_role NOT NULL,
  assigned_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

CREATE INDEX IF NOT EXISTS idx_user_service_roles_user_id ON public.user_service_roles(user_id);

ALTER TABLE public.user_service_roles ENABLE ROW LEVEL SECURITY;

-- 3. Security definer helper: does user have a specific service role?
CREATE OR REPLACE FUNCTION public.has_service_role(_user_id uuid, _role public.service_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_service_roles
    WHERE user_id = _user_id
      AND (role = _role OR role = 'all_role'::public.service_role)
  );
$$;

-- 4. Convenience check: can the user access a given service ('chat'|'audio'|'video'|'group')
CREATE OR REPLACE FUNCTION public.can_access_service(_user_id uuid, _service text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_service_roles
    WHERE user_id = _user_id
      AND (
        role = 'all_role'::public.service_role
        OR (_service = 'chat'  AND role = 'chat_role'::public.service_role)
        OR (_service = 'audio' AND role = 'audio_role'::public.service_role)
        OR (_service = 'video' AND role = 'video_role'::public.service_role)
        OR (_service = 'group' AND role = 'group_role'::public.service_role)
      )
  );
$$;

-- 5. RLS policies on user_service_roles
DROP POLICY IF EXISTS "Users can view own service roles" ON public.user_service_roles;
CREATE POLICY "Users can view own service roles"
ON public.user_service_roles
FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'::public.app_role));

DROP POLICY IF EXISTS "Admins can insert service roles" ON public.user_service_roles;
CREATE POLICY "Admins can insert service roles"
ON public.user_service_roles
FOR INSERT
TO authenticated
WITH CHECK (public.has_role(auth.uid(), 'admin'::public.app_role));

DROP POLICY IF EXISTS "Admins can delete service roles" ON public.user_service_roles;
CREATE POLICY "Admins can delete service roles"
ON public.user_service_roles
FOR DELETE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::public.app_role));

DROP POLICY IF EXISTS "Admins can update service roles" ON public.user_service_roles;
CREATE POLICY "Admins can update service roles"
ON public.user_service_roles
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::public.app_role));

-- 6. Backfill existing users
-- Men → all_role
INSERT INTO public.user_service_roles (user_id, role)
SELECT user_id, 'all_role'::public.service_role
FROM public.male_profiles
ON CONFLICT (user_id, role) DO NOTHING;

-- Women → chat_role
INSERT INTO public.user_service_roles (user_id, role)
SELECT user_id, 'chat_role'::public.service_role
FROM public.female_profiles
ON CONFLICT (user_id, role) DO NOTHING;

-- 7. Trigger: auto-assign default role on profile creation
CREATE OR REPLACE FUNCTION public.assign_default_male_service_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_service_roles (user_id, role)
  VALUES (NEW.user_id, 'all_role'::public.service_role)
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_default_female_service_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_service_roles (user_id, role)
  VALUES (NEW.user_id, 'chat_role'::public.service_role)
  ON CONFLICT (user_id, role) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_default_male_service_role ON public.male_profiles;
CREATE TRIGGER trg_assign_default_male_service_role
AFTER INSERT ON public.male_profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_default_male_service_role();

DROP TRIGGER IF EXISTS trg_assign_default_female_service_role ON public.female_profiles;
CREATE TRIGGER trg_assign_default_female_service_role
AFTER INSERT ON public.female_profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_default_female_service_role();
