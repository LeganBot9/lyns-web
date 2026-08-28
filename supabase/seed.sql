-- ============================================================================
-- LYNS — Stellenbosch starter events (recurring + one-off)
--
-- 1. Deploy, sign in on /admin, add yourself to `admins` (see schema.sql).
-- 2. Dashboard -> Authentication -> Users -> copy YOUR user UID.
-- 3. SQL Editor -> Edit -> Replace:  00000000-0000-0000-0000-000000000000
--    with your UID  (it appears twice per row) -> Run this whole file.
--
-- This file also adds the `recurrence` column if it's missing, so it works
-- whether or not you've run migration-recurrence.sql.
--
-- Times/venues are best-effort from public listings — check each against the
-- venue's own page/Instagram and fix from the admin "Live" tab. Remove them all
-- with:  delete from public.events where reviewed_by = 'YOUR-UID';
-- ============================================================================

-- make sure recurrence exists (safe to run repeatedly)
alter table public.events add column if not exists recurrence text not null default 'none';
alter table public.events drop constraint if exists events_recurrence_check;
alter table public.events add constraint events_recurrence_check
  check (recurrence in ('none','weekly','monthly'));

-- clear any previous copy of these seed rows so this file is safe to re-run
delete from public.events where title in (
  'Casa Beer Run','Stellenbosch Coffee Run','Aandklas Quiz Night','De Warenmarkt Quiz',
  'The Courtyard Cafe Quiz','Versus Friday Run','Tuesday Time Trial','Blaauwklippen Family Market',
  'Stellenbosch Slow Market','ClubPadel Social','Live Music at Daisy Jones','First Thursdays Stellenbosch',
  'Run the Bosch Trail Run','The Gratitude Run','Christmas Lights Switch-On & Night Market','Stellenbosch Woordfees'
);

-- weekly rows target the NEXT occurrence of that weekday; isodow Mon=1..Sun=7.
insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, price, description, status, reviewed_at, reviewed_by)
values
-- ---- weekly ----
('00000000-0000-0000-0000-000000000000','Casa Beer Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '17:30'),
  null,'weekly','Casa','Free',
  'A 5 km social run through town, then live music and cold drinks back at Casa. Come for the run or just the after-party.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Stellenbosch Coffee Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '07:30'),
  null,'weekly','The Braak (meeting point)','Free',
  'Easy 5 km at conversation pace, then coffee and bagels at the finish. This week''s route is posted on @stb_coffee_run.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Aandklas Quiz Night','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((4 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','Aandklas, 43a Bird Street','Free',
  'Stellenbosch''s long-running Thursday pub quiz. Grab a team, get there early for a table, play for drinks.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','De Warenmarkt Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:30'),
  null,'weekly','De Warenmarkt, Ryneveld Street','Free',
  'Midweek quiz in the food hall. It fills up fast — book a table ahead.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','The Courtyard Cafe Quiz','Nightlife',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Courtyard Cafe, Andringa Street','Free',
  'Wednesday quiz with bar-tab and milkshake-shot prizes. Doors from 7, quiz at 8.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Versus Friday Run','Sport',
  timezone('Africa/Johannesburg', (current_date + ((5 - extract(isodow from current_date)::int + 7) % 7)) + time '06:15'),
  null,'weekly','Versus, Bird Street','Free',
  'A quick 5 km loop before work. All paces welcome, social from the first step.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Tuesday Time Trial','Sport',
  timezone('Africa/Johannesburg', (current_date + ((2 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  '2 km or 3 km','weekly','The Boord (end of Van Reede Street)','Free',
  'Weekly time trial with Athletes Academy. Run your own watch and chase a PB.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Blaauwklippen Family Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((7 - extract(isodow from current_date)::int + 7) % 7)) + time '10:00'),
  '10:00 – 15:00','weekly','Blaauwklippen Wine Estate','Free entry',
  'Sunday market on the lawns: food stalls, makers, live acoustic music, and pony and tractor rides for kids.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Stellenbosch Slow Market','Markets',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '09:00'),
  '09:00 – 14:00','weekly','Oude Libertas','Free entry',
  'Saturday-morning market at Oude Libertas — coffee, pastries, seasonal produce and local makers under the oaks.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','ClubPadel Social','Sport',
  timezone('Africa/Johannesburg', (current_date + ((3 - extract(isodow from current_date)::int + 7) % 7)) + time '18:00'),
  null,'weekly','ClubPadel, Woodmill Lifestyle Centre','Ticketed',
  'Open social padel — rotating doubles across the indoor courts, all levels. Student rates. Book your spot online.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Live Music at Daisy Jones','Music',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '20:00'),
  null,'weekly','The Daisy Jones Bar, Summerhill Wines','Ticketed',
  'Live bands most weekends at one of the country''s favourite small venues. Check the line-up before you go.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

-- ---- monthly ----
('00000000-0000-0000-0000-000000000000','First Thursdays Stellenbosch','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-09-03 17:00'),
  '17:00 – 21:00','monthly','Church Street and around','Free',
  'On the first Thursday of the month, galleries and shops stay open late. Start at the top of Church Street and wander down.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Run the Bosch Trail Run','Outdoors',
  timezone('Africa/Johannesburg', timestamp '2026-09-06 07:00'),
  null,'monthly','Coetzenburg / Jonkershoek','Ticketed',
  'Monthly guided trail run on the mountain. Distance and route are announced about a week before each one.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

-- ---- one-off ----
('00000000-0000-0000-0000-000000000000','The Gratitude Run','Sport',
  timezone('Africa/Johannesburg', timestamp '2026-09-24 17:30'),
  null,'none','Dornier Wines','Ticketed',
  'Evening fun run through the vineyards at Dornier, with food and music at the finish. Entry online.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Christmas Lights Switch-On & Night Market','Markets',
  timezone('Africa/Johannesburg', timestamp '2026-10-02 18:00'),
  'from 18:00','none','Stellenbosch town centre','Free',
  'The town Christmas lights go on, with a night market and food stalls down the main streets.',
  'approved', now(),'00000000-0000-0000-0000-000000000000'),

('00000000-0000-0000-0000-000000000000','Stellenbosch Woordfees','Arts',
  timezone('Africa/Johannesburg', timestamp '2026-10-09 10:00'),
  null,'none','Venues across Stellenbosch','Ticketed',
  'Ten days of theatre, live music, talks, film and food across town. Full programme and tickets at woordfees.co.za.',
  'approved', now(),'00000000-0000-0000-0000-000000000000');
