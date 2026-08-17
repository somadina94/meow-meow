-- Drop scheduled_shifts table and community_shift_schedules table
-- Also drop the rotate_monthly_shifts function if it exists

DROP TABLE IF EXISTS public.community_shift_schedules CASCADE;
DROP TABLE IF EXISTS public.scheduled_shifts CASCADE;
DROP FUNCTION IF EXISTS public.rotate_monthly_shifts() CASCADE;