-- Admin ghost mode: allow admins to read private_groups, group_messages, group_memberships
CREATE POLICY admin_private_groups_select_all ON public.private_groups
  FOR SELECT TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY admin_group_messages_select_all ON public.group_messages
  FOR SELECT TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY admin_group_memberships_select_all ON public.group_memberships
  FOR SELECT TO authenticated
  USING (has_role(auth.uid(), 'admin'::app_role));