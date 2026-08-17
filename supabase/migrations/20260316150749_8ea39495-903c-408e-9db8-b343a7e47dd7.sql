-- Schedule cron job to collect system metrics every minute
SELECT cron.schedule(
  'collect-system-metrics',
  '* * * * *',
  $$
  SELECT net.http_post(
    url:='https://www.meow-meow.co.in:8443/functions/v1/collect-metrics',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body:='{"source": "cron"}'::jsonb
  ) AS request_id;
  $$
);