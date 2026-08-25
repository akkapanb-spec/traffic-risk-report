# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ระบบแจ้งข้อมูลจุดเสี่ยงอุบัติเหตุ สภ.เมืองนครสวรรค์ — a traffic-risk reporting and accident-statistics system ported from Google Apps Script to static HTML + Supabase. UI text, labels, and code comments are in Thai; keep new user-facing strings in Thai.

Deployed via GitHub Pages from `main` root → https://akkapanb-spec.github.io/traffic-risk-report/
**Merging to `main` publishes to production immediately.** Work on a branch, test locally, then PR.

## Running locally

No build step, no `npm install`, no bundler. Every page is a single self-contained HTML file with inline `<style>` and `<script>`; libraries come from CDNs at runtime.

```bash
npx serve -l 3000
```

**Must be served over `http://`** — `index.html:2650` and `officer.html:1096` `fetch('data/tambon_muang.json')`, which `file://` blocks, silently killing the tambon map layer. Opening the file by double-click will look mostly fine but the subdistrict boundaries won't render.

There are no tests and no linter. Verification is manual in the browser (check both desktop and a phone-width viewport — a large share of commits are mobile-layout fixes).

## Architecture

### Two apps, one database

| Page | Audience | Data access |
|---|---|---|
| `index.html` | citizens (public) | anon key, **direct table reads** through RLS |
| `officer.html` | police officers | anon key, **everything through `SECURITY DEFINER` RPCs** |
| `sync.html` | admin | one-off tool: diff legacy GAS data vs Supabase, emit catch-up SQL |
| `videos.html` | public | campaign clips listed from a Google Drive folder |
| `cctv.html` | public | 8 DOH highway cameras, HLS player |

`index.html` reads `risk_points`, `risk_actions`, `traffic_advisories`, `deaths`, `injuries`, and the view `accidents_public` directly — these have `public read` RLS policies. `accidents` itself is **closed** to anon because it holds PII; the public page only ever sees `accidents_public` (id + `incident_datetime`, count-only).

`officer.html` never touches tables directly. Every call goes through the local `rpc(fn, args)` helper (`officer.html:737`) wrapped by `api(action, data)`. Tables `officers` / `officer_sessions` have RLS enabled with **no policies at all** — anon cannot read them by any path.

### Auth model (no Supabase Auth)

Hand-rolled, entirely in Postgres functions:

- Username = 13-digit national ID, password = its last 4 digits (`officer_login`, `sql/officer.sql`).
- Login inserts a row into `officer_sessions` with a 6-hour expiry and returns a uuid token. The token is kept in `localStorage` under `accidentTrafficPoliceSession`.
- Every protected RPC starts by calling `officer_session_user(p_token)`, which validates the token, **slides the expiry forward another 6 hours**, and returns the user JSON — or null. Callers return `{success:false, code:'AUTH_REQUIRED'}`.
- Admin-only RPCs instead call `admin_check_(p_token)` (defined in `sql/deaths_admin.sql`) which additionally requires `officers.is_admin`. `admin_check_` returns an error jsonb or null — the calling convention is `v_err := admin_check_(...); if v_err is not null then return v_err; end if;`.
- Every RPC returns `jsonb` shaped `{success, message, ...}`; they do **not** raise exceptions for business errors. New RPCs should follow this.

When adding an admin feature, the pattern is: table + RLS → `advisory_save`-style RPC guarded by `admin_check_` → a nav button in `officer.html` with class `admin-item` (each one explicitly shown/hidden in `showApp()`, `officer.html:1231`, based on `state.user.isAdmin` — adding a button means adding a line there too).

### Writes fan out

`officer_save_accident` (`sql/officer.sql:181`) is the core write path: it inserts one `accidents` row, then walks party1/party2 plus their passengers and **derives** rows in `deaths` (injury = `เสียชีวิต`) and `injuries` (`หมดสติ`/`สาหัส`/`เล็กน้อย`). The citizen dashboard's fatality and injury counts come from those derived tables, so changing the person/injury JSON shape breaks statistics on both apps. `admin_update_accident` must keep the same derivation in sync.

