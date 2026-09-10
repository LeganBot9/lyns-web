-- ============================================================================
-- LYNS — migration 6: more Stellenbosch events (Sept 2026 research pass)
--
-- Run once in the Supabase SQL editor. Safe to re-run — each event is only
-- inserted if a row with that title doesn't already exist, so it never
-- duplicates and never touches an event you've edited in admin.
--
-- Sources: venue socials, parkrun.co.za, first-thursdays.co.za, visitstellenbosch,
-- capetownmagazine, woordfees.co.za. TIMES AND VENUES ARE BEST-EFFORT — check
-- each against the source and fix from admin -> Live before you lean on it.
--
-- These use generated cover images. Add real photos from admin -> Live -> "Add
-- photo" (the "photo shopping list" note that came with this file says where to
-- grab each one).
-- ============================================================================

insert into public.events
  (organiser_id, title, category, starts_at, time_label, recurrence, venue, residence, price, description, ticket_url, status, reviewed_at, reviewed_by)
select v.organiser_id, v.title, v.category, v.starts_at, v.time_label, v.recurrence,
       v.venue, v.residence, v.price, v.description, v.ticket_url, 'approved', now(), v.reviewed_by
from (values

-- ---- weekly -------------------------------------------------------------
('f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid,'Root44 parkrun','Sport',
  timezone('Africa/Johannesburg', (current_date + ((6 - extract(isodow from current_date)::int + 7) % 7)) + time '08:00'),
  null::text,'weekly','Root 44 Market, cnr R44 & Annandale Road',null::text,'Free',
  'A free, timed 5 km run or walk every Saturday morning — run it, jog it, or push a pram. Register once at parkrun.co.za, bring your barcode, coffee after.',
  'https://www.parkrun.co.za/root44/'::text,
  'f985f322-0ef1-48d7-a632-8aa72dcadf42'::uuid),

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

-- ---- dated one-offs ---------------------------------------------------
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

-- de-dupe safety net
delete from public.events e
using (
  select id, row_number() over (partition by title, venue, starts_at order by created_at, id) as rn
  from public.events
) d
where e.id = d.id and d.rn > 1;

select count(*) as approved_events from public.events where status = 'approved';
