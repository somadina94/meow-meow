-- Update the chat_pricing with the correct default values
UPDATE public.chat_pricing 
SET rate_per_minute = 5.00, 
    women_earning_rate = 2.00,
    updated_at = now()
WHERE id = '09b75042-36f5-4053-b1ca-5bba6a0bcfe6';