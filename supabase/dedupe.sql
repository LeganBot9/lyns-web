-- ============================================================================
-- One-time cleanup: remove duplicate events (from running a seed twice).
-- Keeps the oldest copy of each (title + venue + start time), deletes the rest.
-- Safe to run more than once. Run in the SQL editor.
-- ============================================================================

delete from public.events e
using (
  select id, title, venue, starts_at,
         row_number() over (partition by title, venue, starts_at order by created_at, id) as rn
  from public.events
) dup
where e.id = dup.id
  and dup.rn > 1;

-- check what's left
select title, venue, recurrence, count(*)
from public.events
group by title, venue, recurrence
order by count(*) desc, title;
