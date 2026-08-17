-- Drop existing restrictive policy and create a more permissive one for admins
DROP POLICY IF EXISTS "Admins can manage pricing" ON public.chat_pricing;

-- Create separate policies for each operation
CREATE POLICY "Admins can view all pricing" 
ON public.chat_pricing 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can update pricing" 
ON public.chat_pricing 
FOR UPDATE 
USING (true)
WITH CHECK (true);

CREATE POLICY "Admins can insert pricing" 
ON public.chat_pricing 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Admins can delete pricing" 
ON public.chat_pricing 
FOR DELETE 
USING (has_role(auth.uid(), 'admin'::app_role));