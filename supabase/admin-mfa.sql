-- ============================================================================
-- Require two-factor auth (TOTP) for the admin area. Run ONCE. Safe to re-run.
--
-- After this: reaching the admin queue needs BOTH
--   1. a magic-link sign-in from an email whose UID is in public.admins, AND
--   2. a 6-digit code from an authenticator app (set up on first login)
--
-- The database enforces it — not just the page. Reads of pending events /
-- organisers / the audit log, and every admin write, check that the current
-- session passed 2FA (aal2).
--
-- TOTP MFA is on by default in Supabase; no dashboard toggle needed.
-- ============================================================================

-- on the admin list AND this session completed 2FA
create or replace function public.is_admin_mfa()
returns boolean
language sql stable security invoker
set search_path = ''
as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()))
     and coalesce(((select auth.jwt()) ->> 'aal'), 'aal1') = 'aal2';
$$;

-- ---- reads: 2FA required ------------------------------------------------
drop policy if exists "admin reads all events" on public.events;
create policy "admin reads all events" on public.events
  for select using (public.is_admin_mfa());

drop policy if exists "admin reads all profiles" on public.organisers;
create policy "admin reads all profiles" on public.organisers
  for select using (public.is_admin_mfa());

drop policy if exists "admins read the log" on public.admin_log;
create policy "admins read the log" on public.admin_log
  for select using (public.is_admin_mfa());

drop policy if exists "admin adds event directly" on public.events;
create policy "admin adds event directly" on public.events
  for insert with check (public.is_admin_mfa());

-- ---- writes: swap is_admin() -> is_admin_mfa() in every guarded function --
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

-- ============================================================================
-- FIRST LOGIN after running this:
--   /admin -> sign in -> you'll be asked to set up an authenticator app
--   (scan the QR in Google Authenticator / Authy / 1Password) -> enter a code.
--   Every login after that: magic link + 6-digit code.
-- If you lose the authenticator: Supabase dashboard -> Authentication -> Users
--   -> your user -> remove the MFA factor, then set it up again on next login.
-- ============================================================================
