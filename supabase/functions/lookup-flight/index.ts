// Supabase Edge Function: lookup-flight
//
// Proxies AviationStack so the API key never reaches the client, caches
// results in `flight_lookups`, and normalises the response into the shape
// the web/mobile clients expect for the "confirm before save" screen.
//
// Deploy: supabase functions deploy lookup-flight
// Secrets: supabase secrets set AVIATIONSTACK_API_KEY=xxxx

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const AVIATIONSTACK_BASE = "https://api.aviationstack.com/v1/flights";

interface LookupRequest {
  flight_iata: string; // e.g. "SQ308"
  flight_date: string; // "YYYY-MM-DD"
}

interface NormalisedFlight {
  flight_number: string;
  airline_iata: string | null;
  airline_name: string | null;
  departure_iata: string | null;
  arrival_iata: string | null;
  departure_time: string | null;
  arrival_time: string | null;
  live_status: string | null;
}

function normalise(raw: any): NormalisedFlight | null {
  const f = raw?.data?.[0];
  if (!f) return null;
  return {
    flight_number: f.flight?.iata ?? f.flight?.number ?? "",
    airline_iata: f.airline?.iata ?? null,
    airline_name: f.airline?.name ?? null,
    departure_iata: f.departure?.iata ?? null,
    arrival_iata: f.arrival?.iata ?? null,
    departure_time: f.departure?.scheduled ?? null,
    arrival_time: f.arrival?.scheduled ?? null,
    live_status: f.flight_status ?? null,
  };
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { flight_iata, flight_date } = (await req.json()) as LookupRequest;
  if (!flight_iata || !flight_date) {
    return new Response(
      JSON.stringify({ error: "flight_iata and flight_date are required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1. Check cache first (avoid burning AviationStack quota on repeat lookups)
  const { data: cached } = await supabase
    .from("flight_lookups")
    .select("raw_response, fetched_at")
    .eq("flight_number", flight_iata)
    .eq("flight_date", flight_date)
    .maybeSingle();

  const CACHE_TTL_MS = 1000 * 60 * 30; // 30 min — live status can change
  const isFresh =
    cached && Date.now() - new Date(cached.fetched_at).getTime() < CACHE_TTL_MS;

  let raw: any;
  if (isFresh) {
    raw = cached!.raw_response;
  } else {
    const apiKey = Deno.env.get("AVIATIONSTACK_API_KEY");
    const url = `${AVIATIONSTACK_BASE}?access_key=${apiKey}&flight_iata=${flight_iata}&flight_date=${flight_date}`;
    const res = await fetch(url);
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: "Upstream lookup failed" }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
    raw = await res.json();

    // Upsert cache (fire-and-forget is fine here, but we await for simplicity)
    await supabase.from("flight_lookups").upsert({
      flight_number: flight_iata,
      flight_date,
      raw_response: raw,
      fetched_at: new Date().toISOString(),
    });
  }

  const normalised = normalise(raw);
  if (!normalised) {
    return new Response(
      JSON.stringify({ error: "No flight found for that code/date" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify(normalised), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
