SELECT cron.unschedule('monthly-payout-processor-daily-ist-midnight') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monthly-payout-processor-daily-ist-midnight');

SELECT cron.schedule(
  'monthly-payout-processor-daily-ist-midnight',
  '30 18 * * *',
  $cron$ select net.http_post(
    url:='https://www.meow-meow.co.in:8443/functions/v1/monthly-payout-processor',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body:=concat('{"scheduled_at": "', now(), '"}')::jsonb
  ) as request_id; $cron$
);