-- Run once in Supabase Dashboard > SQL Editor after replacing PASTE_CRON_SECRET_HERE.
-- The function runs at 19:00 UTC (02:00 Asia/Bangkok) every day.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

select cron.unschedule(jobid)
from cron.job
where jobname = 'fire-insurance-renewal-reminders';

select vault.create_secret(
  'https://ovaceqrzhvzgugoclxyl.supabase.co/functions/v1/send-scheduled-reminders',
  'fire_reminder_function_url',
  'URL for the daily fire insurance renewal reminder function'
);

select vault.create_secret(
  'PASTE_CRON_SECRET_HERE',
  'fire_reminder_cron_secret',
  'Shared secret for the scheduled reminder function'
);

select cron.schedule(
  'fire-insurance-renewal-reminders',
  '0 19 * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'fire_reminder_function_url' limit 1),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'fire_reminder_cron_secret' limit 1)
      ),
      body := '{}'::jsonb
    );
  $$
);
