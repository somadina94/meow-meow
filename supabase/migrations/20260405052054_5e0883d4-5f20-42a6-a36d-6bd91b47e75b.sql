-- Add audio call pricing columns to chat_pricing table
ALTER TABLE public.chat_pricing
ADD COLUMN IF NOT EXISTS audio_rate_per_minute NUMERIC NOT NULL DEFAULT 6,
ADD COLUMN IF NOT EXISTS audio_women_earning_rate NUMERIC NOT NULL DEFAULT 3;

-- Update existing active row with default audio rates
UPDATE public.chat_pricing SET audio_rate_per_minute = 6, audio_women_earning_rate = 3 WHERE is_active = true;