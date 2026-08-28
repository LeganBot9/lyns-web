# LYNS — web app

A calm, minimal way to discover events and things to do around Stellenbosch.

- **`/`** — the public app. Discover feed + Saved (saved on the device, no account).
- **`/organiser`** — organisers sign in, get verified by you, and submit events.
- **`/admin`** — your review queue. Approve organisers, approve/decline events, post events
  directly, take live events down. **Only accounts on the `admins` table can see anything here.**

Static frontend (no build step) + [Supabase](https://supabase.com) for auth, database and
image storage. Deployed on [Vercel](https://vercel.com).

```
web/
  index.html  organiser.html  admin.html
  assets/         config.js (← your keys), supabase.js, ui.js, eventform.js, *.js, styles.css
  supabase/       schema.sql (run once), seed.sql (optional demo data)
  vercel.json
```

---

## 1. Supabase

1. Create a project at [supabase.com](https://supabase.com) (free tier is fine).
2. **SQL Editor → New query →** paste all of [`supabase/schema.sql`](supabase/schema.sql) → **Run**.
3. **Project Settings → API** — copy:
   - *Project URL* → `SUPABASE_URL`
   - *Project API keys → `anon` `public`* → `SUPABASE_ANON_KEY`
4. Paste both into [`assets/config.js`](assets/config.js).
5. **Authentication → URL Configuration:**
   - *Site URL:* your Vercel URL (e.g. `https://lyns.vercel.app`) — use `http://localhost:3000`
     while developing.
   - *Redirect URLs:* add `https://YOUR-DOMAIN/organiser`, `https://YOUR-DOMAIN/admin`,
     and the `http://localhost:3000/...` versions.
6. **Authentication → Providers → Email:** make sure **Email** is on. "Confirm email" can stay on;
   sign-in uses a magic link so no passwords are involved.

> The built-in Supabase email sender is rate-limited (a few messages per hour) — fine for testing.
> Before launch, add a real SMTP provider (Resend, Postmark, Mailgun) under
> **Authentication → Emails → SMTP Settings**.

## 2. Deploy to Vercel

1. Push this repo to GitHub (the whole project, or just `web/`).
2. In Vercel: **Add New → Project →** import the repo.
3. **Framework preset:** *Other*. **Root Directory:** `web` (if you pushed the whole LYNS folder).
   No build command, no output directory — it's static.
4. Deploy. You get `https://something.vercel.app`.
5. Go back to Supabase step 1.5 and put that URL in Site URL + Redirect URLs.

**Local development:** from `web/`, run `npx serve -l 3000` (or `vercel dev`) and open
`http://localhost:3000`. Opening the files directly (`file://`) will not work — ES modules and
auth redirects need a real origin.

## 3. Make yourself the admin

1. Open `https://YOUR-DOMAIN/admin`, enter your email, click the link it sends you.
2. You'll see **"No access"** — that's correct, you're not on the list yet.
3. Supabase **→ Authentication → Users →** copy your **User UID**.
4. Supabase **→ SQL Editor →** run:
   ```sql
   insert into public.admins (user_id) values ('paste-your-uid-here');
   ```
5. Reload `/admin`. You now have the queue. To add another admin later, insert their UID the same way.

## 4. Recurring events + starter data

If your database was created before the `recurrence` column existed, run
[`supabase/migration-recurrence.sql`](supabase/migration-recurrence.sql) once (keeps your data).
If you re-run `schema.sql`, it's already included.

Then follow the steps at the top of [`supabase/seed.sql`](supabase/seed.sql) and run it — it
loads ~16 real Stellenbosch things (the beer run, coffee run, pub quizzes, weekend markets,
First Thursdays, Woordfees…). Weekly and monthly ones roll their date forward automatically.
**Check every time/venue against the source and fix from the admin "Live" tab** — they're
best-effort from public listings. Remove them all with
`delete from public.events where reviewed_by = 'YOUR-UID';`

**How recurrence works:** an event stores one `starts_at` plus `recurrence` = `none` / `weekly`
/ `monthly`. The feed shows the next occurrence and keeps showing it — no cron, no duplicate
rows. Times are stored in `Africa/Johannesburg`; the feed formats in the viewer's local zone
(fine for SA, no daylight saving).

## 5. Custom domain

Buy `lyns.co.za` (or `lyns.app`) — [domains.co.za](https://domains.co.za), Namecheap, Cloudflare.
In Vercel: **Project → Settings → Domains →** add it and follow the DNS instructions. Then update
the Supabase Site URL + Redirect URLs to the real domain.

---

## How the "only I can see pending events" guarantee works

It's enforced in the database, not the UI:

- `events` has Row Level Security on. The public policy is `status = 'approved'` — an anonymous
  or logged-in visitor **cannot read a single pending row**, whatever they do in the browser.
- Organisers can read their *own* rows (any status) and nothing else.
- The review queue reads *all* rows, allowed only by `admin reads all events`, which calls
  `is_admin()` → checks the `admins` table.
- The `admins` table has RLS on and **no policies at all**, so it's unreachable from the website.
  You edit it only from the Supabase dashboard.

So `/admin` is not "hidden" — it's genuinely locked. Someone who finds the URL and signs in
just sees "No access", and the API returns them nothing.

## Data model (quick reference)

| table | who can read | who can write |
|---|---|---|
| `events` | approved rows: everyone · own rows: organiser · all: admin | insert: approved organiser (as `pending`) or admin · update/delete: admin (organiser may edit own while `pending`) |
| `organisers` | own row · all: admin | insert: self (as `pending`) · update: admin |
| `admins` | — | dashboard only |
| storage `event-images` | public read | authenticated upload into own `{uid}/` folder |

## Common changes

- **New city:** `CITY` in `assets/config.js`, and add an `area`/`city` column + filter when you
  actually launch a second one.
- **Categories:** edit `CATS` in `assets/ui.js` **and** the `check (category in (...))` constraint
  in `schema.sql`.
- **Featured / paid placement:** add `featured boolean default false` to `events`, an admin toggle,
  and sort `featured desc, starts_at asc` in `assets/discover.js`.
