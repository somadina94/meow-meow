-- Fix: Add missing SELECT RLS policy for women_availability
-- Without this, dashboards can't read availability data (all queries return empty)

-- Allow authenticated users to read women availability (for showing online/busy status)
CREATE POLICY "Authenticated users can view women availability"
ON public.women_availability
FOR SELECT
TO authenticated
USING (true);

-- Allow admins full access
CREATE POLICY "admin_women_availability_all"
ON public.women_availability
FOR ALL
TO authenticated
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));