-- ============================================================================
-- LYNS — database schema
-- Run this in: Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- The block right below RESETS the LYNS tables first, so this file always runs
-- cleanly even if an earlier attempt half-finished.
--   * Safe now: the project is new and has no real data.
--   * Once you have real organisers/events, do NOT re-run the reset block —
--     delete those four lines before running again.
-- ============================================================================

-- ---- reset (delete these 7 lines once you have real data) -------------------
drop table if exists public.events cascade;
drop table if exists public.organisers cascade;
drop table if exists public.admins cascade;
drop function if exists public.is_admin() cascade;
drop policy if exists "event images are publicly readable" on storage.objects;
drop policy if exists "authenticated uploads to own folder" on storage.objects;
drop policy if exists "authenticated updates own folder" on storage.objects;
-- ---------------------------------------------------------------------------

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- admins : who may see the review queue. This table has NO API policies, so it
-- can only be changed by you from the dashboard. Nobody can grant themselves
-- access from the website.
-- ---------------------------------------------------------------------------
create table public.admins (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.admins enable row level security;

create function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- organisers : a profile for every account that signs up to post events.
-- New profiles start 'pending'. Only you move them to 'approved'. An organiser
-- cannot submit a single event until their profile is approved.
-- ---------------------------------------------------------------------------
create table public.organisers (
  id         uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  name       text not null,
  email      text,
  phone      text,
  instagram  text,
  about      text,
  status     text not null default 'pending'
             check (status in ('pending','approved','suspended'))
);
alter table public.organisers enable row level security;

create policy "organiser reads own profile" on public.organisers
  for select using (auth.uid() = id);
create policy "admin reads all profiles" on public.organisers
  for select using (public.is_admin());
create policy "organiser creates own profile" on public.organisers
  for insert with check (auth.uid() = id and status = 'pending');
create policy "admin updates profiles" on public.organisers
  for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
create table public.events (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  organiser_id uuid not null references auth.users(id) on delete cascade,
  title        text not null,
  category     text not null
               check (category in ('Music','Nightlife','Outdoors','Sport','Arts','Markets')),
  starts_at    timestamptz not null,
  time_label   text,
  venue        text not null,
  area         text not null default 'Stellenbosch',
  price        text not null,
  description  text,
  ticket_url   text,
  image_url    text,
  status       text not null default 'pending'
               check (status in ('pending','approved','declined','archived')),
  reviewed_at  timestamptz,
  reviewed_by  uuid references auth.users(id)
);
alter table public.events enable row level security;

create index events_status_starts_idx on public.events (status, starts_at);

create policy "public reads approved events" on public.events
  for select using (status = 'approved');
create policy "organiser reads own events" on public.events
  for select using (auth.uid() = organiser_id);
create policy "admin reads all events" on public.events
  for select using (public.is_admin());

create policy "approved organiser submits event" on public.events
  for insert with check (
    auth.uid() = organiser_id
    and status = 'pending'
    and exists (
      select 1 from public.organisers o
      where o.id = auth.uid() and o.status = 'approved'
    )
  );
create policy "admin adds event directly" on public.events
  for insert with check (public.is_admin());
create policy "organiser edits own pending event" on public.events
  for update using (auth.uid() = organiser_id and status = 'pending')
  with check (auth.uid() = organiser_id and status = 'pending');
create policy "admin updates any event" on public.events
  for update using (public.is_admin()) with check (public.is_admin());
create policy "admin deletes event" on public.events
  for delete using (public.is_admin());

-- ---------------------------------------------------------------------------
-- storage : optional cover-image uploads, filed under the organiser's user id
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('event-images', 'event-images', true)
on conflict (id) do nothing;

create policy "event images are publicly readable" on storage.objects
  for select using (bucket_id = 'event-images');
create policy "authenticated uploads to own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "authenticated updates own folder" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================================
-- AFTER THIS RUNS CLEANLY:
--   1. Deploy the site, then sign in once on /admin with your own email.
--   2. Dashboard -> Authentication -> Users -> copy your user UID.
--   3. Dashboard -> SQL Editor -> run:
--        insert into public.admins (user_id) values ('<your-uid>');
--   4. Reload /admin — you have the review queue. Nobody else does.
-- ============================================================================
