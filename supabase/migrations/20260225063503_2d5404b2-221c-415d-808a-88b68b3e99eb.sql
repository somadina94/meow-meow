-- Reset all stuck groups that show is_live=true but have no host
UPDATE public.private_groups 
SET is_live = false, stream_id = NULL, current_host_id = NULL, current_host_name = NULL, participant_count = 0
WHERE is_live = true AND current_host_id IS NULL;

-- Clean up any orphan memberships for groups that are no longer live
DELETE FROM public.group_memberships 
WHERE group_id IN (SELECT id FROM public.private_groups WHERE is_live = false);