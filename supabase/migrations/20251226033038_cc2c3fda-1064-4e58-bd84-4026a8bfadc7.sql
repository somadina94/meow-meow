-- Add all roles to rpendyal436@gmail.com for full access
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'moderator'::app_role
FROM auth.users
WHERE email = 'rpendyal436@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

INSERT INTO public.user_roles (user_id, role)
SELECT id, 'user'::app_role
FROM auth.users
WHERE email = 'rpendyal436@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;