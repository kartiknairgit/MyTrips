"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { getOverviewStats, OverviewStats as OverviewStatsData } from "@/lib/stats";
import { assertSupabaseConfigured, supabase } from "@/lib/supabaseClient";

export default function OverviewStats() {
  const [stats, setStats] = useState<OverviewStatsData | null>(null);
  const [homeCountry, setHomeCountry] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      assertSupabaseConfigured();
      const { data: auth } = await supabase.auth.getUser();
      let country = "";
      if (auth.user) {
        const { data: profile, error: profileError } = await supabase
          .from("profiles")
          .select("home_country")
          .eq("id", auth.user.id)
          .maybeSingle();
        if (profileError) throw profileError;
        country = profile?.home_country ?? "";
        setHomeCountry(country);
      }
      setStats(await getOverviewStats(country || undefined));
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Could not load your overview.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  async function saveCountry(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      assertSupabaseConfigured();
    } catch (configurationError) {
      setSaving(false);
      setError(configurationError instanceof Error ? configurationError.message : "Supabase is not configured.");
      return;
    }
    const { data: auth, error: authError } = await supabase.auth.getUser();
    if (authError || !auth.user) {
      setSaving(false);
      setError("Sign in to save your home country.");
      return;
    }
    const normalized = homeCountry.trim().toUpperCase();
    const { error: saveError } = await supabase.from("profiles").upsert({
      id: auth.user.id,
      home_country: normalized || null,
    });
    if (saveError) {
      setSaving(false);
      setError(saveError.message);
      return;
    }
    try {
      setStats(await getOverviewStats(normalized || undefined));
      setMessage("Home country saved. Your percentile uses a national cohort when enough data exists.");
    } catch (statsError) {
      setError(statsError instanceof Error ? statsError.message : "Country saved, but stats could not refresh.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="dashboard-section" id="overview" aria-labelledby="overview-title">
      <div className="section-heading">
        <div>
          <div className="eyebrow">At a glance</div>
          <h2 className="section-title" id="overview-title">Your flight story</h2>
        </div>
        <button className="button ghost" onClick={() => void load()} disabled={loading}>Refresh</button>
      </div>

      {loading ? (
        <div className="state-grid" aria-busy="true">
          {[0, 1, 2, 3].map((item) => <div className="stat-card skeleton" key={item} />)}
          <span className="sr-only">Loading overview statistics</span>
        </div>
      ) : error && !stats ? (
        <div className="notice error" role="alert">We couldn’t load your flight overview. {error}</div>
      ) : stats ? (
        <>
          <div className="state-grid">
            <StatCard label="Flights" value={stats.totalFlights.toLocaleString()} />
            <StatCard label="Kilometres" value={stats.totalKm.toLocaleString()} />
            <StatCard label="Hours airborne" value={stats.totalHours.toLocaleString()} />
            <StatCard label="Mileage rank" value={percentileCopy(stats)} accent />
          </div>
          {stats.totalFlights === 0 && (
            <div className="notice info">Your overview is ready for takeoff. Add your first completed flight to fill these cards.</div>
          )}
        </>
      ) : null}

      <form className="country-setting" onSubmit={saveCountry}>
        <div className="field">
          <label htmlFor="home-country">Home country (2-letter code)</label>
          <input id="home-country" maxLength={2} value={homeCountry} onChange={(event) => setHomeCountry(event.target.value)} placeholder="AU" />
        </div>
        <button className="button" type="submit" disabled={saving}>{saving ? "Saving…" : "Save country"}</button>
      </form>
      {error && stats && <div className="notice error" role="alert">{error}</div>}
      {message && <div className="notice success" role="status">{message}</div>}
    </section>
  );
}

function StatCard({ label, value, accent = false }: { label: string; value: string; accent?: boolean }) {
  return (
    <article className={`stat-card${accent ? " stat-card-accent" : ""}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  );
}

function percentileCopy(stats: OverviewStatsData) {
  if (stats.percentileScope === "no_data" || stats.percentile === null) return "Not enough flights yet";
  const rounded = Math.round(stats.percentile);
  if (stats.percentileScope === "national") return `Beats ${rounded}% of flyers nationally`;
  return `Beats ${rounded}% of flyers globally`;
}
