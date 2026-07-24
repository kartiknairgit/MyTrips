import MapView from "@/components/MapView";
import FlightEntryForm from "@/components/FlightEntryForm";
import OverviewStats from "@/components/OverviewStats";

export default function Home() {
  return (
    <main className="app-shell">
      <header className="topbar">
        <h1 className="brand">Flight<span className="brand-mark">Path</span></h1>
        <span className="eyebrow">Your world in motion</span>
      </header>
      <div className="content">
        <div className="hero">
          <div className="panel map-panel"><MapView /></div>
          <FlightEntryForm />
        </div>
        <OverviewStats />
      </div>
    </main>
  );
}
