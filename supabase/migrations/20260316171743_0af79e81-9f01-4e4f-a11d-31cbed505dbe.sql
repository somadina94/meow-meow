
-- Monthly earning rotation: runs at midnight UTC on the 1st of each month
SELECT cron.schedule(
  'monthly-earning-rotation',
  '0 0 1 * *',
  $$
  SELECT net.http_post(
    url := 'https://www.meow-meow.co.in:8443/functions/v1/monthly-earning-rotation',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body := '{"source": "cron"}'::jsonb
  ) AS request_id;
  $$
);

-- Shift scheduler monthly refresh: runs at 00:30 UTC on the 1st of each month
SELECT cron.schedule(
  'shift-scheduler-monthly-refresh',
  '30 0 1 * *',
  $$
  SELECT net.http_post(
    url := 'https://www.meow-meow.co.in:8443/functions/v1/shift-scheduler',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body := '{"action": "generate_all_shifts", "source": "cron"}'::jsonb
  ) AS request_id;
  $$
);

-- Shift scheduler daily attendance marking: runs every day at 23:55 UTC
SELECT cron.schedule(
  'shift-scheduler-daily-attendance',
  '55 23 * * *',
  $$
  SELECT net.http_post(
    url := 'https://www.meow-meow.co.in:8443/functions/v1/shift-scheduler',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"}'::jsonb,
    body := '{"action": "monthly_refresh", "source": "cron"}'::jsonb
  ) AS request_id;
  $$
);
