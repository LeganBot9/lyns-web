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
values ('f985f322-0ef1-48d7-a632-8aa72dcadf42')
on conflict (user_id) do nothing;

-- ---- 5. Stellenbosch starter events ------------------------------------
-- Each event is only inserted if no row with that title exists yet, so
-- re-running this file is safe: it never duplicates, and it never overwrites
-- a cover photo, time or venue you've since fixed from admin -> Live.
-- (To reload a starter event from scratch, delete it in admin first.)
-- Weekly rows target the next occurrence of that weekday (isodow Mon=1..Sun=7);
-- times are stored as Africa/Johannesburg local.
insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, status, reviewed_at, reviewed_by)
select v.organiser_id, v.title, v.category, v.starts_at, v.time_label, v.recurrence,
       v.venue, v.residence, v.price, v.description, 'approved', now(), v.reviewed_by
from (values
('f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid,'Casa Beer Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '17:30'),
  null::text,'weekly','Casa',null::text,'Free',
  'A 5 km social run through town, then live music and cold drinks back at Casa. Come for the run or just the after-party.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Stellenbosch Coffee Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '17:00'),
  '17:00 for a 17:15 start','weekly','Sox / Mood Cafe (cnr Andringa & Dorp)',null,'Free',
  'Casual 5 km at conversation pace, then coffee and bagels at the finish. All paces welcome. Route on @stb_coffee_run.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Stellies Shakeout Trail Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  null,'weekly','Coetzenburg (meet at the track)',null,'Free',
  'Social trail run with the SSO crew — four pace groups so no one gets dropped. Free to join, everyone welcome. @stelliesshakeout.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Aandklas Quiz Night','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','Aandklas, 43a Bird Street',null,'Free',
  'Stellenbosch''s long-running Thursday pub quiz. Grab a team, get there early for a table, play for drinks.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','De Warenmarkt Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:30'),
  null,'weekly','De Warenmarkt, Ryneveld Street',null,'Free',
  'Midweek quiz in the food hall. It fills up fast — book a table ahead.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','The Courtyard Cafe Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Courtyard Cafe, Andringa Street',null,'Free',
  'Wednesday quiz with bar-tab and milkshake-shot prizes. Doors from 7, quiz at 8.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Versus Friday Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((5 - extract(isodow from current_date)::int + 7) % 7)) + time '06:15'),
  null,'weekly','Versus, Bird Street',null,'Free',
  'A quick 5 km loop before work. All paces welcome, social from the first step.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Tuesday Time Trial','Sport',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  '2 km or 3 km','weekly','The Boord (end of Van Reede Street)',null,'Free',
  'Weekly time trial with Athletes Academy. Run your own watch and chase a PB.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Blaauwklippen Family Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((7 - extract(isodow from current_date)::int + 7) % 7)) + time '10:00'),
  '10:00 – 15:00','weekly','Blaauwklippen Wine Estate',null,'Free entry',
  'Sunday market on the lawns: food stalls, makers, live acoustic music, and pony and tractor rides for kids.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Stellenbosch Slow Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '09:00'),
  '09:00 – 14:00','weekly','Oude Libertas',null,'Free entry',
  'Saturday-morning market at Oude Libertas — coffee, pastries, seasonal produce and local makers under the oaks.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','ClubPadel Social','Sport',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  null,'weekly','ClubPadel, Woodmill Lifestyle Centre',null,'Ticketed',
  'Open social padel — rotating doubles across the indoor courts, all levels. Student rates. Book your spot online.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Live Music at Daisy Jones','Music',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Daisy Jones Bar, Summerhill Wines',null,'Ticketed',
  'Live bands most weekends at one of the country''s favourite small venues. Check the line-up before you go.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','First Thursdays Stellenbosch','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-03 17:00'),
  '17:00 – 21:00','monthly','Church Street and around',null,'Free',
  'On the first Thursday of the month, galleries and shops stay open late. Start at the top of Church Street and wander down.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Run the Bosch Trail Run','Outdoors',
  timezone('Africa/Johannesburg', timestamp '2026-09-06 07:00'),
  null,'monthly','Coetzenburg / Jonkershoek',null,'Ticketed',
  'Monthly guided trail run on the mountain. Distance and route are announced about a week before each one.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','The Gratitude Run','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-24 17:30'),
  null,'none','Dornier Wines',null,'Ticketed',
  'Evening fun run through the vineyards at Dornier, with food and music at the finish. Entry online.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Christmas Lights Switch-On & Night Market','Markets',
  timezone('Africa/Johannesburg', timestamp '2026-10-02 18:00'),
  'from 18:00','none','Stellenbosch town centre',null,'Free',
  'The town Christmas lights go on, with a night market and food stalls down the main streets.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Stellenbosch Woordfees','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-09 10:00'),
  null,'none','Venues across Stellenbosch',null,'Ticketed',
  'Ten days of theatre, live music, talks, film and food across town. Full programme and tickets at woordfees.co.za.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

