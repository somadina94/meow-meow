
-- Update the active pricing row to set group call women earning to ₹0.50/min per man
UPDATE public.chat_pricing 
SET group_call_women_earning_rate = 0.50, 
    updated_at = now()
WHERE is_active = true;

-- Set the default for new rows
ALTER TABLE public.chat_pricing 
ALTER COLUMN group_call_women_earning_rate SET DEFAULT 0.50;
