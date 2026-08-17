ALTER TABLE public.scrolling_announcements
  DROP CONSTRAINT IF EXISTS scrolling_announcements_target_group_check;

UPDATE public.scrolling_announcements SET target_group = 'all_men' WHERE target_group = 'men';
UPDATE public.scrolling_announcements SET target_group = 'all_women' WHERE target_group = 'women';

ALTER TABLE public.scrolling_announcements
  ADD CONSTRAINT scrolling_announcements_target_group_check
  CHECK (target_group IN ('all','all_men','all_women','indian_men','indian_women'));