### Black-spot analysis (`sql/blackspot_1..4_*.sql`, `bs_*` tables)

The risk-point analysis is the one feature that does **not** compute in Postgres. The engine lives in `officer.html` (`bsAnalyze` and the `bsRule1/2/3` functions) because it needs spatial clustering, convex hulls, and polygon buffering. The database only stores inputs (`bs_features`, `bs_incidents`, `bs_settings`) and outputs (`bs_sites`, `bs_zones`, `bs_runs`); an admin runs the analysis in the browser and presses publish, which calls `bs_publish` to replace the previous `source='auto'` rows. Hand-drawn zones (`source='manual'`) are never touched by a run.

`bs_sites` and `bs_zones` use `using (published)` for public read, so drafts stay invisible until published — that gate is deliberate, since these drive public "avoid this area" messaging.

Two documented approximations, both surfaced in the UI rather than hidden: rules 1 and 2 specify **road distance**, but there is no routing engine, so it's haversine × a tunable `detourFactor`. And the `accidents` table has no direction-of-travel column, so rule 2 groups by road name alone unless a direction was entered on a `bs_incidents` row.

Fatal accidents are derived into `deaths` by `officer_save_accident`, so `bsDedupeDeaths` drops death rows within 2 minutes and 60 m of an accident row before analysis — without it every fatality counts twice.

### Images

Uploaded from the browser straight into Supabase Storage bucket `risk-images`, then the public URL is stored as text in the row (`image1_url`/`image2_url`, or `images` jsonb). No server-side upload step.

### Time

Everything is Asia/Bangkok. JS uses the `bkkParts()` / `bkkDay()` helpers (`index.html:1149`) built on `toLocaleString('sv-SE', {timeZone:'Asia/Bangkok'})` — don't reach for raw `getFullYear()`/`getMonth()`, which use the browser's zone. Years are displayed as Buddhist Era on citizen pages while internal values stay CE.

## SQL files — ordering matters

`sql/` is an append-only migration log, not a desired-state schema. **Several functions are defined in more than one file, with later files overriding earlier ones.** Run order for a fresh database is roughly: `schema.sql` → `storage.sql` → `officer.sql` → `officers_data.sql` → the various `*_admin.sql` → `actions_cleanup.sql`.

> If you re-run any older file, you must re-run `admin.sql` (the `officer_login` variant that returns `isAdmin`) and `actions_cleanup.sql` (the `admin_add_risk_action` variant that records `risk_id` + `status`) afterwards, or the app loses admin menus and risk-action linking.

`sql/accidents_part1..8.sql` are bulk data imports from the legacy system, not schema.

Claude cannot run these — the user must drag them onto the Supabase SQL Editor. When adding a feature that needs schema changes, write a new `sql/<feature>.sql` and tell the user to run it; do not edit an already-applied file in place.

### Never write `{`, `}`, or `$` in a SQL file

Both ways of getting SQL into the editor corrupt it. Pasting lets Chrome auto-translate rewrite keywords (`create` → `สร้าง`). Drag-drop avoids that, but the editor is Monaco and treats a dropped file as a **snippet**: it escapes every `}` to `\}` and appends `$0` at the end.

When the escape lands outside a string the file fails loudly at Run and the user deletes it. When it lands *inside* a quoted string the file runs clean and the damage is stored in the database. That is how `'{}'::jsonb` became `'{\}'::jsonb` inside `officer_save_accident` — every officer save failed with `invalid input syntax for type json — Token "\" is invalid` from install until 17 Aug 2026.

- empty object → `jsonb_build_object()`, empty array → `jsonb_build_array()`
- `val #>> '{}'` → `val #>> array[]::text[]`
- square brackets are safe
- $ is escaped too, and this is the more dangerous one. `'^[0-9]+$'` installs as
  `'^[0-9]+\$'` — a regex that can never match. It runs clean and the function then
  silently verifies nothing, forever. This bit `line_verify_sends` on 25 Aug 2026.
  Avoid $ entirely: test "all digits" with `translate(v, '0123456789', '') = ''`
  rather than an anchored regex. The `$fn$` body delimiters are the one exception —
  they survive intact, verified the same day.
