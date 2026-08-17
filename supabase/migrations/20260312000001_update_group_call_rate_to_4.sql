-- Update group call pricing: men charged ₹4/min, host earns ₹2/min per man

-- Update column defaults
ALTER TABLE public.chat_pricing
  ALTER COLUMN group_call_rate_per_minute SET DEFAULT 4.00;

-- Update existing active pricing row to ₹4/min
UPDATE public.chat_pricing
SET 
  group_call_rate_per_minute = 4.00,
  group_call_women_earning_rate = 2.00,
  updated_at = now()
WHERE is_active = true;
