-- ============================================================================
-- LYNS — ONE-SHOT SETUP  (run this whole file in the Supabase SQL editor)
--
-- Does everything except the two things SQL can't touch:
--   * the leaked-password toggle (dashboard — see note at the bottom)
--   * SMTP settings (dashboard)
--
-- Assumes schema.sql has been run once already (tables exist). If you're on a
-- brand-new project, run schema.sql first, then this.
--
-- Safe to run more than once. Your admin UID is baked in below.
-- ============================================================================

-- ---- 1. columns added since the first schema ------------------------------
alter table public.events     add column if not exists recurrence text not null default 'none';
alter table public.events     drop constraint if exists events_recurrence_check;
alter table public.events     add  constraint events_recurrence_check
                                   check (recurrence in ('none','weekly','monthly'));
alter table public.events     add column if not exists residence text;
alter table public.organisers add column if not exists logo_url text;

-- ---- 2. is_admin(): run as the caller, read only your own admins row ------
drop policy if exists "read own admin row" on public.admins;
create policy "read own admin row" on public.admins
  for select using (user_id = (select auth.uid()));

create or replace function public.is_admin()
returns boolean language sql security invoker stable
set search_path = ''
as $$ select exists (select 1 from public.admins where user_id = (select auth.uid())) $$;

-- ---- 3. storage: public bucket, not listable, own-folder uploads ---------
insert into storage.buckets (id, name, public)
values ('event-images','event-images', true)
on conflict (id) do nothing;

drop policy if exists "event images are publicly readable" on storage.objects;
drop policy if exists "authenticated uploads to own folder" on storage.objects;
drop policy if exists "authenticated updates own folder" on storage.objects;

create policy "authenticated uploads to own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'event-images'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "authenticated updates own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'event-images'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---- 4. make you the admin ----------------------------------------------
insert into public.admins (user_id)
values ('3e2e5f4e-5141-4408-8970-48ca6f86dd8c')
on conflict (user_id) do nothing;

-- ---- 5. Stellenbosch starter events ------------------------------------
-- Deletes its own rows first, so re-running this file never duplicates them.
-- Times/venues are best-effort — verify each and fix from admin -> Live.
delete from public.events where title in (
  'Casa Beer Run','Stellenbosch Coffee Run','Stellies Shakeout Trail Run','Aandklas Quiz Night','De Warenmarkt Quiz',
  'The Courtyard Cafe Quiz','Versus Friday Run','Tuesday Time Trial','Blaauwklippen Family Market',
  'Stellenbosch Slow Market','ClubPadel Social','Live Music at Daisy Jones','First Thursdays Stellenbosch',
  'Run the Bosch Trail Run','The Gratitude Run','Christmas Lights Switch-On & Night Market','Stellenbosch Woordfees',
  'Wilgenhof Serenade Practice','Dagbreek vs Simonsberg','Huis ten Bosch Open Mic'
);

