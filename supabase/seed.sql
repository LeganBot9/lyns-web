-- ============================================================================
-- Optional: load 8 demo events so the app isn't empty on first launch.
--
-- 1. Deploy the site, sign in on /admin, and make yourself an admin
--    (see the bottom of schema.sql).
-- 2. Dashboard -> Authentication -> Users -> copy YOUR user UID.
-- 3. Replace every  00000000-0000-0000-0000-000000000000  below with that UID.
--    (In the SQL editor: Edit -> Replace, or just do it by hand — it appears twice per row.)
-- 4. Run this file in the SQL editor.
--
-- Remove them later from the admin "Live" tab, or here with:
--    delete from public.events where organiser_id = 'YOUR-UID';
-- ============================================================================

insert into public.events
  (organiser_id, title, category, starts_at, time_label, venue, area, price, description, ticket_url, status, reviewed_at, reviewed_by)
values
  ('00000000-0000-0000-0000-000000000000','Neon Winter','Nightlife', current_date + 3 + time '22:00','22:00 – late','Bohemia','Stellenbosch','R80','Full UV setup across two rooms — amapiano downstairs, house up top.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Jonkershoek Sunrise Hike','Outdoors', current_date + 4 + time '06:15', null,'Jonkershoek Gate','Stellenbosch','R55','Guided 9 km loop to the second waterfall and back. Bring a headlamp and water.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Wine & Vinyl','Music', current_date + 2 + time '18:00', null,'Blend, Dorp Street','Stellenbosch','R120','Local selectors playing soul, funk and jazz on wax. One glass included.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Maties vs UCT','Sport', current_date + 4 + time '15:00', null,'Danie Craven Stadium','Stellenbosch','R40','Varsity Cup return leg. Student section opens at 14:00.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Throwing Night','Arts', current_date + 1 + time '17:30','17:30 – 19:30','Klein Karoo Clay','Stellenbosch','R240','Two hours on the wheel, all clay and tools included. Beginners welcome.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Root44 Saturday Market','Markets', current_date + 4 + time '09:00','09:00 – 15:00','Audacia Wine Farm','Stellenbosch','Free','Around eighty stalls, acoustic sets from 11:00, dog friendly.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Open Mic Night','Music', current_date + 5 + time '20:00', null,'Die Stellenbosch Kafee','Stellenbosch','Free','Sign-up from 19:30. Poetry, acoustic sets, the odd stand-up spot.', null,'approved', now(),'00000000-0000-0000-0000-000000000000'),
  ('00000000-0000-0000-0000-000000000000','Silent Film & Live Score','Arts', current_date + 3 + time '19:30', null,'HB Thom Theatre','Stellenbosch','R110','The 1927 classic “Sunrise” with an original score performed live.', null,'approved', now(),'00000000-0000-0000-0000-000000000000');
