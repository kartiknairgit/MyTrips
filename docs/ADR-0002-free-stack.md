# ADR-0002: Fully Free Stack Override

**Status:** Accepted — supersedes the map choice in ADR-0001

## Context

The v1 stack (ADR-0001) used Mapbox GL. Mapbox's free tier is generous
(50,000 map loads/month) and would very likely never be exceeded by a
personal trip log — but it's still a metered product tied to an account,
requiring a public API token and, in principle, a card on file once you
scale past the free tier. The requirement was tightened to: **no component
in the stack should have any possible billing relationship at all.**

## Decision

Replace Mapbox GL with:

- **MapLibre GL JS** (web) / **maplibre_gl** (Flutter) — the open-source
  fork of Mapbox GL JS from before Mapbox relicensed it. Same API shape
  (this repo's `flightPath.ts` styling/arc logic is unchanged), no account,
  no token, no cap, ever.
- **OpenFreeMap** as the vector tile source — a free, keyless hosted tile
  service (`https://tiles.openfreemap.org/styles/liberty`). No signup, no
  rate limiting tied to an account.

Every other component was audited against the same bar:

| Component | Free tier is permanent, no card? | Notes |
|---|---|---|
| Supabase | Yes | Free project tier, no card on signup |
| Vercel | Yes | Hobby plan free indefinitely for personal projects |
| GitHub Actions | Yes | Unlimited for public repos; 2,000 min/month free even if private |
| AviationStack | Yes, but capped at 100 req/month | No card required; cache in `flight_lookups` keeps you well under this for personal use |
| MapLibre + OpenFreeMap | Yes | No account exists to bill |

## Consequences

- **Positive:** Genuinely $0 to run indefinitely at personal-project scale. Nothing to forget to monitor for overage.
- **Trade-off:** OpenFreeMap is a smaller, community-run service rather than Mapbox's SLA-backed infrastructure — acceptable for a personal app, worth revisiting if this ever needs guaranteed uptime.
- **Trade-off:** AviationStack's 100 req/month cap is a real constraint if you started logging many flights per month or debugging lookups heavily. If ever hit, the cache (`flight_lookups`) already minimises repeat calls; the next free-tier fallback would be a static OpenFlights route/airline/airport dataset for offline lookups, with AviationStack reserved only for live-status refinement.
- **Out of scope, not free:** official app store distribution (Google Play $25 one-off, Apple Developer $99/year). Mitigated by sideloading the CI-built release APK directly rather than publishing to Play/App Store.
