REVOKE EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_chat_billing(uuid, numeric) TO service_role;