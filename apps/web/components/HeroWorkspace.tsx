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
  const [mapState, setMapState] = useState<"loading" | "empty" | "ready" | "error">("loading");
  const [mapMessage, setMapMessage] = useState<string | undefined>();
  const handleReady = useCallback((nextMap: maplibregl.Map | null) => setMap(nextMap), []);
  const handleFlights = useCallback((nextFlights: FlightForAnimation[]) => setFlights(nextFlights), []);
  const handleMapState = useCallback((
    state: "loading" | "empty" | "ready" | "error",
    message?: string,
  ) => {
    setMapState(state);
    setMapMessage(message);
  }, []);

  return (
    <>
      <div className="hero">
        <div className="panel map-panel">
          <MapView onReady={handleReady} onFlightsChange={handleFlights} onStateChange={handleMapState} />
          {mapState !== "ready" && (
            <div className={`map-state map-state-${mapState}`} role={mapState === "error" ? "alert" : "status"}>
              <strong>
                {mapState === "loading" && "Loading your route map…"}
                {mapState === "empty" && "Your map is ready for its first flight"}
                {mapState === "error" && "Route map unavailable"}
              </strong>
              {mapState === "empty" && <span>Add a flight to draw your first great-circle route.</span>}
              {mapState === "error" && <span>{mapMessage}</span>}
            </div>
          )}
        </div>
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

  async function makeVideo(preferShare: boolean) {
    if (!map || flights.length === 0 || !capabilities.recording) return;
    setBusy("video");
    setError(null);
    setSuccess(null);
    try {
      const blob = await recordFlightFootprint(map, flights);
      const outcome = await shareOrDownload(blob, "my-flightpath.webm", preferShare);
      setSuccess(outcome === "shared" ? "Your footprint video was shared." : "Your footprint video was downloaded.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not record your footprint.");
    } finally {
      setBusy(null);
    }
  }

  async function makePoster(preferShare: boolean) {
    if (!map || flights.length === 0) return;
    setBusy("poster");
    setError(null);
    setSuccess(null);
    try {
      const stats: OverviewStats = await getOverviewStats();
      const blob = await renderPoster(map, stats);
      if (!blob) throw new Error("This browser could not render the poster.");
      const outcome = await shareOrDownload(blob, "my-flightpath.png", preferShare);
      setSuccess(outcome === "shared" ? "Your poster was shared." : "Your poster was downloaded.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not create your poster.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="panel export-panel" id="footprint" aria-labelledby="footprint-title">
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
              <>
                {capabilities.sharing && (
                  <button className="button primary" disabled={busy !== null} onClick={() => void makeVideo(true)}>
                    {busy === "video" ? "Recording…" : "Record & share video"}
                  </button>
                )}
                <button className={capabilities.sharing ? "button" : "button primary"} disabled={busy !== null} onClick={() => void makeVideo(false)}>
                  {busy === "video" ? "Recording…" : "Record & download video"}
                </button>
              </>
            ) : (
              <span className="notice info">Video recording isn’t available in this browser. Poster download is still supported.</span>
            )}
            {capabilities.sharing && (
              <button className="button" disabled={busy !== null} onClick={() => void makePoster(true)}>
                {busy === "poster" ? "Rendering…" : "Share poster"}
              </button>
            )}
            <button className="button" disabled={busy !== null} onClick={() => void makePoster(false)}>
              {busy === "poster" ? "Rendering…" : "Download poster"}
            </button>
          </div>
          {success && <div className="notice success" role="status">{success}</div>}
          {error && <div className="notice error" role="alert">{error}</div>}
        </>
      )}
    </section>
  );
}
