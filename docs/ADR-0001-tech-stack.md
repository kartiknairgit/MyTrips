# ADR-0001: Core Tech Stack

**Status:** Accepted

## Context

Need a system that: works on web + mobile as separate native apps, supports
multi-user accounts, animates a flight's path in "real time" relative to
scheduled departure/arrival (not live GPS), auto-looks-up flight details by
code with manual override, and can be built/deployed via GitHub Actions with
minimal ongoing ops.

## Decision

- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions)
- **Web:** Next.js, deployed to Vercel
- **Mobile:** Flutter (separate native codebase from web)
- **Map:** ~~Mapbox GL~~ — superseded by ADR-0002 (MapLibre GL + OpenFreeMap)
- **Flight data:** AviationStack, proxied through a Supabase Edge Function

## Alternatives considered

| Area | Alternative | Why not (for v1) |
|---|---|---|
| Backend | Firebase | Firestore's document model is a worse fit for relational flight/airport/airline data than Postgres |
| Backend | Custom Node/FastAPI + Postgres | More control, but you'd be hosting/patching auth and API infra yourself for no v1 benefit |
| Mobile | React Native/Expo (shared code with web) | You explicitly chose separate Next.js + Flutter apps over a shared codebase |
| Map | Leaflet | Simpler and free, but weaker built-in support for animated great-circle arcs and custom dash-styling |
| Map | Google Maps Platform | Usage-based pricing adds up faster than Mapbox's free tier for a low-traffic personal app |
| Flight data | OpenSky Network | Free, but focused on live ADS-B positions — weak on scheduled route/airline metadata, which is what auto-lookup actually needs |
| Flight data | FlightAware AeroAPI | More accurate/complete, but paid and likely overkill for a personal trip log |

## Consequences

- Two codebases to maintain (web, mobile) instead of one shared one — accepted trade-off for native mobile quality.
- Mapbox usage needs a public token per client; token is domain/bundle-restricted, not secret-critical, but still kept in env vars not committed to git.
- AviationStack's free tier has a monthly call cap — mitigated by caching lookups in `flight_lookups` so repeated lookups of the same flight+date don't burn quota.
