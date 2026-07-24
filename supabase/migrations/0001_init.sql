-- FlightPath initial schema
-- Run via: supabase db push  (or applied automatically in CI, see docs/ARCHITECTURE.md)

-- ============================================================
-- Reference tables (shared across all users)
-- ============================================================

create table if not exists airlines (
  iata_code text primary key,
  name text not null,
  brand_color_hex text not null default '#6b7280' -- fallback grey until assigned
);

create table if not exists airports (
  iata_code text primary key,
  name text not null,
  country text,
  lat double precision not null,
  lng double precision not null
);

-- ============================================================
-- Profiles (1:1 with auth.users)
-- ============================================================

create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles: read own" on profiles
  for select using (auth.uid() = id);

create policy "profiles: update own" on profiles
  for update using (auth.uid() = id);

create policy "profiles: insert own" on profiles
  for insert with check (auth.uid() = id);

-- ============================================================
-- Flights (the core user-owned table — one row = one arc)
-- ============================================================

create type flight_status as enum ('scheduled', 'in_transit', 'completed', 'cancelled');
create type flight_source as enum ('auto', 'manual');

create table if not exists flights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  flight_number text not null,
  airline_iata text references airlines (iata_code),
  departure_iata text not null references airports (iata_code),
  arrival_iata text not null references airports (iata_code),
  departure_time timestamptz not null,
  arrival_time timestamptz not null,
  status flight_status not null default 'scheduled',
  source flight_source not null default 'manual',
  created_at timestamptz not null default now()
);

alter table flights enable row level security;

create policy "flights: read own" on flights
  for select using (auth.uid() = user_id);

create policy "flights: insert own" on flights
  for insert with check (auth.uid() = user_id);

create policy "flights: update own" on flights
  for update using (auth.uid() = user_id);

create policy "flights: delete own" on flights
  for delete using (auth.uid() = user_id);

create index if not exists flights_user_id_idx on flights (user_id);
create index if not exists flights_departure_time_idx on flights (departure_time);

-- ============================================================
-- Flight lookup cache (backs the lookup-flight Edge Function)
-- ============================================================

create table if not exists flight_lookups (
  flight_number text not null,
  flight_date date not null,
  raw_response jsonb not null,
  fetched_at timestamptz not null default now(),
  primary key (flight_number, flight_date)
);

-- No RLS needed: this table is only ever touched by the Edge Function
-- using the service role key, never directly by clients.

-- ============================================================
-- Status transition helper
-- Recomputes status based on wall-clock time; call from a scheduled
-- Edge Function / cron (see docs/ARCHITECTURE.md section 5) or on read.
-- ============================================================

create or replace function compute_flight_status(dep timestamptz, arr timestamptz)
returns flight_status
language sql
immutable
as $$
  select case
    when now() < dep then 'scheduled'::flight_status
    when now() >= dep and now() < arr then 'in_transit'::flight_status
    else 'completed'::flight_status
  end
$$;
