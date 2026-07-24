"use client";

import { useEffect, useMemo, useState } from "react";
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { getAircraftStats } from "@/lib/stats";

export default function AircraftStats() {
  const [stats, setStats] = useState<Record<string, number> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    getAircraftStats()
      .then((data) => { if (active) setStats(data); })
      .catch((reason) => { if (active) setError(reason instanceof Error ? reason.message : "Could not load aircraft stats."); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const data = useMemo(
    () => Object.entries(stats ?? {}).sort((a, b) => b[1] - a[1]).map(([manufacturer, flights]) => ({ manufacturer, flights })),
    [stats],
  );

  return (
    <section className="panel stats-panel" aria-labelledby="aircraft-title">
      <div className="eyebrow">What you flew on</div>
      <h2 className="section-title" id="aircraft-title">Aircraft manufacturers</h2>
      <p className="section-copy">Flights without an aircraft type stay visible as Unknown, so incomplete lookup data never disappears.</p>
      {loading ? (
        <div className="chart-loading skeleton" aria-label="Loading aircraft statistics" />
      ) : error ? (
        <div className="notice error" role="alert">We couldn’t load aircraft statistics. {error}</div>
      ) : data.length === 0 ? (
        <div className="empty-state compact-empty"><strong>No aircraft data yet</strong><span>Your completed flights—including unknown aircraft—will appear here.</span></div>
      ) : (
        <div className="chart-wrap" role="img" aria-label={`Aircraft manufacturer breakdown with ${data.length} categories`}>
          <ResponsiveContainer width="100%" height={Math.max(260, data.length * 48)}>
            <BarChart data={data} layout="vertical" margin={{ top: 8, right: 20, left: 18, bottom: 0 }}>
              <CartesianGrid stroke="#292930" horizontal={false} />
              <XAxis type="number" allowDecimals={false} stroke="#aaaab5" axisLine={false} tickLine={false} />
              <YAxis type="category" dataKey="manufacturer" width={100} stroke="#aaaab5" axisLine={false} tickLine={false} />
              <Tooltip cursor={{ fill: "rgba(255,255,255,.04)" }} contentStyle={{ background: "#111113", border: "1px solid #303038", borderRadius: 10 }} />
              <Bar dataKey="flights" fill="#FF10F0" radius={[0, 6, 6, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </section>
  );
}