- verify before handing over: `grep -c '[{}]' sql/<file>.sql` must print `0`
- tell the user to delete any trailing `$0` before pressing Run
- put diagnostics in **one** statement — the editor only shows results for the last one

To find existing damage, run `sql/find_backslash_damage.sql`. It scans `pg_proc.prosrc` line by line using `chr(92)` (never a literal backslash). Legitimate hits exist — regex like `^\d{13}$` in `officer_login`/`officer_register`, IP patterns in `cam_save`, and PostGIS internals. The corrupt ones are jsonb literals.

## Frontend conventions

- **Tailwind is not loaded on `index.html` / `officer.html`.** `index.html:9` onward is a hand-extracted subset of Tailwind v3 utilities with the exact spec values. Using a Tailwind class that isn't in that block does nothing — either add the rule with the correct v3 value or write plain CSS. (`sync.html` still uses the Tailwind CDN.)
- Navigation is DIY: `showTab(name, el)` on `index.html`, `openPage(name, el)` on `officer.html`, wired through inline `onclick`. Pages are sibling `<div>`s toggled by class.
- SweetAlert2 is globally mixed in with `heightAuto:false, scrollbarPadding:false` on both apps — this fixes a mobile scroll-jump on every popup open/close. Don't remove it, and don't call `Swal.fire` from a fresh reference that bypasses the mixin.
- Leaflet map instances must be destroyed on dialog close; several past bugs were leaked map instances or picker markers nulled before the confirm handler read them. Capture pin coordinates in `preConfirm`, not in `willClose`.
- Chart.js instances live in `state.charts` on `officer.html`; caches (`state.dashboardData`, `state.accidentRows`, `cachedDeathRows` on `index.html`) must be invalidated after any save/edit/delete or stats go stale.
- Grid overrides on mobile use `minmax(0,1fr)` plus `min-width:0` — bare `1fr` has repeatedly blown out the viewport width.

## LINE alerts

Push-only, driven entirely by `pg_cron` — no Edge Function is involved in sending. Four jobs run against `line_send_*` functions; `line_broadcast(kind, text, ref)` fans each message out to rows in `line_targets`.

Two things make alerts silently do nothing, and both look like success in the cron log:

- **`line_broadcast` only sends to `target_type = 'group'`** (deliberate — auto-alerts are group-only). The seeded `BROADCAST` row is *not* a group, so with no group registered every run returns 0 and logs `succeeded`. A LINE group id starts with `C` and is obtainable **only** from a webhook event — the `line.me/R/ti/g/…` invite link cannot be converted into one.
- **`line_sent` is the dedupe ledger**, keyed `(kind, ref_id, target_id)`. `line_send_new_deaths` skips any death already having *any* `line_sent` row, so marking rows there is how you suppress a backlog without sending.

`line_send_hotspots` (`sql/line_hotspot_5_report.sql` is the current definition) reports repeat-crash cells for the calendar month: 100 m hex cells, triggered at `hotspotMinPerMonth` crashes **or** `hotspotSevereMinPerMonth` serious/fatal casualties. It sends **one** message per run listing up to 3 cells. Ranking is deaths-first, then a weighted score — death 12, serious-or-unconscious 6, crash 3, minor 3. Casualties are read out of `accidents.party1/party2` (plus their `passengers`), so legacy rows storing `"passengers":{}` must be type-checked with `jsonb_typeof` or the function dies. The dedupe `ref` embeds every count, which is what makes it re-send when a cell's numbers move and stay quiet when they don't.

Wording and thresholds live in `bs_settings` (`hotspotTitle`, `publicSiteUrl`, the two thresholds) precisely so they can be changed with one `update` instead of another trip through the SQL editor.

The webhook Edge Function is deployed as **`line2`**, not `line-webhook` — the original was abandoned after its config broke and a redeploy could not repair it. The source lives in `supabase/functions/line2/`, and the LINE console's Webhook URL ends in `/line2`. It does only two things: a `join` event replies with the room id (the only way to learn a group id), and text messages are matched against `line_keywords`. It stays silent on everything else, including `follow` — greeting every citizen who scans the QR with their own LINE user id was noise they had no use for. A bot that answers everything gets removed from a working group.

