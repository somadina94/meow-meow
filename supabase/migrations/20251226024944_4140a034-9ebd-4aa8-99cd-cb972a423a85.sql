-- Delete duplicate chat_pricing rows, keeping only the most recent one
DELETE FROM chat_pricing 
WHERE id NOT IN (
  SELECT id FROM chat_pricing 
  ORDER BY updated_at DESC 
  LIMIT 1
);

-- Add unique constraint to ensure only one active pricing exists
-- First drop if exists, then create
DO $$ 
BEGIN
  -- Create unique partial index to ensure only one active pricing
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'unique_active_chat_pricing'
  ) THEN
    CREATE UNIQUE INDEX unique_active_chat_pricing 
    ON chat_pricing (is_active) 
    WHERE is_active = true;
  END IF;
END $$;