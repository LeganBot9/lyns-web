-- ============================================================================
-- Migration: add recurring events (weekly / monthly).
-- Run this ONCE in the SQL editor if your database was created before the
-- `recurrence` column existed. It keeps all existing data.
--
-- (If you'd rather start clean, just re-run schema.sql — its reset block wipes
--  the LYNS tables first. Only do that while you have no real data.)
-- ============================================================================

alter table public.events
  add column if not exists recurrence text not null default 'none';

alter table public.events
  drop constraint if exists events_recurrence_check;

alter table public.events
  add constraint events_recurrence_check
  check (recurrence in ('none','weekly','monthly'));
