-- Update default min_gift_amount to 0 for new groups
ALTER TABLE public.private_groups ALTER COLUMN min_gift_amount SET DEFAULT 0;