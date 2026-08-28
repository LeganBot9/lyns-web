-- ============================================================================
-- Migration 2 — run ONCE in the SQL editor on your existing database.
-- Keeps all your data. Safe to run more than once.
--
-- Does three things:
--   A. clears the "SECURITY DEFINER function" advisor warnings on is_admin()
--   B. clears the "Public Bucket Allows Listing" warning on event-images
--   C. adds the `residence` column for koshuis / residence events
-- ============================================================================

-- ---- A. is_admin() no longer needs elevated privileges --------------------
-- Let a signed-in user read ONLY their own admins row; then is_admin() can run
-- as the caller. They still can't see other admins or grant themselves access.
drop policy if exists "read own admin row" on public.admins;
create policy "read own admin row" on public.admins
  for select using (user_id = (select auth.uid()));

create or replace function public.is_admin()
returns boolean
language sql
security invoker
stable
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;

-- ---- B. stop the event-images bucket being listable -----------------------
-- The bucket stays public, so images still load by URL (getPublicUrl). Without
-- a SELECT policy, nobody can enumerate the bucket's file list.
drop policy if exists "event images are publicly readable" on storage.objects;

-- ---- C. residence column -------------------------------------------------
alter table public.events add column if not exists residence text;

-- ============================================================================
-- Still one manual step, in the dashboard (can't be done in SQL):
--   Authentication -> Sign In / Providers -> scroll to "Password security"
--   (or Project Settings -> Auth) -> turn ON "Prevent use of leaked passwords".
--   LYNS uses magic links, not passwords, but enabling it clears the warning.
-- ============================================================================
