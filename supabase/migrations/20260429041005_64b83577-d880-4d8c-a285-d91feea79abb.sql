-- Remove all billing and statement business logic
-- Wallet/statement table STRUCTURES are preserved

DROP FUNCTION IF EXISTS public.process_call_billing(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_gift_transaction(uuid, uuid, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.process_group_tip(uuid, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.process_group_tip(uuid, uuid, uuid, numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.ledger_bill_session(uuid, text, uuid, uuid, integer, numeric, numeric, integer) CASCADE;
DROP FUNCTION IF EXISTS public.init_video_call_billing() CASCADE;

DROP FUNCTION IF EXISTS public.admin_get_statement_detail(uuid, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.admin_search_statements(uuid, integer, integer, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.generate_monthly_statement(uuid, integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.get_my_statement_detail(integer, integer) CASCADE;
DROP FUNCTION IF EXISTS public.get_my_statement_summary(integer, integer) CASCADE;

DROP FUNCTION IF EXISTS public.validate_financial_sot() CASCADE;
