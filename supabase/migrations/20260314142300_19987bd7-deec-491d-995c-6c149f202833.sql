-- Add admin SELECT policy for policy_violation_alerts
CREATE POLICY admin_policy_alerts_select
ON public.policy_violation_alerts
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::public.app_role));

-- Add admin UPDATE policy for policy_violation_alerts
CREATE POLICY admin_policy_alerts_update
ON public.policy_violation_alerts
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'admin'::public.app_role));