## Prize campaign (`sql/camp_*.sql`, `camp_` tables)

A referral campaign that gives a free helmet to anyone whose 5 invited friends have **both** added the OA and joined the LINE group. Installed 21 Aug 2026; `campEnabled` in `bs_settings` is the master switch and every entry point checks it, so the whole feature is inert while it is false.

Nothing is counted cumulatively. Qualification is decided by **asking LINE at check time**, twice per member:

- `GET /v2/bot/profile/{userId}` → 200 means still a friend
- `GET /v2/bot/group/{groupId}/member/{userId}` → 200 means still in the group

Both user ids come from the same Messaging API channel, so they match without LINE Login. Only `200` and `404` are interpreted; **any other status is left as "unknown" on purpose** — treating a 401 or a LINE outage as "not a member" would drop every participant at once and look like normal operation. The bulk endpoint `/members/ids` returns 403 for this account (verified-accounts only) and is not used.

Attribution — who invited whom — is impossible from LINE events, so each member gets a 6-character `ref_code` and shares `https://line.me/R/oaMessage/%40<oaId>/?<CODE>`, which opens the OA chat with the code pre-filled; the friend only taps send. `line_reply` matches any whitespace-separated token in the message against `camp_members.ref_code` — **no regex**, because a length quantifier needs `{n}` and braces cannot appear in a SQL file here.

`line_reply` now takes `(p_text, p_user_id default null, p_source_type default null)`. The old single-argument version had to be **dropped**, not left alongside: PostgREST resolves functions by the exact argument set, and two overloads make the one-argument call ambiguous, which silences the bot completely. The campaign branch only runs for `p_source_type = 'user'` — group chats never get campaign replies.

Deploying the Edge Function is the fragile step; see the deploy notes in memory. The dashboard Code editor keeps its own copy of the source, so pressing "Deploy updates" after editing the repo file ships the old build with a new version number.

> The campaign group is the **same group** that `line_send_new_deaths` posts to (`C81363…`). Inviting the public into it was a deliberate decision made on 21 Aug 2026 after the consequence was spelled out: fatality alerts carry time, road, subdistrict, gender, age and role, and go out within five minutes — possibly before the family is told. There is no separate officer group, and `line_broadcast` only sends to `target_type = 'group'`, so turning `want_death` off here would stop death alerts for everyone.

## Google Drive access (`videos.html` + the `drive` Edge Function)

`videos.html` used to carry a Google API key inline, referrer-locked to `akkapanb-spec.github.io`. When the site moved to Netlify after the GitHub suspension the key did not move with it, so **every request from the new domain returned 403 and the clip page silently showed an error for weeks**. The referrer lock is why the leak was never dangerous — and also why the page broke.

Fixed 24 Aug 2026 by moving the key behind an Edge Function named `drive`:

- `?list=1` returns the folder listing; `?id=<fileId>` streams the file and **forwards the `Range` header**, so the player can still seek. It pipes `upstream.body` straight through rather than buffering — these clips are 25 MB+.
- The key lives in Edge Function Secrets as `GOOGLE_API_KEY`. Rotating it no longer requires touching the site.
- The replacement key must have **Application restrictions = None** and **API restrictions = Google Drive API only**. A referrer restriction would break it again: a server-side call sends no `Referer`.
- If the function is unreachable, `loadPlaylist` falls back to the keyless `embeddedfolderview` iframe rather than leaving the page empty.

The old key is in git history at `af55f0a`; removing it from the working tree does not remove it from clones, so it was deleted in the Google Cloud Console rather than merely rotated.

## Known issue

**Supabase dashboard access hangs on one suspended GitHub account.** The Supabase account is GitHub-OAuth-only — password reset is refused with "your account is linked to GitHub". As of 24 Aug 2026 `github.com/akkapanb-spec` still 404s, so the only way in is an already-live browser session. If that session expires before the appeal succeeds, nobody can run SQL, deploy functions, or set secrets, while the database, bot, cron jobs and campaign all keep running untouched. Invite a second org member on a different email.
