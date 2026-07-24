-- FlightPath v2 schema extensions
-- Adds: geography fields, alliances, aircraft types, per-user stats views,
-- and a privacy-safe percentile ranking function.

-- ============================================================
-- Geography — extend airports so we can derive continents/countries/cities
-- ============================================================

alter table airports add column if not exists city text;
alter table airports add column if not exists continent text; -- 'AF','AN','AS','EU','NA','OC','SA'

-- ============================================================
-- Airline alliances (static reference data — seed once, rarely changes)
-- ============================================================

create type airline_alliance as enum ('star_alliance', 'skyteam', 'oneworld', 'other');

alter table airlines add column if not exists alliance airline_alliance not null default 'other';

-- ============================================================
-- Aircraft types (manufacturer grouping for stat #6)
-- ============================================================

create table if not exists aircraft_types (
  iata_code text primary key,        -- e.g. '789' for 787-9
  name text not null,                -- e.g. 'Boeing 787-9'
  manufacturer text not null         -- 'Airbus' | 'Boeing' | 'COMAC' | 'Other'
);

alter table flights add column if not exists aircraft_iata text references aircraft_types (iata_code);
-- Nullable: not every AviationStack response includes aircraft type, and
-- manual entries won't have it unless the user knows/enters it.

-- ============================================================
-- Profiles — add home_country for optional "national" percentile scoping
-- ============================================================

alter table profiles add column if not exists home_country text; -- ISO 3166-1 alpha-2, user-supplied

-- ============================================================
-- Per-user stats view (mileage, duration, counts) — computed, not stored.
-- Distance uses the haversine formula on airport lat/lng (same great-circle
-- basis as the map arcs, so the map and the stats always agree).
-- ============================================================

create or replace view user_flight_stats as
select
  f.user_id,
  count(*) filter (where f.status = 'completed') as total_flights,
  coalesce(sum(
    extract(epoch from (f.arrival_time - f.departure_time)) / 3600.0
  ) filter (where f.status = 'completed'), 0) as total_hours,
  coalesce(sum(
    -- Haversine great-circle distance in km between departure/arrival airports
    2 * 6371 * asin(sqrt(
      sin(radians(arr.lat - dep.lat) / 2) ^ 2 +
      cos(radians(dep.lat)) * cos(radians(arr.lat)) *
      sin(radians(arr.lng - dep.lng) / 2) ^ 2
    ))
  ) filter (where f.status = 'completed'), 0) as total_km,
  count(distinct dep.continent) + count(distinct arr.continent) -- de-duped below in app layer if needed
    as continent_touch_count,
  count(distinct dep.country) as countries_from_departures,
  count(distinct arr.country) as countries_from_arrivals,
  count(distinct dep.city) as cities_from_departures,
  count(distinct arr.city) as cities_from_arrivals
from flights f
join airports dep on dep.iata_code = f.departure_iata
join airports arr on arr.iata_code = f.arrival_iata
group by f.user_id;

-- Row-level security doesn't apply to views by default in the same way;
-- enforce it by querying through a function that filters to auth.uid(),
-- or wrap with a security_barrier + policy-respecting base tables (already
-- RLS'd, so a normal SELECT through PostgREST still only returns the
-- caller's own row here since `flights` itself is RLS-protected).

-- ============================================================
-- Percentile ranking — privacy-safe cross-user comparison
--
-- SECURITY DEFINER: runs with elevated privileges so it CAN read every
-- user's total_km, but only ever returns the calling user's percentile —
-- never another user's raw row. This is the only place in the schema
-- that looks across users, and it's intentionally narrow.
-- ============================================================

create or replace function my_mileage_percentile(scope_country text default null)
returns table (percentile numeric, sample_size int, scope text)
language plpgsql
security definer
set search_path = public
as $$
declare
  my_km numeric;
  cohort_size int;
  rank_count int;
begin
  select total_km into my_km from user_flight_stats where user_id = auth.uid();
  if my_km is null then
    return query select null::numeric, 0, 'no_data';
    return;
  end if;

  if scope_country is not null then
    select count(*) into cohort_size
    from user_flight_stats s
    join profiles p on p.id = s.user_id
    where p.home_country = scope_country;

    -- Fall back to global if the national cohort is too small to be
    -- meaningful (and to avoid effectively de-anonymising a tiny cohort).
    if cohort_size < 20 then
      scope_country := null;
    end if;
  end if;

  if scope_country is not null then
    select count(*) into cohort_size
    from user_flight_stats s
    join profiles p on p.id = s.user_id
    where p.home_country = scope_country;

    select count(*) into rank_count
    from user_flight_stats s
    join profiles p on p.id = s.user_id
    where p.home_country = scope_country and s.total_km <= my_km;

    return query select
      round(100.0 * rank_count / nullif(cohort_size, 0), 1),
      cohort_size,
      'national'::text;
  else
    select count(*) into cohort_size from user_flight_stats;
    select count(*) into rank_count from user_flight_stats where total_km <= my_km;

    return query select
      round(100.0 * rank_count / nullif(cohort_size, 0), 1),
      cohort_size,
      'global'::text;
  end if;
end;
$$;

-- Grant execute to authenticated users only (not anon)
revoke all on function my_mileage_percentile from public;
grant execute on function my_mileage_percentile to authenticated;

-- ============================================================
-- Most-visited airport / most-flown route (per-user, no cross-user data)
-- ============================================================

create or replace view user_top_airports as
select
  user_id,
  iata_code,
  count(*) as visit_count
from (
  select user_id, departure_iata as iata_code from flights where status = 'completed'
  union all
  select user_id, arrival_iata as iata_code from flights where status = 'completed'
) t
group by user_id, iata_code;

create or replace view user_top_routes as
select
  user_id,
  least(departure_iata, arrival_iata) || '-' || greatest(departure_iata, arrival_iata) as route_pair,
  count(*) as flight_count
from flights
where status = 'completed'
group by user_id, least(departure_iata, arrival_iata), greatest(departure_iata, arrival_iata);
