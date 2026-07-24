"use client";

import { useEffect, useState } from "react";
import { GeoStats as GeoStatsData, getGeoStats } from "@/lib/stats";

export default function GeoStats() {
  const [stats, setStats] = useState<GeoStatsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    getGeoStats()
      .then((data) => { if (active) setStats(data); })
      .catch((reason) => { if (active) setError(reason instanceof Error ? reason.message : "Could not load geographic stats."); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const empty = stats && stats.continents === 0 && stats.countries === 0 && stats.cities === 0;

  return (
    <section className="panel stats-panel" aria-labelledby="geo-title">
      <div className="eyebrow">Where you’ve been</div>
      <h2 className="section-title" id="geo-title">Geographic reach</h2>
      {loading ? (
        <div className="mini-grid" aria-busy="true">{[0, 1, 2, 3, 4].map((item) => <div className="mini-card skeleton" key={item} />)}</div>
      ) : error ? (
        <div className="notice error" role="alert">We couldn’t load geographic statistics. {error}</div>
      ) : empty ? (
        <div className="empty-state compact-empty">
          <strong>Your world map starts here</strong>
          <span>Complete a flight to count its continents, countries, cities, airports, and route.</span>
        </div>
      ) : stats ? (
        <div className="mini-grid">
          <Metric label="Continents" value={stats.continents} />
          <Metric label="Countries" value={stats.countries} />
          <Metric label="Cities" value={stats.cities} />
          <Metric label="Top airport" value={stats.topAirport ? `${stats.topAirport.iata} · ${stats.topAirport.visits} visits` : "No data yet"} />
          <Metric label="Top route" value={stats.topRoute ? `${stats.topRoute.pair} · ${stats.topRoute.count} flights` : "No data yet"} />
        </div>
      ) : null}
    </section>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return <article className="mini-card"><span>{label}</span><strong>{value}</strong></article>;
}
