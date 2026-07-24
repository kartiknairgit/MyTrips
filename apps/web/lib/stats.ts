import { supabase } from "./supabaseClient";

export interface OverviewStats {
  totalFlights: number;
  totalKm: number;
  totalHours: number;
  percentile: number | null;
  percentileScope: "global" | "national" | "no_data";
  sampleSize: number;
}

/** Stat #1: Trip Statistics Overview */
export async function getOverviewStats(homeCountry?: string): Promise<OverviewStats> {
  const { data: stats } = await supabase
    .from("user_flight_stats")
    .select("total_flights, total_km, total_hours")
    .single();

  const { data: percentileRows } = await supabase.rpc("my_mileage_percentile", {
    scope_country: homeCountry ?? null,
  });
  const p = percentileRows?.[0];

  return {
    totalFlights: stats?.total_flights ?? 0,
    totalKm: Math.round(stats?.total_km ?? 0),
    totalHours: Math.round((stats?.total_hours ?? 0) * 10) / 10,
    percentile: p?.percentile ?? null,
    percentileScope: (p?.scope as OverviewStats["percentileScope"]) ?? "no_data",
    sampleSize: p?.sample_size ?? 0,
  };
}

/** Stat #2: Flight Calendar — monthly counts for a given year, for the bar chart */
export async function getMonthlyCounts(year: number): Promise<number[]> {
  const { data, error } = await supabase
    .from("flights")
    .select("departure_time")
    .eq("status", "completed")
    .gte("departure_time", `${year}-01-01`)
    .lt("departure_time", `${year + 1}-01-01`);

  const counts = new Array(12).fill(0);
  if (error || !data) return counts;

  for (const row of data) {
    const month = new Date(row.departure_time).getMonth();
    counts[month]++;
  }
  return counts;
}

/** Stat #4: Geographic stats */
export interface GeoStats {
  continents: number;
  countries: number;
  cities: number;
  topAirport: { iata: string; visits: number } | null;
  topRoute: { pair: string; count: number } | null;
}

export async function getGeoStats(): Promise<GeoStats> {
  const [{ data: airports }, { data: routes }] = await Promise.all([
    supabase
      .from("user_top_airports")
      .select("iata_code, visit_count")
      .order("visit_count", { ascending: false })
      .limit(1),
    supabase
      .from("user_top_routes")
      .select("route_pair, flight_count")
      .order("flight_count", { ascending: false })
      .limit(1),
  ]);

  // Continents/countries/cities: joined client-side from the airports table
  // touched by the user's own flights (RLS-safe — flights is still filtered
  // to auth.uid() under the hood).
  const { data: touched } = await supabase
    .from("flights")
    .select("departure:airports!flights_departure_iata_fkey(country, continent, city), arrival:airports!flights_arrival_iata_fkey(country, continent, city)")
    .eq("status", "completed");

  const continents = new Set<string>();
  const countries = new Set<string>();
  const cities = new Set<string>();
  for (const row of touched ?? ([] as any[])) {
    const r = row as any;
    [r.departure, r.arrival].forEach((a) => {
      if (a?.continent) continents.add(a.continent);
      if (a?.country) countries.add(a.country);
      if (a?.city) cities.add(a.city);
    });
  }

  return {
    continents: continents.size,
    countries: countries.size,
    cities: cities.size,
    topAirport: airports?.[0]
      ? { iata: airports[0].iata_code, visits: airports[0].visit_count }
      : null,
    topRoute: routes?.[0]
      ? { pair: routes[0].route_pair, count: routes[0].flight_count }
      : null,
  };
}

/** Stat #5: Airline stats, grouped by alliance */
export interface AirlineStats {
  totalAirlines: number;
  byAlliance: Record<string, number>;
  topAirline: { iata: string; count: number } | null;
}

export async function getAirlineStats(): Promise<AirlineStats> {
  const { data } = await supabase
    .from("flights")
    .select("airline_iata, airline:airlines(alliance)")
    .eq("status", "completed");

  const counts: Record<string, number> = {};
  const byAlliance: Record<string, number> = {};
  for (const row of data ?? ([] as any[])) {
    const r = row as any;
    if (!r.airline_iata) continue;
    counts[r.airline_iata] = (counts[r.airline_iata] ?? 0) + 1;
    const alliance = r.airline?.alliance ?? "other";
    byAlliance[alliance] = (byAlliance[alliance] ?? 0) + 1;
  }

  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];

  return {
    totalAirlines: Object.keys(counts).length,
    byAlliance,
    topAirline: top ? { iata: top[0], count: top[1] } : null,
  };
}

/** Stat #6: Aircraft stats, grouped by manufacturer */
export async function getAircraftStats(): Promise<Record<string, number>> {
  const { data } = await supabase
    .from("flights")
    .select("aircraft:aircraft_types(manufacturer)")
    .eq("status", "completed");

  const byManufacturer: Record<string, number> = {};
  for (const row of data ?? ([] as any[])) {
    const r = row as any;
    const m = r.aircraft?.manufacturer ?? "Unknown";
    byManufacturer[m] = (byManufacturer[m] ?? 0) + 1;
  }
  return byManufacturer;
}
