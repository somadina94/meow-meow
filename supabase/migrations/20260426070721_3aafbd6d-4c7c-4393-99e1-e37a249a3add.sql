-- Allow admins full management of user_blocks (currently restricted to self-created blocks)
CREATE POLICY "admin_user_blocks_select"
  ON public.user_blocks FOR SELECT
  USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "admin_user_blocks_insert"
  ON public.user_blocks FOR INSERT
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "admin_user_blocks_update"
  ON public.user_blocks FOR UPDATE
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));