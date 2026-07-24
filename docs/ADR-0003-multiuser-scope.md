# ADR-0003: Multi-User Pivot, Scope Cuts, and Privacy Design

**Status:** Accepted

## Context

The v2 feature request (trip stats, calendar, geo/airline/aircraft stats,
percentile ranking, content export, compatibility quiz, data-unlock nudges)
turns this from a personal tool into a real multi-user product, which
changes the privacy model: some features (percentile, compatibility)
inherently need to compare data across users, while the existing schema was
built around strict per-user RLS isolation.

## Decisions

### 1. Real multi-user product
Confirmed direction. No schema changes were needed for this in itself —
`flights` was already `user_id`-scoped with RLS — but two new
cross-user-aware pieces were added deliberately narrowly (see below) rather
than loosening RLS generally.

### 2. No monetization — item #9 dropped entirely
"Unlock 7 earlier trips" and membership badges only exist to drive paywall
conversion. With monetization explicitly off the table, there's nothing
underneath that UI to build — it's cut, not stubbed.

### 3. Percentile ranking via a narrow `SECURITY DEFINER` function
`flights` stays fully RLS-isolated — no user can query another user's rows
directly, ever. `my_mileage_percentile()` is the **one** function that
runs with elevated privileges to read across all users' aggregated
`total_km`, and it returns *only the caller's own percentile and the
cohort size* — never another user's identity or raw numbers. National
scoping falls back to global if the national cohort is under 20 people, so
a small country's users can't be de-anonymised by inference (e.g. "I'm the
only Fijian user, so my percentile reveals my exact mileage to anyone who
guesses").

### 4. Compatibility quiz requires mutual consent
`compat_requests` implements request → accept/decline. `get_compat_report()`
raises an error unless both sides have accepted, and even then only returns
aggregated overlap counts (shared airports/routes/airlines) and a
composite score — never one user's raw flight list to the other. This is
slower to build than "just compare anyone's data" but avoids turning the
feature into a way to snoop on someone who never agreed to it.

### 5. Train route toggle: stubbed, not implemented
Unlike flights (AviationStack), there's no equivalent free, global,
schedule-aware train API. Building a real toggle now would mean either
faking data or scoping to one country's rail network — neither matches
"world map" scope. The UI toggle exists as a placeholder; real data
integration is future work once a specific rail data source is chosen.

### 6. Content export: client-side only
Recording the "3D flight footprint" video and generating posters happens
entirely in the browser (canvas + `MediaRecorder` + Web Share API) — see
`apps/web/lib/footprintExport.ts`. A server-side render pipeline would
produce higher, more consistent quality but requires paid compute
(headless browser or ffmpeg workers), which breaks the zero-cost stack
from ADR-0002. Accepted trade-off: quality is capped by the user's own
device.

### 7. Aircraft type stats: best-effort field, not guaranteed
Not every flight lookup (or manual entry) will include an aircraft type.
`flights.aircraft_iata` is nullable; aircraft-stat charts should treat
"Unknown" as its own bucket rather than skewing manufacturer percentages.

## Consequences

- Two new migrations (`0002_stats_and_social.sql`, `0003_compatibility.sql`)
  on top of the original schema — additive, no breaking changes to existing
  tables/columns.
- The percentile and compatibility features are the only parts of the
  system that read across users; both are narrow, single-purpose functions
  rather than a general relaxation of RLS, which keeps the privacy
  reasoning auditable in one place each.
- Seeding `aircraft_types` and `airlines.alliance`/airport
  city/continent/country needs a one-time static data load (same pattern as
  the existing airports/airlines seeding note in the README) — no new
  external API dependency, since alliance membership and manufacturer are
  static facts, not something to look up per flight.
