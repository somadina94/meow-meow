
-- First delete all existing private groups and memberships (clean slate for permanent groups)
DELETE FROM public.group_memberships;
DELETE FROM public.group_video_access;
DELETE FROM public.group_messages;
DELETE FROM public.private_groups;

-- Insert 4 permanent flower-named groups (no owner - system groups)
INSERT INTO public.private_groups (id, name, description, owner_id, min_gift_amount, access_type, is_active, is_live, participant_count)
VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Rose', 'A beautiful rose-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000002', 'Lily', 'A graceful lily-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000003', 'Jasmine', 'A fragrant jasmine-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0),
  ('00000000-0000-0000-0000-000000000004', 'Orchid', 'An elegant orchid-themed private room', '00000000-0000-0000-0000-000000000000', 0, 'both', true, false, 0);

-- Add a column to track current host
ALTER TABLE public.private_groups ADD COLUMN IF NOT EXISTS current_host_id uuid DEFAULT NULL;
ALTER TABLE public.private_groups ADD COLUMN IF NOT EXISTS current_host_name text DEFAULT NULL;
