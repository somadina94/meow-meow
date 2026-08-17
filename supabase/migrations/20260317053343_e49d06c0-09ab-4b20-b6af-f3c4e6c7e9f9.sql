-- Remove fake/seed audit log entries inserted by migration 20251206080247
-- These pollute the audit trail with fabricated admin actions
DELETE FROM public.audit_logs
WHERE admin_email IN ('admin@meowchat.com', 'moderator@meowchat.com');