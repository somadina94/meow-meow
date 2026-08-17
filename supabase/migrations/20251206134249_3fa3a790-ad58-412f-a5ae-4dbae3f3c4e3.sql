-- Update women earning rate to a custom value (e.g., 3.00)
-- You can change this to any value you want
UPDATE public.chat_pricing 
SET women_earning_rate = 2.00,
    rate_per_minute = 5.00,
    updated_at = now()
WHERE is_active = true;