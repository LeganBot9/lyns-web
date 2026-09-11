-- ============================================================================
-- LYNS — migration 7: more Stellenbosch events (11 Sept 2026 research pass)
--
-- Run once in the Supabase SQL editor. Safe to re-run — each event is only
-- inserted if a row with that title doesn't already exist.
--
-- Sources: allevents.in/stellenbosch, food-blog.co.za (Kapstadt Brauhaus
-- Oktoberfest), Daisy Jones Bar listings, SU Botanical Garden, Woordfees.
-- TIMES/PRICES ARE BEST-EFFORT — verify and fix from admin -> Live.
-- ============================================================================

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

-- de-dupe safety net
delete from public.events e
using (
  select id, row_number() over (partition by title, venue, starts_at order by created_at, id) as rn
  from public.events
) d
where e.id = d.id and d.rn > 1;

select count(*) as approved_events from public.events where status = 'approved';
