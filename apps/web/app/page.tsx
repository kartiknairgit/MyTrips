import OverviewStats from "@/components/OverviewStats";
import FlightCalendar from "@/components/FlightCalendar";
import GeoStats from "@/components/GeoStats";
import AirlineStats from "@/components/AirlineStats";
import AircraftStats from "@/components/AircraftStats";
import HeroWorkspace from "@/components/HeroWorkspace";
import CompatibilityQuiz from "@/components/CompatibilityQuiz";
import { isSupabaseConfigured } from "@/lib/supabaseClient";
import AuthPanel from "@/components/AuthPanel";

export default function Home() {
  return (
    <main className="app-shell">
      <header className="topbar">
        <h1 className="brand">Flight<span className="brand-mark">Path</span></h1>
        <nav className="section-nav" aria-label="Dashboard sections">
          <a href="#account">Account</a>
          <a href="#add-flight">Add flight</a>
          <a href="#overview">Overview</a>
          <a href="#calendar">Calendar</a>
          <a href="#geography">Geography</a>
          <a href="#airlines">Airlines</a>
          <a href="#aircraft">Aircraft</a>
          <a href="#footprint">Export</a>
          <a href="#compatibility">Compatibility</a>
        </nav>
      </header>
      {!isSupabaseConfigured && (
        <div className="notice error configuration-banner" role="alert">
          Supabase is not configured. Add the two public environment variables to connect your account.
        </div>
      )}
      <div className="content">
        <AuthPanel />
        <HeroWorkspace />
        <OverviewStats />
        <FlightCalendar />
        <GeoStats />
        <AirlineStats />
        <AircraftStats />
        <CompatibilityQuiz />
      </div>
    </main>
  );
}
