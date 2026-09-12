# LYNS — web app

A calm, minimal way to discover events and things to do around Stellenbosch.
Live at **https://lynsapp.co.za** (Vercel project `lyns-webb`, Supabase ref
`khjmlidomgwpyxdjhkwt`).

- **`/`** — the public app. Discover feed + Saved (saved on the device, no account).
  Deep links: `/?tab=saved`, `/?cat=Music`, `/?q=quiz`.
- **`/organiser`** — organisers create an email + password account, get verified by you,
  and submit events. Magic-link sign-in is kept as a fallback.
- **`/admin`** — your review queue. Approve organisers, approve/decline events, post events
  directly, take live events down. **Locked to accounts on the `admins` table, and each
  admin login also needs a TOTP code (see "Admin security" below).**

Static frontend (no build step) + [Supabase](https://supabase.com) for auth, database and
image storage. Deployed on [Vercel](https://vercel.com).

```
web/
  index.html  organiser.html  admin.html
  assets/         config.js (← your keys), supabase.js, ui.js, eventform.js, *.js, styles.css
  supabase/       schema.sql (fresh setup), migration-*.sql (one-off updates),
                  seed.sql (starter events), dedupe.sql (cleanup)
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
   - *Site URL:* `https://lynsapp.co.za` — use `http://localhost:3000` while developing.
   - *Redirect URLs:* add `https://lynsapp.co.za/**` (and `http://localhost:3000/**` for dev).
6. **Authentication → Providers → Email:** make sure **Email** is on, and turn
   **"Confirm email" OFF** — organisers sign up with email + password and are manually
   approved anyway, so the confirmation round-trip is just friction. (Admins use a magic
   link; organisers can also fall back to one.)

### Email / SMTP (do this before real testing)

Supabase's built-in email sender caps at **~2–4 messages per hour** — you'll hit
`email rate limit exceeded` fast once other people start signing in. Fix it with your own SMTP
under **Authentication → Emails → SMTP Settings** (then raise the limits under
**Authentication → Rate Limits**):

- **Quick, no domain needed — Gmail:** turn on 2-step verification on the Google account →
  create an **App Password** (Google Account → Security → App passwords) → in Supabase set
  host `smtp.gmail.com`, port `465`, user + sender = your Gmail address, password = the app
  password. ~500/day. Fine for testing; mail comes "from" your personal address.
- **Proper — Resend:** sign up at resend.com (3,000/month free), verify a domain (needs
  `lynsapp.co.za`), create an SMTP credential, paste host `smtp.resend.com` port `465` + the key.
  Branded "from" address, best deliverability.

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

## 4. One-shot setup / update

After `schema.sql`, just run **[`supabase/setup-all.sql`](supabase/setup-all.sql)** — it applies
every later change at once (recurring-events column, residence column, organiser logo column,
the security-advisor fixes, storage policies, auto-archive cron, the admin guard functions and
the 2FA / factor-lock tables), **makes you the admin**, and loads the ~20 Stellenbosch starter
events. The admin UID is baked into that file — change it there if it's ever a different account.

**Safe to re-run.** Starter events use `INSERT … WHERE NOT EXISTS`, so a re-run never
duplicates them and never overwrites a cover photo, time or venue you've since fixed from
admin → Live. (To reload a starter event from scratch, delete it in admin first.)

The individual `migration-*.sql` / `seed.sql` / `dedupe.sql` / `admin-mfa.sql` files still
exist for piecemeal use, but `setup-all.sql` covers all of them.

**Check every seeded time/venue against the source and fix from the admin "Live" tab** — they're
best-effort from public listings.

## Admin security

`/admin` is gated three ways:

1. **`admins` table** — RLS lets a signed-in user read only their own row, and there is no
   insert policy, so admin can only be granted from the Supabase dashboard / SQL editor.
2. **TOTP two-factor** — `is_admin_mfa()` requires the session to be `aal2`. It's enforced in
   the RLS read policies *and* inside every `admin_*` write function, not just in the page.
   First login walks you through authenticator enrolment; every login after asks for the code.
3. **Factor lock** — `public.admin_mfa` records the first authenticator you ever verify. A
   second authenticator someone adds later is rejected ("Blocked" screen). Clear that row from
   the dashboard if you genuinely need to re-enrol.

Recover a lost authenticator: Supabase → Authentication → Users → your user → remove the
factor, then delete the `admin_mfa` row, then sign in and re-enrol.

The `lynsStellie@gmail.com` inbox is the real front door — keep Google 2-Step Verification on
for it.

**How recurrence works:** an event stores one `starts_at` plus `recurrence` = `none` / `weekly`
/ `monthly`. The feed shows the next occurrence and keeps showing it — no cron, no duplicate
rows. Times are stored in `Africa/Johannesburg`; the feed formats in the viewer's local zone
(fine for SA, no daylight saving).

## 5. Custom domain — done

`lynsapp.co.za` is registered (domains.co.za) and pointed at Vercel. Supabase Site URL +
Redirect URLs include `https://lynsapp.co.za/**`. If you ever move it: Vercel → Project →
Settings → Domains, then update the Supabase auth URLs to match.

## 6. Store apps

Packaged for Google Play with PWABuilder → TWA. Android package id `za.co.lynsapp.twa`;
`.well-known/assetlinks.json` holds the signing-key fingerprint so the installed app opens
with no address bar. Listing assets (screenshots, feature graphic, copy) live in
`../store-listing/`. See that folder's README.

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
| `events` | approved rows: everyone · own rows: organiser · all: admin | insert: any organiser (as `pending`) or admin · update/delete: admin (organiser may edit own while `pending`) |
| `organisers` | own row · all: admin | insert: self (auto-`approved`) · update: admin |
| `admins` | — | dashboard only |
| storage `event-images` | public read | authenticated upload into own `{uid}/` folder |

## Common changes

- **New city:** `CITY` in `assets/config.js`, and add an `area`/`city` column + filter when you
  actually launch a second one.
- **Categories:** edit `CATS` in `assets/ui.js` **and** the `check (category in (...))` constraint
  in `schema.sql`.
- **Featured / paid placement:** add `featured boolean default false` to `events`, an admin toggle,
  and sort `featured desc, starts_at asc` in `assets/discover.js`.
