"use client";

import { FormEvent, useMemo, useState } from "react";
import { deriveStatus } from "@/lib/flightPath";
import { assertSupabaseConfigured, supabase } from "@/lib/supabaseClient";

type EntryMode = "lookup" | "manual";
type Step = "edit" | "confirm";

interface FlightDraft {
  flight_number: string;
  airline_iata: string;
  departure_iata: string;
  arrival_iata: string;
  departure_time: string;
  arrival_time: string;
  aircraft_iata: string;
}

const EMPTY_DRAFT: FlightDraft = {
  flight_number: "",
  airline_iata: "",
  departure_iata: "",
  arrival_iata: "",
  departure_time: "",
  arrival_time: "",
  aircraft_iata: "",
};

function toLocalDateTime(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  const offset = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 16);
}

export default function FlightEntryForm() {
  const [mode, setMode] = useState<EntryMode>("lookup");
  const [step, setStep] = useState<Step>("edit");
  const [draft, setDraft] = useState<FlightDraft>(EMPTY_DRAFT);
  const [lookupDate, setLookupDate] = useState("");
  const [source, setSource] = useState<"auto" | "manual">("manual");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const derivedStatus = useMemo(() => {
    if (!draft.departure_time || !draft.arrival_time) return null;
    return deriveStatus(
      new Date(draft.departure_time).toISOString(),
      new Date(draft.arrival_time).toISOString(),
    );
  }, [draft.arrival_time, draft.departure_time]);

  function update<K extends keyof FlightDraft>(key: K, value: FlightDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
    setError(null);
    setSuccess(null);
  }

  function switchMode(next: EntryMode) {
    setMode(next);
    setStep("edit");
    setError(null);
    setSuccess(null);
  }

  function validate() {
    if (!draft.flight_number.trim()) return "Enter a flight number.";
    if (!draft.departure_iata.trim() || !draft.arrival_iata.trim()) {
      return "Enter both departure and arrival airport IATA codes.";
    }
    if (!draft.departure_time || !draft.arrival_time) return "Enter departure and arrival times.";
    if (new Date(draft.arrival_time) <= new Date(draft.departure_time)) {
      return "Arrival must be after departure.";
    }
    return null;
  }

  async function lookupFlight(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSuccess(null);
    if (!draft.flight_number.trim() || !lookupDate) {
      setError("Enter a flight code and travel date to look it up.");
      return;
    }
    try {
      assertSupabaseConfigured();
    } catch (configurationError) {
      setError(configurationError instanceof Error ? configurationError.message : "Supabase is not configured.");
      return;
    }
    setBusy(true);
    const { data, error: lookupError } = await supabase.functions.invoke("lookup-flight", {
      body: { flight_iata: draft.flight_number.trim().toUpperCase(), flight_date: lookupDate },
    });
    setBusy(false);
    if (lookupError || data?.error) {
      setError(data?.error ?? lookupError?.message ?? "Flight lookup failed. You can enter it manually.");
      return;
    }
    setDraft({
      flight_number: data.flight_number ?? draft.flight_number,
      airline_iata: data.airline_iata ?? "",
      departure_iata: data.departure_iata ?? "",
      arrival_iata: data.arrival_iata ?? "",
      departure_time: toLocalDateTime(data.departure_time),
      arrival_time: toLocalDateTime(data.arrival_time),
      aircraft_iata: data.aircraft_iata ?? "",
    });
    setSource("auto");
    setStep("confirm");
  }

  function reviewManual(event: FormEvent) {
    event.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    setSource("manual");
    setStep("confirm");
  }

  async function saveFlight(event: FormEvent) {
    event.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    try {
      assertSupabaseConfigured();
    } catch (configurationError) {
      setError(configurationError instanceof Error ? configurationError.message : "Supabase is not configured.");
      return;
    }
    setBusy(true);
    setError(null);
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) {
      setBusy(false);
      setError("Sign in to save this flight.");
      return;
    }
    const { error: insertError } = await supabase.from("flights").insert({
      user_id: authData.user.id,
      flight_number: draft.flight_number.trim().toUpperCase(),
      airline_iata: draft.airline_iata.trim().toUpperCase() || null,
      departure_iata: draft.departure_iata.trim().toUpperCase(),
      arrival_iata: draft.arrival_iata.trim().toUpperCase(),
      departure_time: new Date(draft.departure_time).toISOString(),
      arrival_time: new Date(draft.arrival_time).toISOString(),
      aircraft_iata: draft.aircraft_iata.trim().toUpperCase() || null,
      source,
      status: derivedStatus ?? "scheduled",
    });
    setBusy(false);
    if (insertError) {
      setError(insertError.message);
      return;
    }
    setSuccess(`${draft.flight_number.toUpperCase()} was added to your FlightPath.`);
    setDraft(EMPTY_DRAFT);
    setLookupDate("");
    setStep("edit");
    setSource("manual");
  }

  return (
    <section className="panel" id="add-flight" aria-labelledby="add-flight-title">
      <div className="eyebrow">Build your route history</div>
      <h2 className="section-title" id="add-flight-title">Add a flight</h2>
      <p className="section-copy">
        Look up a scheduled flight or enter the details yourself. Nothing is saved until you review it.
      </p>

      <div className="segmented" aria-label="Flight entry method">
        <button type="button" aria-pressed={mode === "lookup"} onClick={() => switchMode("lookup")}>Auto-lookup</button>
        <button type="button" aria-pressed={mode === "manual"} onClick={() => switchMode("manual")}>Manual</button>
      </div>

      {step === "edit" && mode === "lookup" ? (
        <form onSubmit={lookupFlight}>
          <div className="form-grid">
            <Field label="Flight code" value={draft.flight_number} onChange={(value) => update("flight_number", value)} placeholder="SQ308" />
            <Field label="Travel date" value={lookupDate} onChange={setLookupDate} type="date" />
          </div>
          <div className="button-row">
            <button className="button primary" disabled={busy} type="submit">{busy ? "Looking up…" : "Auto-lookup flight"}</button>
          </div>
          <div className="notice info">New here? Look up your first flight, then review every field before it joins your map.</div>
        </form>
      ) : (
        <form onSubmit={step === "confirm" ? saveFlight : reviewManual}>
          {step === "confirm" && (
            <div className="confirm-summary">
              <strong>Confirm or edit every detail</strong>
              <span className="section-copy">Status is calculated from these times and cannot be set manually.</span>
              {derivedStatus && <span className="status-chip">Currently {derivedStatus.replace("_", " ")}</span>}
            </div>
          )}
          <FlightFields draft={draft} update={update} />
          <div className="button-row">
            {step === "confirm" && <button className="button ghost" type="button" onClick={() => setStep("edit")}>Back</button>}
            <button className="button primary" disabled={busy} type="submit">
              {busy ? "Saving…" : step === "confirm" ? "Save flight" : "Review flight"}
            </button>
          </div>
        </form>
      )}

      {error && <div className="notice error" role="alert">{error}</div>}
      {success && <div className="notice success" role="status">{success}</div>}
    </section>
  );
}

