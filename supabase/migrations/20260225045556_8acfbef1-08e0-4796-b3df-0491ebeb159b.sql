
-- Clean up stale live groups with no host
UPDATE public.private_groups 
SET is_live = false, participant_count = 0 
WHERE is_live = true AND current_host_id IS NULL;
