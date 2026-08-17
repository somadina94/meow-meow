-- Create a function to get public profile info for group owners
CREATE OR REPLACE FUNCTION public.get_group_owner_profile(owner_user_id uuid)
RETURNS TABLE(user_id uuid, full_name text, photo_url text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    p.user_id,
    p.full_name,
    p.photo_url
  FROM profiles p
  WHERE p.user_id = owner_user_id
  AND EXISTS (
    SELECT 1 FROM private_groups pg 
    WHERE pg.owner_id = owner_user_id 
    AND pg.is_active = true
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_group_owner_profile(uuid) TO authenticated;