function FlightFields({ draft, update }: {
  draft: FlightDraft;
  update: <K extends keyof FlightDraft>(key: K, value: FlightDraft[K]) => void;
}) {
  return (
    <div className="form-grid">
      <Field label="Flight number" value={draft.flight_number} onChange={(v) => update("flight_number", v)} placeholder="SQ308" />
      <Field label="Airline IATA (optional)" value={draft.airline_iata} onChange={(v) => update("airline_iata", v)} placeholder="SQ" />
      <Field label="Departure airport" value={draft.departure_iata} onChange={(v) => update("departure_iata", v)} placeholder="SIN" />
      <Field label="Arrival airport" value={draft.arrival_iata} onChange={(v) => update("arrival_iata", v)} placeholder="LHR" />
      <Field label="Departure time" value={draft.departure_time} onChange={(v) => update("departure_time", v)} type="datetime-local" />
      <Field label="Arrival time" value={draft.arrival_time} onChange={(v) => update("arrival_time", v)} type="datetime-local" />
      <Field label="Aircraft IATA (optional)" value={draft.aircraft_iata} onChange={(v) => update("aircraft_iata", v)} placeholder="789" />
    </div>
  );
}

function Field({ label, value, onChange, type = "text", placeholder }: {
  label: string; value: string; onChange: (value: string) => void; type?: string; placeholder?: string;
}) {
  return (
    <div className="field">
      <label>
        {label}
        <input required={!label.includes("optional")} type={type} value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />
      </label>
    </div>
  );
}