-- residence events (show the Residence filter chip)
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Wilgenhof Serenade Practice','Music',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '19:30'),
  null,'weekly','Wilgenhof dining hall','Wilgenhof','Free',
  'Weekly serenade rehearsal, open to anyone in res who wants to sing. New voices always welcome.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Dagbreek vs Simonsberg','Sport',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7) + 7) + time '14:00'),
  null,'none','Coetzenburg B-field','Dagbreek','Free',
  'Inter-res rugby derby. Wear your colours, stands open an hour before kick-off.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'),

('f985f322-0ef1-48d7-a632-8aa72dcadf42','Huis ten Bosch Open Mic','Arts',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7) + 7) + time '20:00'),
  null,'none','Huis ten Bosch common room','Huis ten Bosch','Free',
  'Music, poetry and stand-up from residents and guests. Sign up on the night.',
  'f985f322-0ef1-48d7-a632-8aa72dcadf42')
) as v(organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, reviewed_by)
where not exists (select 1 from public.events e where e.title = v.title);

-- more Stellenbosch events (research pass, Sept 2026 — see migration-6-more-events.sql).
-- Same rule: only inserted if the title doesn't already exist. Verify times/venues.
insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, ticket_url, status, reviewed_at, reviewed_by)
select v.organiser_id, v.title, v.category, v.starts_at, v.time_label, v.recurrence,
       v.venue, v.residence, v.price, v.description, v.ticket_url, 'approved', now(), v.reviewed_by
