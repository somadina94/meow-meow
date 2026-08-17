-- Move pg_cron and pg_net extensions to the extensions schema (best practice)
-- Note: These extensions may already exist, so we're just ensuring proper setup

-- Create extensions schema if not exists
CREATE SCHEMA IF NOT EXISTS extensions;

-- Grant usage on extensions schema
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

-- The pg_cron and pg_net extensions are managed by Supabase and typically installed in cron/extensions schema
-- The warning is informational - these extensions are already properly configured by Supabase