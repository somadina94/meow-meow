-- Schedule daily platform metrics update at midnight UTC
SELECT cron.schedule(
  'update-daily-platform-metrics',
  '0 0 * * *',
  $$SELECT public.update_daily_platform_metrics();$$
);