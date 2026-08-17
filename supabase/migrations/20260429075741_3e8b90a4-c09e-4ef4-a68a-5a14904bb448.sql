
GRANT EXECUTE ON FUNCTION public.bill_group_gift_or_tip(uuid,uuid,numeric,text,text,text) TO authenticated, service_role, anon;
NOTIFY pgrst, 'reload schema';
