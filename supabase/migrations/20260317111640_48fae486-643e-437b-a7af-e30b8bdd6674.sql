-- Remove orphaned shift-scheduler cron jobs (function was already deleted)
SELECT cron.unschedule('shift-scheduler-monthly-refresh');
SELECT cron.unschedule('shift-scheduler-daily-attendance');