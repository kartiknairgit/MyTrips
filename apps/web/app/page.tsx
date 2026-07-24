import OverviewStats from "@/components/OverviewStats";
import FlightCalendar from "@/components/FlightCalendar";
import GeoStats from "@/components/GeoStats";
import AirlineStats from "@/components/AirlineStats";
import AircraftStats from "@/components/AircraftStats";
import HeroWorkspace from "@/components/HeroWorkspace";

export default function Home() {
  return (
    <main className="app-shell">
      <header className="topbar">
        <h1 className="brand">Flight<span className="brand-mark">Path</span></h1>
        <span className="eyebrow">Your world in motion</span>
      </header>
      <div className="content">
        <HeroWorkspace />
        <OverviewStats />
        <FlightCalendar />
        <GeoStats />
        <AirlineStats />
        <AircraftStats />
      </div>
    </main>
  );
}
