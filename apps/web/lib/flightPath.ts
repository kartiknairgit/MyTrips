import * as turf from "@turf/turf";

export type FlightStatus = "scheduled" | "in_transit" | "completed" | "cancelled";

export interface FlightRow {
  id: string;
  flight_number: string;
  airline_iata: string | null;
  departure_time: string;
  arrival_time: string;
  status: FlightStatus;
  // joined in from `airports` / `airlines` at query time
  departure_lat: number;
  departure_lng: number;
  arrival_lat: number;
  arrival_lng: number;
  airline_color: string;
}

/** Recompute status from wall-clock time — mirrors compute_flight_status() in SQL. */
export function deriveStatus(departureTime: string, arrivalTime: string): FlightStatus {
  const now = Date.now();
  const dep = new Date(departureTime).getTime();
  const arr = new Date(arrivalTime).getTime();
  if (now < dep) return "scheduled";
  if (now < arr) return "in_transit";
  return "completed";
}

/** Great-circle arc between two airports, as a GeoJSON LineString. */
export function greatCircleArc(flight: FlightRow) {
  const from = turf.point([flight.departure_lng, flight.departure_lat]);
  const to = turf.point([flight.arrival_lng, flight.arrival_lat]);
  // npoints controls smoothness; 100 is plenty for a world-map zoom level
  return turf.greatCircle(from, to, { npoints: 100 });
}

/** How far along the arc (0-1) the plane icon should sit right now, for in_transit flights. */
export function progressFraction(flight: FlightRow): number {
  const now = Date.now();
  const dep = new Date(flight.departure_time).getTime();
  const arr = new Date(flight.arrival_time).getTime();
  if (now <= dep) return 0;
  if (now >= arr) return 1;
  return (now - dep) / (arr - dep);
}

/** MapLibre line-paint styling per status. Feed straight into a `line` layer's `paint`. */
export function paintForStatus(status: FlightStatus, color: string) {
  switch (status) {
    case "completed":
      return { "line-color": color, "line-width": 2.5, "line-opacity": 1, "line-dasharray": [1, 0] };
    case "in_transit":
      return { "line-color": color, "line-width": 2.5, "line-opacity": 1, "line-dasharray": [2, 2] };
    case "scheduled":
      return { "line-color": color, "line-width": 1, "line-opacity": 0.35, "line-dasharray": [1, 3] };
    case "cancelled":
      return { "line-color": "#9ca3af", "line-width": 1, "line-opacity": 0.2, "line-dasharray": [1, 3] };
  }
}
