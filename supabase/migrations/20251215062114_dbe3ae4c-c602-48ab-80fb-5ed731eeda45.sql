-- Add city/village column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS city TEXT;