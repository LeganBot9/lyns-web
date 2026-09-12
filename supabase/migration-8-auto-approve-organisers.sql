-- ============================================================================
-- LYNS — migration 8: organisers are trusted on signup
--
-- Only events go through a review queue now. An organiser account works the
-- moment it's created (no more "pending organiser" approval step); nothing
-- they submit is public until you approve that specific event. You can still
-- Pause a bad-faith organiser from admin -> Queue at any time, which blocks
-- them from submitting anything new.
--
-- Safe to run more than once.
-- ============================================================================

alter table public.organisers alter column status set default 'approved';

drop policy if exists "organiser creates own profile" on public.organisers;
create policy "organiser creates own profile" on public.organisers
  for insert with check (auth.uid() = id and status = 'approved');

-- let anyone already waiting in the old queue through
update public.organisers set status = 'approved' where status = 'pending';

select count(*) as approved_organisers from public.organisers where status = 'approved';