from (values
('f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid,'Root44 parkrun','Sport',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '08:00'),
  null::text,'weekly','Root 44 Market, cnr R44 & Annandale Road',null::text,'Free',
  'A free, timed 5 km run or walk every Saturday morning — run it, jog it, or push a pram. Register once at parkrun.co.za, bring your barcode, coffee after.',
  'https://www.parkrun.co.za/root44/'::text,'f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Aandklas Karaoke','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '21:00'),
  'Tuesdays & Wednesdays','weekly','Aandklas, 43a Bird Street',null,'Free',
  'Karaoke every Tuesday and Wednesday. Put your name down at the bar and commit to the bit.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Tiger''s Milk Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '19:00'),
  null,'weekly','Tiger''s Milk, Andringa Street',null,'Free',
  'Tuesday-night pub quiz, free to enter. Get there early for a table; the kitchen runs late.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Bohemia Student Wednesday','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '21:00'),
  null,'weekly','Bohemia, cnr Andringa & Victoria Street',null,'Free',
  'The Wednesday student night — live music early, a DJ later, and the kitchen going until 2am.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Live Music at Die Mystic Boer','Music',
  timezone('Africa/Johannesburg', (current_date + ((5 - extract(isodow from current_date)::int + 7) % 7)) + time '21:00'),
  null,'weekly','Die Mystic Boer, Victoria Street',null,'Ticketed',
  'Local bands under the psychedelic posters, most Friday and Saturday nights. Check their socials for who''s on.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Middelvlei Boerebraai','Outdoors',
  timezone('Africa/Johannesburg', (current_date + ((7 - extract(isodow from current_date)::int + 7) % 7)) + time '12:00'),
  '12:00 – 15:00 · Wed–Sun','weekly','Middelvlei Wine Estate',null,'R320',
  'A proper Cape boerebraai on the lawns — lamb, wors, sosaties, potbrood and all the sides (potjie in winter). Wednesday to Sunday; book ahead.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','The Met Opera: Twenty Years of The Met','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-21 14:00'),
  null,'none','Neelsie Cinema, Merriman Avenue',null,'R175',
  'The Metropolitan Opera''s twenty-year retrospective, screened in HD at the Neelsie.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Toyota Stellenbosch Woordfees: Music Evenings','Music',
  timezone('Africa/Johannesburg', timestamp '2026-10-08 18:00'),
  '8–11 October','none','Stellenbosch town centre',null,'Ticketed',
  'Four evenings of live music under the stars as part of the Woordfees (3–11 Oct, theme "It''s About Time!"). Full line-up and tickets at woordfees.co.za.',
  'https://woordfees.co.za','f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','The Met Opera: Cosi fan tutte','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-12 14:00'),
  null,'none','Neelsie Cinema, Merriman Avenue',null,'R175',
  'Mozart''s comedy of two sisters, two soldiers and a reckless bet — the Met''s production, screened at the Neelsie.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Great Art on Screen: Munch','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-19 17:00'),
  null,'none','Neelsie Cinema, Merriman Avenue',null,'R100',
  'A cinema documentary on Edvard Munch — the man behind a great deal more than "The Scream".',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42')
) as v(organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, ticket_url, reviewed_by)
where not exists (select 1 from public.events e where e.title = v.title);

-- yet more Stellenbosch events (research pass, 11 Sept 2026 — see migration-7-more-events.sql)
insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, ticket_url, status, reviewed_at, reviewed_by)
select v.organiser_id, v.title, v.category, v.starts_at, v.time_label, v.recurrence,
       v.venue, v.residence, v.price, v.description, v.ticket_url, 'approved', now(), v.reviewed_by
from (values
('f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid,'Oktoberfest at Kapstadt Brauhaus','Nightlife',
  timezone('Africa/Johannesburg', timestamp '2026-10-02 18:00'),
  '2 & 3 October','none','Kapstadt Brauhaus, 98 Dorp Street',null::text,'Free entry',
  'Two days of proper Oktoberfest energy at the Brauhaus — drinks specials, competitions, and lederhosen or a dirndl strongly encouraged. Prizes on the night, including a year''s supply of beer.',
  null::text,'f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Conrad Koch''s Chester''s Got Talent','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-18 19:00'),
  null,'none','48 Alexander Street',null,'Ticketed',
  'Conrad Koch and Chester the puppet host a talent-show comedy night — sharp, silly, and very South African.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','TITAN Trail Run: Devonbosch','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-12 07:00'),
  null,'none','Devonbosch, Stellenbosch',null,'Ticketed',
  'A trail race through the Devonbosch reserve — distances for every level, music and a proper finish-line vibe.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Beards, Bikes & Beers','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-13 08:30'),
  null,'none','Dirtopia Trail Centre, Muratie Wine Farm',null,'Ticketed',
  'A morning on the MTB trails at Dirtopia, wrapped up with beers at Muratie. Bring your own bike.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Norsemen Spring Equinox Festival of Trails','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-23 17:45'),
  '17:45 – 22:00','none','Casa Cerveza',null,'Ticketed',
  'An evening trail-running festival to mark the equinox — night trails, then food and drinks at Casa Cerveza.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Sunset to Full Moon Hike at Muratie','Outdoors',
  timezone('Africa/Johannesburg', timestamp '2026-09-25 16:45'),
  null,'none','Muratie Wine Farm, Knorhoek Road',null,'Ticketed',
  'A guided sunset hike timed to the full moon, finishing with wine at Muratie as it gets dark.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','SUBG Rare Plant Market','Markets',
  timezone('Africa/Johannesburg', timestamp '2026-10-03 08:00'),
  '3–4 October, 8:00 – 15:00','none','Stellenbosch University Botanical Garden',null,'Free entry',
  'Indigenous and rare succulent nursery stalls set up in the botanical garden. Come for the plants, stay for the coffee cart.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Woordfees Long Table','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-02 18:30'),
  null,'none','Ryneveld Street',null,'Ticketed',
  'Communal long tables down Ryneveld Street for a Woordfees dinner under the oaks — part of the festival''s food programme.',
  'https://woordfees.co.za','f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','An Italian Songbook: Salon Music','Music',
  timezone('Africa/Johannesburg', timestamp '2026-10-04 11:00'),
  null,'none','Endler Hall, SU Music Building',null,'Ticketed',
  'An intimate vocal recital in the Conservatoire''s Endler Hall, part of the Salon Music series.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Spoegwolf at Jan Marais Nature Reserve','Music',
  timezone('Africa/Johannesburg', timestamp '2026-10-08 18:00'),
  null,'none','Jan Marais Nature Reserve',null,'Ticketed',
  'Afrikaans rock outdoors at the nature reserve — Spoegwolf, with Van der Aven support.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42'),
