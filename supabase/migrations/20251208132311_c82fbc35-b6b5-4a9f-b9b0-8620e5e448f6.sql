-- Create a function to auto-assign admin role for admin emails (admin1@meow-meow.com to admin15@meow-meow.com)
CREATE OR REPLACE FUNCTION public.handle_admin_role_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the email matches admin1@meow-meow.com through admin15@meow-meow.com pattern
  IF NEW.email ~ '^admin(1[0-5]?|[1-9])@meow-meow\.com$' THEN
    -- Insert admin role for this user
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to auto-assign admin role on user creation
DROP TRIGGER IF EXISTS on_auth_user_created_admin_role ON auth.users;
CREATE TRIGGER on_auth_user_created_admin_role
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_admin_role_assignment();

-- Also assign admin roles to any existing admin users
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE email ~ '^admin(1[0-5]?|[1-9])@meow-meow\.com$'
ON CONFLICT (user_id, role) DO NOTHING;