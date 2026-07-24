# Collaboration

This repo is built by two developers working in parallel on separate apps
that share one backend contract.

## The split

- **Dev A** works only in `apps/web/`, on branch `feature/web-ui`.
- **Dev B** works only in `apps/mobile/`, on branch `feature/mobile-ui`.

Each dev stays inside their own app directory. Don't reach into the other
app's code, and don't merge the other person's branch into yours unless
you're intentionally syncing.

## The frozen contract

`docs/` and `supabase/migrations/` are the shared contract both apps build
against. Neither dev touches either without the other's sign-off first.

That means:
- No schema changes in `supabase/migrations/` without agreeing on the change
  with the other dev — both apps read from the same database.
- No edits to `docs/` (architecture, data model, feature status) without
  agreement — it's the source of truth both apps are implemented against,
  not a place to record one app's local decisions.

If a change to the shared contract is needed, coordinate first, land it as
its own change, then both apps adjust to it.

## Required reading before starting

Before writing any code, read:

- `docs/ARCHITECTURE.md` — overall system design
- `docs/DATA_MODEL.md` — database schema
- `docs/FEATURES.md` — tracks exactly what's built vs. not-started; check
  this first so you don't duplicate work or build against a feature that
  isn't there yet

## CI

CI is path-filtered per app, so pushes to one branch never trigger the
other's pipeline:

- `.github/workflows/web-ci-cd.yml` only triggers on changes under
  `apps/web/**`.
- `.github/workflows/mobile-ci.yml` only triggers on changes under
  `apps/mobile/**`.

You can push to your feature branch and open PRs without waiting on or
worrying about the other app's build.
