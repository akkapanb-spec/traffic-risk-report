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

### Black-spot analysis (`sql/blackspot.sql`, `bs_*` tables)

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

Claude cannot run these — the user must paste them into the Supabase SQL Editor. When adding a feature that needs schema changes, write a new `sql/<feature>.sql` and tell the user to run it; do not edit an already-applied file in place.

## Frontend conventions

- **Tailwind is not loaded on `index.html` / `officer.html`.** `index.html:9` onward is a hand-extracted subset of Tailwind v3 utilities with the exact spec values. Using a Tailwind class that isn't in that block does nothing — either add the rule with the correct v3 value or write plain CSS. (`sync.html` still uses the Tailwind CDN.)
- Navigation is DIY: `showTab(name, el)` on `index.html`, `openPage(name, el)` on `officer.html`, wired through inline `onclick`. Pages are sibling `<div>`s toggled by class.
- SweetAlert2 is globally mixed in with `heightAuto:false, scrollbarPadding:false` on both apps — this fixes a mobile scroll-jump on every popup open/close. Don't remove it, and don't call `Swal.fire` from a fresh reference that bypasses the mixin.
- Leaflet map instances must be destroyed on dialog close; several past bugs were leaked map instances or picker markers nulled before the confirm handler read them. Capture pin coordinates in `preConfirm`, not in `willClose`.
- Chart.js instances live in `state.charts` on `officer.html`; caches (`state.dashboardData`, `state.accidentRows`, `cachedDeathRows` on `index.html`) must be invalidated after any save/edit/delete or stats go stale.
- Grid overrides on mobile use `minmax(0,1fr)` plus `min-width:0` — bare `1fr` has repeatedly blown out the viewport width.

## Known issue

`videos.html:156` has a Google API key hardcoded in a public repo. It should be restricted by HTTP referrer to `akkapanb-spec.github.io` in the Google Cloud Console.
