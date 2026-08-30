-- ============================================================================
-- Auto-archive events whose date has passed.
-- Run this ONCE in the SQL editor. Safe to re-run.
--
-- What it does:
--   * a function that sets one-off events (recurrence = 'none') to 'archived'
--     once their day is over — recurring events roll forward and are left alone
--   * a daily 03:00 (UTC) cron job that calls it
--   * runs it once immediately to clean up what's already past
-- ============================================================================

-- pg_cron ships with Supabase. If this line errors, enable it first:
-- Dashboard -> Database -> Extensions -> search "pg_cron" -> toggle on.
create extension if not exists pg_cron;

create or replace function public.archive_past_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.events
    set status = 'archived'
  where status in ('approved', 'pending')
    and recurrence = 'none'
    and starts_at < date_trunc('day', now());
  get diagnostics n = row_count;
  return n;
end;
$$;

-- schedule it daily at 03:00 UTC (05:00 SAST). cron.schedule upserts by name.
select cron.schedule(
  'lyns-archive-past-events',
  '0 3 * * *',
  $$ select public.archive_past_events(); $$
);

-- clean up everything already in the past, right now
select public.archive_past_events() as archived_now;

-- to see the scheduled job:      select * from cron.job;
-- to stop it:                    select cron.unschedule('lyns-archive-past-events');
-- archived events are hidden everywhere; find them with:
--   select title, starts_at from public.events where status = 'archived' order by starts_at desc;
