REVOKE EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.ledger_recharge(uuid,numeric,text,text,text,text) TO authenticated, service_role;