('f985f322-0ef1-48d7-a632-8aa72dcadf42','Jeremy Loops at Jan Marais Nature Reserve','Music',
  timezone('Africa/Johannesburg', timestamp '2026-10-10 18:00'),
  null,'none','Jan Marais Nature Reserve',null,'Ticketed',
  'Jeremy Loops live outdoors at the nature reserve, with Tessi Nandi opening.',
  null,'f985f322-0ef1-48d7-a632-8aa72dcadf42')
) as v(organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, ticket_url, reviewed_by)
where not exists (select 1 from public.events e where e.title = v.title);

-- ticket links we actually know (only fills blanks — never clobbers one you set)
update public.events set ticket_url = 'https://woordfees.co.za'
  where title = 'Stellenbosch Woordfees' and ticket_url is null;

-- cover photos, served from the repo (web/seed-images/). Only fills events that
-- have no photo yet, so a re-run never replaces one you've changed in admin.
-- To swap any of these: admin -> Live -> "Change photo".
update public.events e set image_url = 'https://lynsapp.co.za/seed-images/' || m.file
from (values
  ('De Warenmarkt Quiz',                        'warenmarkt-quiz.jpg'),
  ('Stellenbosch Coffee Run',                   'coffee-run.jpg'),
  ('Aandklas Quiz Night',                       'aandklas-quiz.jpg'),
  ('Stellies Shakeout Trail Run',               'shakeout-trail-run.jpg'),
  ('Run the Bosch Trail Run',                   'run-the-bosch.jpg'),
  ('The Gratitude Run',                         'gratitude-run.jpg'),
  ('Christmas Lights Switch-On & Night Market', 'christmas-lights.jpg'),
  ('Stellenbosch Slow Market',                  'slow-market.jpg'),
  ('ClubPadel Social',                          'clubpadel-social.jpg'),
  ('Live Music at Daisy Jones',                 'daisy-jones.jpg')
) as m(title, file)
where e.title = m.title and e.image_url is null;

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

create or replace function public._log_admin(p_action text, p_target uuid, p_detail text default null)
returns void language sql security definer set search_path = public as $$
  insert into public.admin_log (actor, action, target, detail)
  values (auth.uid(), p_action, p_target, p_detail);
$$;

