-- Schedule attachment-cleanup edge function every 2 hours (deletes files > 1h old).
do $$
declare
  proj text := current_setting('app.settings.project_ref', true);
  fn_url text;
begin
  if proj is null or proj = '' then
    raise notice 'app.settings.project_ref not set — self-hosted deployments must schedule attachment-cleanup manually.';
    return;
  end if;
  fn_url := 'https://' || proj || '.functions.www.meow-meow.co.in:8443/attachment-cleanup';

  if exists (select 1 from cron.job where jobname = 'attachment_cleanup_every_2h') then
    perform cron.unschedule('attachment_cleanup_every_2h');
  end if;

  perform cron.schedule(
    'attachment_cleanup_every_2h',
    '0 */2 * * *',
    format($f$select net.http_post(url:=%L, headers:=jsonb_build_object('content-type','application/json'), body:='{}'::jsonb);$f$, fn_url)
  );
exception when others then
  raise notice 'cron.schedule not available: %', sqlerrm;
end $$;
