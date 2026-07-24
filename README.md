# MyTrips
with adhikari (@lazY)

Log your flights (by flight code or manually), watch them appear on a world
map as colour-coded, animated arcs — dashed while in the air, solid once
landed — building up a permanent map of everywhere you've flown.

See `docs/ARCHITECTURE.md` for the full system design and `docs/DATA_MODEL.md`
for the schema.

## Repo layout

```
.
├── apps/
│   ├── web/       # Next.js app (Vercel)
│   └── mobile/    # Flutter app
├── supabase/
│   ├── migrations/  # Postgres schema
│   └── functions/   # Edge Functions (AviationStack proxy)
├── docs/           # Architecture, data model, ADRs
└── .github/workflows/  # CI/CD
```

## One-time setup

### 1. Supabase project

```bash
npm install -g supabase
supabase login
supabase init          # if not already linked
supabase link --project-ref <your-project-ref>
supabase db push       # applies supabase/migrations/0001_init.sql
supabase secrets set AVIATIONSTACK_API_KEY=xxxxx
supabase functions deploy lookup-flight
```

Seed `airlines` and `airports` reference tables — a static IATA dataset works
fine (e.g. OurAirports' open airport CSV), or let rows populate lazily the
first time each airline/airport is looked up.

**v2 additions** also need: `airports.city`/`continent`, `airlines.alliance`,
and `aircraft_types` seeded (see `docs/FEATURES.md` for exactly what and
why — all static reference data, no paid API needed). Run
`supabase/migrations/0002_stats_and_social.sql` and `0003_compatibility.sql`
after `0001_init.sql`.

### 2. Web app

```bash
cd apps/web
cp .env.example .env.local   # fill in Supabase values (no map token needed)
npm install
npm run dev
```

To enable auto-deploy: `vercel link` once locally, then add
`VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` as GitHub repo secrets.
Every push to `main` under `apps/web/**` then builds + deploys automatically
(see `.github/workflows/web-ci-cd.yml`).

### 3. Mobile app

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

CI (`.github/workflows/mobile-ci.yml`) runs `flutter analyze` + `flutter test`
on every push/PR, and builds a release APK artifact on `main`. iOS build is
stubbed out — needs a macOS runner + signing setup once you have an Apple
Developer account.

Then add the GitHub secrets listed above for the deploy steps to run.

## Collaboration

Two developers work on this repo in parallel — see `docs/COLLABORATION.md`
for the branch split and the shared contract both apps build against.