-- weekly rows target the next occurrence of that weekday (isodow Mon=1..Sun=7);
-- times are stored as Africa/Johannesburg local.
insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, status, reviewed_at, reviewed_by)
values
('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Casa Beer Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '17:30'),
  null,'weekly','Casa',null,'Free',
  'A 5 km social run through town, then live music and cold drinks back at Casa. Come for the run or just the after-party.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Stellenbosch Coffee Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '17:00'),
  '17:00 for a 17:15 start','weekly','Sox / Mood Cafe (cnr Andringa & Dorp)',null,'Free',
  'Casual 5 km at conversation pace, then coffee and bagels at the finish. All paces welcome. Route on @stb_coffee_run.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Stellies Shakeout Trail Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  null,'weekly','Coetzenburg (meet at the track)',null,'Free',
  'Social trail run with the SSO crew — four pace groups so no one gets dropped. Free to join, everyone welcome. @stelliesshakeout.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Aandklas Quiz Night','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','Aandklas, 43a Bird Street',null,'Free',
  'Stellenbosch''s long-running Thursday pub quiz. Grab a team, get there early for a table, play for drinks.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','De Warenmarkt Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:30'),
  null,'weekly','De Warenmarkt, Ryneveld Street',null,'Free',
  'Midweek quiz in the food hall. It fills up fast — book a table ahead.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','The Courtyard Cafe Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Courtyard Cafe, Andringa Street',null,'Free',
  'Wednesday quiz with bar-tab and milkshake-shot prizes. Doors from 7, quiz at 8.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Versus Friday Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((5 - extract(isodow from current_date)::int + 7) % 7)) + time '06:15'),
  null,'weekly','Versus, Bird Street',null,'Free',
  'A quick 5 km loop before work. All paces welcome, social from the first step.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Tuesday Time Trial','Sport',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  '2 km or 3 km','weekly','The Boord (end of Van Reede Street)',null,'Free',
  'Weekly time trial with Athletes Academy. Run your own watch and chase a PB.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Blaauwklippen Family Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((7 - extract(isodow from current_date)::int + 7) % 7)) + time '10:00'),
  '10:00 – 15:00','weekly','Blaauwklippen Wine Estate',null,'Free entry',
  'Sunday market on the lawns: food stalls, makers, live acoustic music, and pony and tractor rides for kids.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Stellenbosch Slow Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '09:00'),
  '09:00 – 14:00','weekly','Oude Libertas',null,'Free entry',
  'Saturday-morning market at Oude Libertas — coffee, pastries, seasonal produce and local makers under the oaks.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','ClubPadel Social','Sport',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  null,'weekly','ClubPadel, Woodmill Lifestyle Centre',null,'Ticketed',
  'Open social padel — rotating doubles across the indoor courts, all levels. Student rates. Book your spot online.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Live Music at Daisy Jones','Music',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Daisy Jones Bar, Summerhill Wines',null,'Ticketed',
  'Live bands most weekends at one of the country''s favourite small venues. Check the line-up before you go.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','First Thursdays Stellenbosch','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-03 17:00'),
  '17:00 – 21:00','monthly','Church Street and around',null,'Free',
  'On the first Thursday of the month, galleries and shops stay open late. Start at the top of Church Street and wander down.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Run the Bosch Trail Run','Outdoors',
  timezone('Africa/Johannesburg', timestamp '2026-09-06 07:00'),
  null,'monthly','Coetzenburg / Jonkershoek',null,'Ticketed',
  'Monthly guided trail run on the mountain. Distance and route are announced about a week before each one.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','The Gratitude Run','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-24 17:30'),
  null,'none','Dornier Wines',null,'Ticketed',
  'Evening fun run through the vineyards at Dornier, with food and music at the finish. Entry online.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Christmas Lights Switch-On & Night Market','Markets',
  timezone('Africa/Johannesburg', timestamp '2026-10-02 18:00'),
  'from 18:00','none','Stellenbosch town centre',null,'Free',
  'The town Christmas lights go on, with a night market and food stalls down the main streets.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Stellenbosch Woordfees','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-09 10:00'),
  null,'none','Venues across Stellenbosch',null,'Ticketed',
  'Ten days of theatre, live music, talks, film and food across town. Full programme and tickets at woordfees.co.za.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

-- residence events (show the Residence filter chip)
('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Wilgenhof Serenade Practice','Music',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '19:30'),
  null,'weekly','Wilgenhof dining hall','Wilgenhof','Free',
  'Weekly serenade rehearsal, open to anyone in res who wants to sing. New voices always welcome.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Dagbreek vs Simonsberg','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-05 14:00'),
  null,'none','Coetzenburg B-field','Dagbreek','Free',
  'Inter-res rugby derby. Wear your colours, stands open an hour before kick-off.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c'),

('3e2e5f4e-5141-4408-8970-48ca6f86dd8c','Huis ten Bosch Open Mic','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-11 20:00'),
  null,'none','Huis ten Bosch common room','Huis ten Bosch','Free',
  'Music, poetry and stand-up from residents and guests. Sign up on the night.',
  'approved', now(),'3e2e5f4e-5141-4408-8970-48ca6f86dd8c');

