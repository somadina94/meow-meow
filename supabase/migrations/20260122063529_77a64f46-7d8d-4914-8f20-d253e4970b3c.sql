-- Schedule monthly rotation cron job (runs on 1st of each month at 00:05 UTC)
SELECT cron.schedule(
  'monthly-earning-rotation',
  '5 0 1 * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_functions_url') || '/monthly-earning-rotation',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);