-- Update woman group call earning rate to ₹1.00/min per man (was ₹2.00)
UPDATE public.chat_pricing
   SET group_call_women_earning_rate = 1.00,
       group_call_rate_per_minute    = 4.00,
       updated_at = now()
 WHERE is_active = true;

-- Also align the column default so new pricing rows inherit the correct value
ALTER TABLE public.chat_pricing
  ALTER COLUMN group_call_women_earning_rate SET DEFAULT 1.00;