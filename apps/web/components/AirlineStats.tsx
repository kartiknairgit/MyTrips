"use client";

import { useEffect, useMemo, useState } from "react";
import { Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { AirlineStats as AirlineStatsData, getAirlineStats } from "@/lib/stats";

const COLORS = ["#FF10F0", "#7A8CFF", "#62D49C", "#F0B35A", "#A8A8B3"];
const LABELS: Record<string, string> = {
  star_alliance: "Star Alliance",
  skyteam: "SkyTeam",
  oneworld: "Oneworld",
  other: "Other / unknown",
};

export default function AirlineStats() {
  const [stats, setStats] = useState<AirlineStatsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    getAirlineStats()
      .then((data) => { if (active) setStats(data); })
      .catch((reason) => { if (active) setError(reason instanceof Error ? reason.message : "Could not load airline stats."); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const chartData = useMemo(() => Object.entries(stats?.byAlliance ?? {}).map(([name, value]) => ({
    name: LABELS[name] ?? name,
    value,
  })), [stats]);

  return (
    <section className="panel stats-panel" id="airlines" aria-labelledby="airline-title">
      <div className="eyebrow">Who carried you</div>
      <h2 className="section-title" id="airline-title">Airline statistics</h2>
      {loading ? (
        <div className="split-stats"><div className="chart-loading skeleton" /><div className="feature-card skeleton" /></div>
      ) : error ? (
        <div className="notice error" role="alert">We couldn’t load airline statistics. {error}</div>
      ) : !stats || stats.totalAirlines === 0 ? (
        <div className="empty-state compact-empty"><strong>No airline history yet</strong><span>Complete a flight with an airline code to reveal your alliance mix.</span></div>
      ) : (
        <div className="split-stats">
          <div className="chart-wrap" role="img" aria-label={`Alliance breakdown across ${stats.totalAirlines} airlines`}>
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={chartData} dataKey="value" nameKey="name" innerRadius={62} outerRadius={100} paddingAngle={2}>
                  {chartData.map((item, index) => <Cell key={item.name} fill={COLORS[index % COLORS.length]} />)}
                </Pie>
                <Tooltip contentStyle={{ background: "#111113", border: "1px solid #303038", borderRadius: 10 }} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <article className="feature-card">
            <span className="eyebrow">Most flown</span>
            <strong>{stats.topAirline?.iata ?? "—"}</strong>
            <p>{stats.topAirline ? `${stats.topAirline.count} completed ${stats.topAirline.count === 1 ? "flight" : "flights"}` : "No top airline yet"}</p>
            <small>{stats.totalAirlines} unique {stats.totalAirlines === 1 ? "airline" : "airlines"}</small>
          </article>
        </div>
      )}
    </section>
  );
}
