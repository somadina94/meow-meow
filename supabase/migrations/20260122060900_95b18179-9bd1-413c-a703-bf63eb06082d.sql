-- Drop existing cron job
SELECT cron.unschedule(2);

-- Create new cron job to run every 5 minutes
SELECT cron.schedule(
  'ai-women-approval-every-5-mins',
  '*/5 * * * *',
  $$
  SELECT
    net.http_post(
        url:='https://www.meow-meow.co.in:8443/functions/v1/ai-women-approval',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
        body:='{"action": "auto_approve"}'::jsonb
    ) as request_id;
  $$
);