-- ---- 6. de-dupe anything left over from earlier runs --------------------
delete from public.events e
using (
  select id, row_number() over (partition by title, venue, starts_at order by created_at, id) as rn
  from public.events
) d
where e.id = d.id and d.rn > 1;

-- ---- 7. auto-archive past events (daily job) ---------------------------
create extension if not exists pg_cron;

create or replace function public.archive_past_events()
returns integer language plpgsql security definer set search_path = public
as $$
declare n integer;
begin
  update public.events set status = 'archived'
  where status in ('approved','pending')
    and recurrence = 'none'
    and starts_at < date_trunc('day', now());
  get diagnostics n = row_count;
  return n;
end; $$;

select cron.schedule('lyns-archive-past-events', '0 3 * * *',
  $$ select public.archive_past_events(); $$);
select public.archive_past_events();

-- ---- 8. harden admin actions ----------------------------------------
-- Every admin change goes through a function that checks is_admin() and logs.
-- (Full comments in supabase/admin-guards.sql.)
create table if not exists public.admin_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor uuid, action text not null, target uuid, detail text
);
alter table public.admin_log enable row level security;
drop policy if exists "admins read the log" on public.admin_log;
create policy "admins read the log" on public.admin_log for select using (public.is_admin());

create or replace function public._log_admin(p_action text, p_target uuid, p_detail text default null)
returns void language sql security definer set search_path = public as $$
  insert into public.admin_log (actor, action, target, detail)
  values (auth.uid(), p_action, p_target, p_detail);
$$;

create or replace function public.admin_set_event_status(p_id uuid, p_status text)
returns public.events language plpgsql security definer set search_path = public as $$
declare r public.events;
begin
  if not public.is_admin() then raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501'; end if;
  if p_status not in ('approved','declined','archived','pending') then raise exception 'Invalid status: %', p_status; end if;
  update public.events set status = p_status, reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_id returning * into r;
  if r.id is null then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:' || p_status, p_id, r.title);
  return r;
end; $$;

create or replace function public.admin_set_organiser_status(p_id uuid, p_status text)
returns public.organisers language plpgsql security definer set search_path = public as $$
declare r public.organisers;
begin
  if not public.is_admin() then raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501'; end if;
  if p_status not in ('pending','approved','suspended') then raise exception 'Invalid status: %', p_status; end if;
  update public.organisers set status = p_status where id = p_id returning * into r;
  if r.id is null then raise exception 'Organiser not found.'; end if;
  perform public._log_admin('organiser:' || p_status, p_id, r.name);
  return r;
end; $$;

create or replace function public.admin_set_event_image(p_id uuid, p_url text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501'; end if;
  update public.events set image_url = p_url where id = p_id;
  if not found then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:image', p_id, p_url);
end; $$;

create or replace function public.admin_delete_event(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.events;
begin
  if not public.is_admin() then raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501'; end if;
  delete from public.events where id = p_id returning * into r;
  if r.id is null then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:deleted', p_id, r.title);
end; $$;

-- direct admin writes no longer needed from the client — remove the broad policies
drop policy if exists "admin updates any event"   on public.events;
drop policy if exists "admin deletes event"       on public.events;
drop policy if exists "admin updates profiles"    on public.organisers;

-- ---- done — quick check --------------------------------------------------
select
  (select count(*) from public.admins) as admins,
  (select count(*) from public.events where status = 'approved') as live_events;

-- ============================================================================
-- LAST MANUAL STEP (not possible in SQL):
--   Dashboard -> Authentication -> Sign In / Providers -> scroll to
--   "Bot and Abuse Protection" / "Password security" -> turn ON
--   "Prevent sign ups / sign ins with leaked passwords" (HaveIBeenPwned check).
--   LYNS uses magic links so it changes nothing functionally; it clears the
--   advisor warning.
-- ============================================================================
