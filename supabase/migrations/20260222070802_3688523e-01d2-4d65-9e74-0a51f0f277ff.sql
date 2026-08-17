-- Drop the restrictive photo viewing policy
DROP POLICY "Users can view own or matched user photos" ON public.user_photos;

-- Create a new policy that allows all authenticated users to view all photos
CREATE POLICY "Authenticated users can view all photos"
ON public.user_photos
FOR SELECT
USING (auth.uid() IS NOT NULL);