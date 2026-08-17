
-- Schedule midnight reset of private group counts (00:00 IST = 18:30 UTC previous day)
SELECT cron.schedule(
  'reset-private-group-counts',
  '30 18 * * *',
  $$SELECT public.reset_private_group_counts()$$
);
