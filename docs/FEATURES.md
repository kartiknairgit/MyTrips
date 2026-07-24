# FlightPath — Feature Status (v2 spec)

Tracks the feature list from the "flight wrapped" spec against what's
actually built in this repo. See `ADR-0003-multiuser-scope.md` for the
reasoning behind each cut/deferral.

| # | Feature | Status | Notes |
|---|---|---|---|
| 0 | Flight entry (manual + lookup confirmation) | ✅ Web + mobile UI built | Both clients provide editable lookup/manual confirmation with wall-clock-derived status |
| 1 | Trip stats overview (mileage, duration, count, percentile) | ✅ Web + mobile UI built | Scope-aware totals and percentile badges use the frozen view/RPC |
| 2 | Flight calendar (month/day toggle, bar chart, year filter) | ✅ Web + mobile UI built | Month/day views and data-derived year options extend through the current year |
| 3 | Route map (2D/3D toggle, arrows, zoom, train toggle) | 🟡 Web + mobile 2D done; 3D + train not built | Both clients use MapLibre/OpenFreeMap; dedicated 3D viewing and the train toggle remain out of scope |
| 4 | Geo stats (continents/countries/cities, top airport/route) | ✅ Web + mobile UI built | Auth-scoped geographic reach counts and top-airport/route cards |
| 5 | Airline stats (alliance grouping, top airline) | ✅ Web + mobile UI built | Auth-scoped alliance breakdown and top-airline highlight |
| 6 | Aircraft stats (manufacturer grouping) | ✅ Web + mobile UI built | Both clients use `aircraft_types.manufacturer` and preserve Unknown aircraft |
| 7 | Content generation & sharing | ✅ Web UI built; mobile not applicable | The specified canvas, MediaRecorder, and Web Share implementation is web-client-only |
| 8 | Compatibility quiz | ✅ Web + mobile UI built | Send, accept/decline, consent-waiting, and aggregate-only reports use the frozen APIs |
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
