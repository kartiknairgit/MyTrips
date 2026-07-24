"use client";

import { useCallback, useEffect, useState } from "react";
import type maplibregl from "maplibre-gl";
import FlightEntryForm from "@/components/FlightEntryForm";
import MapView from "@/components/MapView";
import {
  FlightForAnimation,
  recordFlightFootprint,
  renderPoster,
  shareOrDownload,
} from "@/lib/footprintExport";
import { getOverviewStats, OverviewStats } from "@/lib/stats";

interface Capabilities {
  recording: boolean;
  sharing: boolean;
}

export default function HeroWorkspace() {
  const [map, setMap] = useState<maplibregl.Map | null>(null);
  const [flights, setFlights] = useState<FlightForAnimation[]>([]);
  const handleReady = useCallback((nextMap: maplibregl.Map | null) => setMap(nextMap), []);
  const handleFlights = useCallback((nextFlights: FlightForAnimation[]) => setFlights(nextFlights), []);

  return (
    <>
      <div className="hero">
        <div className="panel map-panel"><MapView onReady={handleReady} onFlightsChange={handleFlights} /></div>
        <FlightEntryForm />
      </div>
      <FootprintExport map={map} flights={flights} />
    </>
  );
}

function FootprintExport({ map, flights }: { map: maplibregl.Map | null; flights: FlightForAnimation[] }) {
  const [capabilities, setCapabilities] = useState<Capabilities>({ recording: false, sharing: false });
  const [busy, setBusy] = useState<"video" | "poster" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    const canvas = document.createElement("canvas");
    setCapabilities({
      recording: typeof MediaRecorder !== "undefined" && "captureStream" in canvas,
      sharing: typeof navigator.share === "function" && typeof navigator.canShare === "function",
    });
  }, []);

  async function makeVideo() {
    if (!map || flights.length === 0 || !capabilities.recording) return;
    setBusy("video");
    setError(null);
    setSuccess(null);
    try {
      const blob = await recordFlightFootprint(map, flights);
      await shareOrDownload(blob, "my-flightpath.webm");
      setSuccess(capabilities.sharing ? "Your footprint video is ready to share." : "Your footprint video was downloaded.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not record your footprint.");
    } finally {
      setBusy(null);
    }
  }

  async function makePoster() {
    if (!map || flights.length === 0) return;
    setBusy("poster");
    setError(null);
    setSuccess(null);
    try {
      const stats: OverviewStats = await getOverviewStats();
      const blob = await renderPoster(map, stats);
      if (!blob) throw new Error("This browser could not render the poster.");
      await shareOrDownload(blob, "my-flightpath.png");
      setSuccess(capabilities.sharing ? "Your poster is ready to share." : "Your poster was downloaded.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not create your poster.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="panel export-panel" aria-labelledby="footprint-title">
      <div>
        <div className="eyebrow">Made on your device</div>
        <h2 className="section-title" id="footprint-title">Record your footprint</h2>
        <p className="section-copy">Turn your mapped routes into a camera fly-through or a shareable poster. Your flight data never leaves the browser for rendering.</p>
      </div>
      {!map ? (
        <div className="notice info" aria-busy="true">Preparing the map for export…</div>
      ) : flights.length === 0 ? (
        <div className="empty-state compact-empty"><strong>Nothing to export yet</strong><span>Add your first flight to create a poster and route recording.</span></div>
      ) : (
        <>
          <div className="button-row">
            {capabilities.recording ? (
              <button className="button primary" disabled={busy !== null} onClick={() => void makeVideo()}>
                {busy === "video" ? "Recording…" : capabilities.sharing ? "Record & share video" : "Record & download video"}
              </button>
            ) : (
              <span className="notice info">Video recording isn’t available in this browser. Poster download is still supported.</span>
            )}
            <button className="button" disabled={busy !== null} onClick={() => void makePoster()}>
              {busy === "poster" ? "Rendering…" : capabilities.sharing ? "Share poster" : "Download poster"}
            </button>
          </div>
          {success && <div className="notice success" role="status">{success}</div>}
          {error && <div className="notice error" role="alert">{error}</div>}
        </>
      )}
    </section>
  );
}
