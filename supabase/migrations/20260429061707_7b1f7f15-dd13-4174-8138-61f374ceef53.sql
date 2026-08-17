UPDATE public.chat_pricing
SET group_call_women_earning_rate = 2.00,
    updated_at = now()
WHERE is_active = true;