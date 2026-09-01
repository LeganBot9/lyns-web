-- ============================================================================
-- Harden admin actions. Run ONCE in the SQL editor. Safe to re-run.
--
-- Before: the admin page called `update events ...` directly. Row Level
-- Security still blocked non-admins, but silently (0 rows, no error), so the
-- UI could show a misleading "done" message.
--
-- After: every admin action goes through a function that FIRST checks
-- is_admin() and raises a hard error otherwise — and writes an audit row.
-- ============================================================================

-- ---- audit log -----------------------------------------------------------
create table if not exists public.admin_log (
  id     bigint generated always as identity primary key,
  at     timestamptz not null default now(),
  actor  uuid,
  action text not null,
  target uuid,
  detail text
);
alter table public.admin_log enable row level security;
drop policy if exists "admins read the log" on public.admin_log;
create policy "admins read the log" on public.admin_log
  for select using (public.is_admin());
-- no insert policy: rows are only written by the security-definer functions below.

create or replace function public._log_admin(p_action text, p_target uuid, p_detail text default null)
returns void language sql security definer set search_path = public as $$
  insert into public.admin_log (actor, action, target, detail)
  values (auth.uid(), p_action, p_target, p_detail);
$$;

-- ---- guarded event action ---------------------------------------------
create or replace function public.admin_set_event_status(p_id uuid, p_status text)
returns public.events
language plpgsql security definer set search_path = public
as $$
declare r public.events;
begin
  if not public.is_admin() then
    raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501';
  end if;
  if p_status not in ('approved','declined','archived','pending') then
    raise exception 'Invalid status: %', p_status;
  end if;
  update public.events
     set status = p_status,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   where id = p_id
  returning * into r;
  if r.id is null then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:' || p_status, p_id, r.title);
  return r;
end; $$;

-- ---- guarded organiser action ---------------------------------------
create or replace function public.admin_set_organiser_status(p_id uuid, p_status text)
returns public.organisers
language plpgsql security definer set search_path = public
as $$
declare r public.organisers;
begin
  if not public.is_admin() then
    raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501';
  end if;
  if p_status not in ('pending','approved','suspended') then
    raise exception 'Invalid status: %', p_status;
  end if;
  update public.organisers set status = p_status where id = p_id
  returning * into r;
  if r.id is null then raise exception 'Organiser not found.'; end if;
  perform public._log_admin('organiser:' || p_status, p_id, r.name);
  return r;
end; $$;

-- ---- guarded cover-image update -----------------------------------
create or replace function public.admin_set_event_image(p_id uuid, p_url text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501';
  end if;
  update public.events set image_url = p_url where id = p_id;
  if not found then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:image', p_id, p_url);
end; $$;

-- ---- guarded permanent delete --------------------------------------
create or replace function public.admin_delete_event(p_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare r public.events;
begin
  if not public.is_admin() then
    raise exception 'Not authorised — you are not a LYNS admin.' using errcode = '42501';
  end if;
  delete from public.events where id = p_id returning * into r;
  if r.id is null then raise exception 'Event not found.'; end if;
  perform public._log_admin('event:deleted', p_id, r.title);
end; $$;

-- ---- lock the tables down to the functions only --------------------
-- Direct writes are no longer needed from the client; drop the broad admin
-- write policies so the ONLY path is the guarded functions above.
drop policy if exists "admin updates any event"    on public.events;
drop policy if exists "admin adds event directly"  on public.events;
drop policy if exists "admin deletes event"        on public.events;
drop policy if exists "admin updates profiles"     on public.organisers;

-- admin still needs to INSERT events (the "Add" tab) and READ everything —
-- keep a tight insert policy, reads are already covered.
create policy "admin adds event directly" on public.events
  for insert with check (public.is_admin());

-- ============================================================================
-- After running this: reload /admin and test. A non-admin who somehow reaches
-- the page now gets a visible "Not authorised" error on every action, and
-- every real action is recorded in public.admin_log.
--   select * from public.admin_log order by at desc;
-- ============================================================================
