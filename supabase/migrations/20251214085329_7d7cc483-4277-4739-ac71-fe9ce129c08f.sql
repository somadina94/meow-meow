-- Drop the public access policy that allows unauthenticated access
DROP POLICY IF EXISTS "Photos are publicly viewable" ON public.user_photos;
DROP POLICY IF EXISTS "User photos are publicly viewable" ON public.user_photos;
DROP POLICY IF EXISTS "Public photos access" ON public.user_photos;