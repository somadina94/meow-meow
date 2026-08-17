-- Create function to get top earner for today (returns aggregated data only)
CREATE OR REPLACE FUNCTION public.get_top_earner_today()
RETURNS TABLE(user_id uuid, full_name text, total_amount numeric)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  today_start timestamp with time zone;
  today_end timestamp with time zone;
BEGIN
  -- Calculate today's start and end in UTC (will work with any timezone client)
  today_start := date_trunc('day', now());
  today_end := today_start + interval '1 day' - interval '1 second';
  
  RETURN QUERY
  SELECT 
    we.user_id,
    p.full_name,
    SUM(we.amount) as total_amount
  FROM women_earnings we
  JOIN profiles p ON p.user_id = we.user_id
  WHERE we.created_at >= today_start 
    AND we.created_at <= today_end
  GROUP BY we.user_id, p.full_name
  ORDER BY total_amount DESC
  LIMIT 1;
END;
$$;

-- Allow authenticated users to view chat pricing (earning rates)
CREATE POLICY "Authenticated users can view pricing" 
ON public.chat_pricing 
FOR SELECT 
USING (auth.uid() IS NOT NULL);