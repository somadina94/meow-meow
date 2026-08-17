-- -- Fix orphaned group: add owner as member
-- INSERT INTO public.group_memberships (group_id, user_id, has_access, gift_amount_paid)
-- VALUES ('02648183-1a33-46df-a897-6c8f76f3440e', 'c5da801c-d7f9-4ab3-ae3c-34aaa7fde7f5', true, 0)
-- ON CONFLICT (group_id, user_id) DO UPDATE SET has_access = true;

-- Update participant count to reflect owner
UPDATE public.private_groups 
SET participant_count = 1 
WHERE id = '02648183-1a33-46df-a897-6c8f76f3440e' AND participant_count = 0;