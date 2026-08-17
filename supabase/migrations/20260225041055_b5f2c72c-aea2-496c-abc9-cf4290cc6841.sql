
-- Create function to reset group counts at midnight
CREATE OR REPLACE FUNCTION public.reset_private_group_counts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Reset participant_count to 0 for all active groups
  UPDATE public.private_groups
  SET participant_count = 0, is_live = false;

  -- Delete all group memberships (everyone re-joins fresh)
  DELETE FROM public.group_memberships;

  RAISE LOG 'Private group counts reset at midnight';
END;
$$;
