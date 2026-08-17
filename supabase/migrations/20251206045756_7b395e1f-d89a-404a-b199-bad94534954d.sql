-- Add location columns to profiles table
ALTER TABLE public.profiles
ADD COLUMN latitude double precision,
ADD COLUMN longitude double precision,
ADD COLUMN state text;