-- Add video call pricing columns to chat_pricing table
ALTER TABLE public.chat_pricing
ADD COLUMN IF NOT EXISTS video_rate_per_minute numeric NOT NULL DEFAULT 10.00,
ADD COLUMN IF NOT EXISTS video_women_earning_rate numeric NOT NULL DEFAULT 5.00;

-- Add comment for clarity
COMMENT ON COLUMN public.chat_pricing.video_rate_per_minute IS 'Rate charged to men per minute for video calls';
COMMENT ON COLUMN public.chat_pricing.video_women_earning_rate IS 'Rate earned by women per minute for video calls';