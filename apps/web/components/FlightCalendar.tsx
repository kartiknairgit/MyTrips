"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { getDailyCounts, getFlightYearRange, getMonthlyCounts } from "@/lib/stats";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const CURRENT_YEAR = new Date().getFullYear();
const CURRENT_MONTH = new Date().getMonth();

export default function FlightCalendar() {
  const [view, setView] = useState<"month" | "day">("month");
  const [year, setYear] = useState(CURRENT_YEAR);
  const [month, setMonth] = useState(CURRENT_MONTH);
  const [years, setYears] = useState<number[]>([CURRENT_YEAR]);
  const [hasFlights, setHasFlights] = useState(false);
  const [counts, setCounts] = useState<number[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const range = await getFlightYearRange();
      setYears(range.years);
      setHasFlights(range.hasFlights);
      if (!range.years.includes(year)) setYear(range.years.at(-1) ?? CURRENT_YEAR);
      const result = view === "month"
        ? await getMonthlyCounts(year)
        : await getDailyCounts(year, month);
      setCounts(result);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Could not load calendar data.");
    } finally {
      setLoading(false);
    }
  }, [month, view, year]);

  useEffect(() => { void load(); }, [load]);

  const chartData = useMemo(
    () => counts.map((count, index) => ({
      label: view === "month" ? MONTHS[index] : String(index + 1),
      flights: count,
    })),
    [counts, view],
  );
  const selectedTotal = counts.reduce((sum, count) => sum + count, 0);

  return (
    <section className="panel chart-panel" id="calendar" aria-labelledby="calendar-title">
      <div className="section-heading">
        <div>
          <div className="eyebrow">When you flew</div>
          <h2 className="section-title" id="calendar-title">Flight calendar</h2>
        </div>
        <div className="calendar-filters">
          <select aria-label="Calendar year" value={year} onChange={(event) => setYear(Number(event.target.value))}>
            {years.map((option) => <option value={option} key={option}>{option}</option>)}
          </select>
          {view === "day" && (
            <select aria-label="Calendar month" value={month} onChange={(event) => setMonth(Number(event.target.value))}>
              {MONTHS.map((label, index) => <option value={index} key={label}>{label}</option>)}
            </select>
          )}
        </div>
      </div>
      <div className="segmented compact" aria-label="Calendar granularity">
        <button type="button" aria-pressed={view === "month"} onClick={() => setView("month")}>Month</button>
        <button type="button" aria-pressed={view === "day"} onClick={() => setView("day")}>Day</button>
      </div>

      {loading ? (
        <div className="chart-loading skeleton" aria-label="Loading flight calendar" />
      ) : error ? (
        <div className="notice error" role="alert">We couldn’t load your calendar. {error}</div>
      ) : !hasFlights ? (
        <div className="empty-state">
          <strong>No flights on the calendar yet</strong>
          <span>Add a flight above and completed journeys will appear here.</span>
        </div>
      ) : selectedTotal === 0 ? (
        <div className="empty-state">
          <strong>No completed flights in this {view === "month" ? "year" : "month"}</strong>
          <span>Choose another period or add an earlier journey.</span>
        </div>
      ) : (
        <div className="chart-wrap" role="img" aria-label={`${selectedTotal} completed flights shown by ${view}`}>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={chartData} margin={{ top: 8, right: 8, left: -22, bottom: 0 }}>
              <CartesianGrid stroke="#292930" vertical={false} />
              <XAxis dataKey="label" stroke="#aaaab5" tickLine={false} axisLine={false} />
              <YAxis allowDecimals={false} stroke="#aaaab5" tickLine={false} axisLine={false} />
              <Tooltip cursor={{ fill: "rgba(255,255,255,.04)" }} contentStyle={{ background: "#111113", border: "1px solid #303038", borderRadius: 10 }} />
              <Bar dataKey="flights" fill="#FF10F0" radius={[5, 5, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </section>
  );
}
