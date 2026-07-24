"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { supabase } from "@/lib/supabaseClient";
import {
  FlightRow,
  deriveStatus,
  greatCircleArc,
  paintForStatus,
} from "@/lib/flightPath";
import type { FlightForAnimation } from "@/lib/footprintExport";

// OpenFreeMap: free, no API key, no usage cap, no account required.
// Swap this URL for a self-hosted PMTiles style later if you ever want to.
const FREE_MAP_STYLE = "https://tiles.openfreemap.org/styles/liberty";

export default function MapView({
  onReady,
  onFlightsChange,
}: {
  onReady?: (map: maplibregl.Map | null) => void;
  onFlightsChange?: (flights: FlightForAnimation[]) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: FREE_MAP_STYLE,
      center: [30, 15],
      zoom: 1.5,
      preserveDrawingBuffer: true,
    });
    mapRef.current = map;
    onReady?.(map);

    map.on("load", async () => {
      await loadAndRenderFlights(map, onFlightsChange);
    });

    // Realtime: when a flight's status flips (e.g. scheduled -> in_transit),
    // or a new flight is added, re-render.
    const channel = supabase
      .channel("flights-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "flights" },
        () => loadAndRenderFlights(map, onFlightsChange),
      )
      .subscribe();

    // Re-derive in_transit progress every 30s even with no DB change,
    // since "now" moving forward is what advances the plane icon.
    const interval = setInterval(() => loadAndRenderFlights(map, onFlightsChange), 30_000);

    return () => {
      supabase.removeChannel(channel);
      clearInterval(interval);
      onReady?.(null);
      map.remove();
      mapRef.current = null;
    };
  }, [onFlightsChange, onReady]);

  return <div ref={containerRef} style={{ width: "100%", height: "100%" }} aria-label="Map of your flight routes" />;
}

async function loadAndRenderFlights(
  map: maplibregl.Map,
  onFlightsChange?: (flights: FlightForAnimation[]) => void,
) {
  // Joins airports (dep/arr lat/lng) and airlines (brand_color_hex) at query time.
  const { data, error } = await supabase
    .from("flights")
    .select(
      `
      id, flight_number, airline_iata, departure_time, arrival_time, status,
      departure:airports!flights_departure_iata_fkey (lat, lng),
      arrival:airports!flights_arrival_iata_fkey (lat, lng),
      airline:airlines (brand_color_hex)
    `,
    );

  if (error || !data) {
    console.error("Failed to load flights", error);
    return;
  }

  const rows: FlightRow[] = data.map((f: any) => ({
    id: f.id,
    flight_number: f.flight_number,
    airline_iata: f.airline_iata,
    departure_time: f.departure_time,
    arrival_time: f.arrival_time,
    status: deriveStatus(f.departure_time, f.arrival_time),
    departure_lat: f.departure.lat,
    departure_lng: f.departure.lng,
    arrival_lat: f.arrival.lat,
    arrival_lng: f.arrival.lng,
    airline_color: f.airline?.brand_color_hex ?? "#6b7280",
  }));
  onFlightsChange?.(rows.map((flight) => ({
    id: flight.id,
    departure: [flight.departure_lng, flight.departure_lat],
    arrival: [flight.arrival_lng, flight.arrival_lat],
    departureTime: flight.departure_time,
  })));

  for (const flight of rows) {
    const sourceId = `flight-${flight.id}`;
    const arc = greatCircleArc(flight);
    const paint = paintForStatus(flight.status, flight.airline_color);

    if (map.getSource(sourceId)) {
      (map.getSource(sourceId) as maplibregl.GeoJSONSource).setData(arc as any);
      map.setPaintProperty(sourceId, "line-color", paint["line-color"] as string);
    } else {
      map.addSource(sourceId, { type: "geojson", data: arc as any });
      map.addLayer({
        id: sourceId,
        type: "line",
        source: sourceId,
        layout: { "line-cap": "round", "line-join": "round" },
        paint: paint as any,
      });
    }
  }
}
