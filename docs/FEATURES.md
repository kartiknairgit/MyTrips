# FlightPath — Feature Status (v2 spec)

Tracks the feature list from the "flight wrapped" spec against what's
actually built in this repo. See `ADR-0003-multiuser-scope.md` for the
reasoning behind each cut/deferral.

| # | Feature | Status | Notes |
|---|---|---|---|
| 0 | Flight entry (manual + lookup confirmation) | ✅ Web UI built | Editable lookup/manual confirmation flow with wall-clock-derived status |
| 1 | Trip stats overview (mileage, duration, count, percentile) | ✅ Web UI built | Stat cards use `getOverviewStats()` with scope-aware badge copy and a home-country profile setting |
| 2 | Flight calendar (month/day toggle, bar chart, year filter) | ✅ Web UI built | Recharts month/day views; year options span the user’s earliest flight through the current year |
| 3 | Route map (2D/3D toggle, arrows, zoom, train toggle) | 🟡 2D done, 3D + train stubbed | 2D arcs from v1 `MapView.tsx`; 3D fly-through exists via `footprintExport.ts`'s camera animation but no dedicated 3D *viewing* mode yet; train toggle is UI-only placeholder, no data source |
| 4 | Geo stats (continents/countries/cities, top airport/route) | ✅ Web UI built | Geographic reach counts and top-airport/route cards use `getGeoStats()` |
| 5 | Airline stats (alliance grouping, top airline) | ✅ Web UI built | Alliance doughnut chart and top-airline highlight use `getAirlineStats()` |
| 6 | Aircraft stats (manufacturer grouping) | ✅ Web UI built | Manufacturer bar chart uses `getAircraftStats()` and preserves nullable aircraft as an Unknown bucket |
| 7 | Content generation & sharing | ✅ Web UI built | Capability-gated client-only recording, poster rendering, Web Share, and direct-download fallback |
| 8 | Compatibility quiz | ✅ Consent-gated backend built | `compat_requests` + `get_compat_report()`; UI flow (send request, accept, view report) not built |
| 9 | Data-unlock / membership nudges | ❌ Dropped | Monetization explicitly out of scope — nothing to build under the UI |

## What's genuinely not started yet (UI layer)

Everything above marked "schema + client lib" has the data plumbing but no
React components yet — that's the next chunk of work: stat cards, the
calendar bar chart, alliance/manufacturer breakdown charts, the
compatibility request/accept flow, and a 3D route-viewing mode distinct
from the export camera fly-through.

## Seeding required before any of this works

- `airports`: add `city`, `continent` for every airport you'll actually fly through (OurAirports dataset covers this)
- `airlines`: set `alliance` for each airline you fly (Star Alliance / SkyTeam / Oneworld / Other — static, look up once)
- `aircraft_types`: seed common types with `manufacturer` (Airbus/Boeing/COMAC/Other)

None of this needs a paid API — it's static reference data, seeded once.
