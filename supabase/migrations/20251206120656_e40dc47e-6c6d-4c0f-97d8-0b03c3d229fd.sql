-- Add women's earning rate to chat_pricing table
ALTER TABLE public.chat_pricing 
ADD COLUMN women_earning_rate numeric NOT NULL DEFAULT 2.00;

-- Add a comment explaining the fields
COMMENT ON COLUMN public.chat_pricing.rate_per_minute IS 'Amount men are charged per minute (INR)';
COMMENT ON COLUMN public.chat_pricing.women_earning_rate IS 'Amount women earn per minute (INR)';