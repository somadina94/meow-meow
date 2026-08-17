
-- Add force free mode tracking columns to women_chat_modes
ALTER TABLE public.women_chat_modes
ADD COLUMN IF NOT EXISTS force_free_minutes_used_today integer NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS force_free_minutes_limit integer NOT NULL DEFAULT 15,
ADD COLUMN IF NOT EXISTS is_force_free_active boolean NOT NULL DEFAULT false;
