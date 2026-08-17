-- Add is_online column to sample_users table
ALTER TABLE public.sample_users 
ADD COLUMN is_online boolean NOT NULL DEFAULT true;

-- Update existing sample users to be online
UPDATE public.sample_users SET is_online = true;