-- ---- 9. two-factor for admin: is_admin_mfa() = on the list AND passed 2FA --
create or replace function public.is_admin_mfa()
returns boolean language sql stable security invoker set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()))
     and coalesce(((select auth.jwt()) ->> 'aal'), 'aal1') = 'aal2';
$$;

-- factor lock: the FIRST authenticator ever verified is the only one that
-- counts. Claimed once by the app; a row here can only be cleared from the
-- Supabase dashboard, so a second authenticator can't be swapped in.
create table if not exists public.admin_mfa (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  factor_id  text not null,
  claimed_at timestamptz not null default now()
);
alter table public.admin_mfa enable row level security;
drop policy if exists "read own mfa lock" on public.admin_mfa;
create policy "read own mfa lock" on public.admin_mfa
  for select using (user_id = (select auth.uid()));
drop policy if exists "claim mfa lock once" on public.admin_mfa;
create policy "claim mfa lock once" on public.admin_mfa
  for insert with check (
    user_id = (select auth.uid())
    and not exists (select 1 from public.admin_mfa m where m.user_id = (select auth.uid()))
  );
-- no update/delete policy: reset only from the dashboard / SQL editor.

-- admin reads + the direct-add insert require 2FA
drop policy if exists "admin reads all events" on public.events;
create policy "admin reads all events" on public.events for select using (public.is_admin_mfa());
drop policy if exists "admin reads all profiles" on public.organisers;
create policy "admin reads all profiles" on public.organisers for select using (public.is_admin_mfa());
drop policy if exists "admins read the log" on public.admin_log;
create policy "admins read the log" on public.admin_log for select using (public.is_admin_mfa());
drop policy if exists "admin adds event directly" on public.events;
create policy "admin adds event directly" on public.events for insert with check (public.is_admin_mfa());

-- every guarded write also requires 2FA
create or replace function public.admin_set_event_status(p_id uuid, p_status text)
returns public.events language plpgsql security definer set search_path = public as $$
declare r public.events;
begin
  if not public.is_admin_mfa() then raise exception 'Admin 2FA required.' using errcode = '42501'; end if;
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
  if not public.is_admin_mfa() then raise exception 'Admin 2FA required.' using errcode = '42501'; end if;
  if p_status not in ('pending','approved','suspended') then raise exception 'Invalid status: %', p_status; end if;
  update public.organisers set status = p_status where id = p_id returning * into r;
  if r.id is null then raise exception 'Organiser not found.'; end if;
  perform public._log_admin('organiser:' || p_status, p_id, r.name);
  return r;
end; $$;

create or replace function public.admin_set_event_image(p_id uuid, p_url text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin_mfa() then raise exception 'Admin 2FA required.' using errcode = '42501'; end if;
  update public.events set image_url = p_url where id = p_id;
  if not found then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:image', p_id, p_url);
end; $$;

create or replace function public.admin_delete_event(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.events;
begin
  if not public.is_admin_mfa() then raise exception 'Admin 2FA required.' using errcode = '42501'; end if;
  delete from public.events where id = p_id returning * into r;
  if r.id is null then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:deleted', p_id, r.title);
end; $$;

-- direct admin writes no longer needed from the client — remove the broad policies
drop policy if exists "admin updates any event"   on public.events;
drop policy if exists "admin deletes event"       on public.events;
drop policy if exists "admin updates profiles"    on public.organisers;

-- ---- 10. organisers are trusted on signup — only events need your approval ----
-- Only events go through a queue now. An organiser account works the moment
-- it's created; nothing they submit is public until you approve that specific
-- event. You can still Pause a bad-faith organiser from admin -> Queue at any
-- time, which blocks them from submitting anything new.
alter table public.organisers alter column status set default 'approved';
drop policy if exists "organiser creates own profile" on public.organisers;
create policy "organiser creates own profile" on public.organisers
  for insert with check (auth.uid() = id and status = 'approved');
-- let anyone already waiting in the old queue through
update public.organisers set status = 'approved' where status = 'pending';

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
