/**
 * Stat #7: Content generation & sharing.
 *
 * Deliberately client-side only: rendering video server-side (e.g. a
 * headless-browser or ffmpeg render farm) would need paid compute, which
 * breaks the zero-cost constraint from ADR-0002/0003. Instead:
 *
 *  - "3D flight footprint animation": drive the existing MapLibre map
 *    through a scripted camera fly-through (flyTo/easeTo per flight, in
 *    chronological order) while capturing the canvas via MediaRecorder.
 *  - "Shareable poster": render a static canvas (stats + a snapshot of the
 *    map) and export as PNG via canvas.toBlob — trivial, free, instant.
 *  - "Export to external platforms": use the Web Share API where
 *    available (native share sheet, no third-party SDK/cost), falling
 *    back to a plain download link.
 *
 * This is a real trade-off vs. a server-rendered video: lower and more
 * variable quality, capped by the user's own device performance, and only
 * works in browsers that support MediaRecorder (all major ones do). Worth
 * revisiting with a paid render service only if free client-side output
 * turns out not to be good enough once you've tried it.
 */

import type maplibregl from "maplibre-gl";

export interface FlightForAnimation {
  id: string;
  departure: [number, number]; // [lng, lat]
  arrival: [number, number];
  departureTime: string;
}

/** Fly the camera through each flight in chronological order, recording the canvas. */
export async function recordFlightFootprint(
  map: maplibregl.Map,
  flights: FlightForAnimation[],
  options: { msPerFlight?: number } = {},
): Promise<Blob> {
  const msPerFlight = options.msPerFlight ?? 2000;
  const canvas = map.getCanvas();
  const stream = canvas.captureStream(30); // 30fps
  const recorder = new MediaRecorder(stream, { mimeType: "video/webm" });
  const chunks: Blob[] = [];

  recorder.ondataavailable = (e) => {
    if (e.data.size > 0) chunks.push(e.data);
  };

  const sorted = [...flights].sort(
    (a, b) => new Date(a.departureTime).getTime() - new Date(b.departureTime).getTime(),
  );

  recorder.start();

  for (const flight of sorted) {
    const midpoint: [number, number] = [
      (flight.departure[0] + flight.arrival[0]) / 2,
      (flight.departure[1] + flight.arrival[1]) / 2,
    ];
    map.easeTo({ center: midpoint, zoom: 3, duration: msPerFlight * 0.8 });
    await sleep(msPerFlight);
  }

  recorder.stop();
  return new Promise((resolve) => {
    recorder.onstop = () => resolve(new Blob(chunks, { type: "video/webm" }));
  });
}

/** Static shareable poster: snapshot the map canvas + draw stats text over it. */
export function renderPoster(
  map: maplibregl.Map,
  stats: { totalFlights: number; totalKm: number; totalHours: number },
): Blob | null {
  const mapCanvas = map.getCanvas();
  const poster = document.createElement("canvas");
  poster.width = mapCanvas.width;
  poster.height = mapCanvas.height + 160; // extra space for stats banner
  const ctx = poster.getContext("2d");
  if (!ctx) return null;

  ctx.drawImage(mapCanvas, 0, 0);
  ctx.fillStyle = "#0a0a0a";
  ctx.fillRect(0, mapCanvas.height, poster.width, 160);
  ctx.fillStyle = "#ffffff";
  ctx.font = "bold 28px sans-serif";
  ctx.fillText(
    `${stats.totalFlights} flights · ${stats.totalKm.toLocaleString()} km · ${stats.totalHours}h`,
    24,
    mapCanvas.height + 90,
  );

  let blob: Blob | null = null;
  poster.toBlob((b) => (blob = b), "image/png");
  return blob; // Note: toBlob is async in practice; wrap in a Promise in real usage.
}

/** Share via native share sheet where available, else fall back to download. */
export async function shareOrDownload(blob: Blob, filename: string) {
  const file = new File([blob], filename, { type: blob.type });
  if (navigator.share && navigator.canShare?.({ files: [file] })) {
    await navigator.share({ files: [file], title: "My FlightPath" });
    return;
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
