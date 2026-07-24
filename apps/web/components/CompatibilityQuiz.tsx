"use client";

import { FormEvent, useCallback, useEffect, useState } from "react";
import { assertSupabaseConfigured, supabase } from "@/lib/supabaseClient";

interface CompatRequest {
  id: string;
  requester_id: string;
  target_id: string;
  status: "pending" | "accepted" | "declined";
  created_at: string;
}

interface CompatReport {
  shared_airports: number;
  shared_routes: number;
  shared_airlines: number;
  compatibility_score: number;
}

export default function CompatibilityQuiz() {
  const [userId, setUserId] = useState<string | null>(null);
  const [targetId, setTargetId] = useState("");
  const [requests, setRequests] = useState<CompatRequest[]>([]);
  const [reports, setReports] = useState<Record<string, CompatReport>>({});
  const [waitingReport, setWaitingReport] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      assertSupabaseConfigured();
    } catch (configurationError) {
      setLoading(false);
      setError(configurationError instanceof Error ? configurationError.message : "Supabase is not configured.");
      return;
    }
    const { data: auth, error: authError } = await supabase.auth.getUser();
    if (authError || !auth.user) {
      setLoading(false);
      setError("Sign in to send or respond to compatibility requests.");
      return;
    }
    setUserId(auth.user.id);
    const { data, error: requestError } = await supabase
      .from("compat_requests")
      .select("id, requester_id, target_id, status, created_at")
      .order("created_at", { ascending: false });
    if (requestError) setError(requestError.message);
    else setRequests((data ?? []) as CompatRequest[]);
    setLoading(false);
  }, []);

  useEffect(() => { void load(); }, [load]);

  async function sendRequest(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSuccess(null);
    if (!userId) {
      setError("Sign in before sending a request.");
      return;
    }
    if (!isUuid(targetId.trim())) {
      setError("Enter the other flyer’s complete user ID.");
      return;
    }
    if (targetId.trim() === userId) {
      setError("Choose another flyer—you can’t compare with yourself.");
      return;
    }
    setBusyId("send");
    const { error: sendError } = await supabase.from("compat_requests").insert({
      requester_id: userId,
      target_id: targetId.trim(),
      status: "pending",
    });
    setBusyId(null);
    if (sendError) {
      setError(sendError.message);
      return;
    }
    setTargetId("");
    setSuccess("Compatibility request sent. The report stays locked until the other flyer accepts.");
    await load();
  }

  async function respond(request: CompatRequest, status: "accepted" | "declined") {
    setBusyId(request.id);
    setError(null);
    setSuccess(null);
    const { error: responseError } = await supabase
      .from("compat_requests")
      .update({ status, responded_at: new Date().toISOString() })
      .eq("id", request.id);
    setBusyId(null);
    if (responseError) {
      setError(responseError.message);
      return;
    }
    setSuccess(status === "accepted" ? "Request accepted. Your aggregate report is ready." : "Request declined. No comparison was generated.");
    await load();
  }

  async function viewReport(request: CompatRequest) {
    setBusyId(request.id);
    setError(null);
    setWaitingReport(null);
    if (request.status !== "accepted") {
      setBusyId(null);
      setWaitingReport(request.id);
      return;
    }
    const { data, error: reportError } = await supabase.rpc("get_compat_report", { request_id: request.id });
    setBusyId(null);
    if (reportError) {
      if (reportError.message.toLowerCase().includes("accept")) setWaitingReport(request.id);
      else setError(reportError.message);
      return;
    }
    const report = data?.[0] as CompatReport | undefined;
    if (!report) {
      setError("The accepted request returned no aggregate report.");
      return;
    }
    setReports((current) => ({ ...current, [request.id]: report }));
  }

  return (
    <section className="panel stats-panel" id="compatibility" aria-labelledby="compat-title">
      <div className="eyebrow">Compare by consent</div>
      <h2 className="section-title" id="compat-title">Flight compatibility</h2>
      <p className="section-copy">Invite another flyer, then compare only aggregate overlap after they accept. Individual flight lists always stay private.</p>

      <form className="compat-form" onSubmit={sendRequest}>
        <div className="field">
          <label htmlFor="compat-target">Other flyer’s user ID</label>
          <input id="compat-target" value={targetId} onChange={(event) => setTargetId(event.target.value)} placeholder="00000000-0000-0000-0000-000000000000" />
        </div>
        <button className="button primary" type="submit" disabled={busyId === "send"}>{busyId === "send" ? "Sending…" : "Send request"}</button>
      </form>

      {loading ? (
        <div className="request-list" aria-busy="true">{[0, 1].map((item) => <div className="request-card skeleton" key={item} />)}</div>
      ) : requests.length === 0 && !error ? (
        <div className="empty-state compact-empty"><strong>No compatibility requests</strong><span>Send your first invitation with another flyer’s user ID.</span></div>
      ) : (
        <div className="request-list">
          {requests.map((request) => {
            const incoming = request.target_id === userId;
            const otherId = incoming ? request.requester_id : request.target_id;
            const report = reports[request.id];
            return (
              <article className="request-card" key={request.id}>
                <div>
                  <span className={`status-chip status-${request.status}`}>{request.status}</span>
                  <strong>{incoming ? "Incoming request" : "Sent request"}</strong>
                  <small>With {shortId(otherId)} · {new Date(request.created_at).toLocaleDateString()}</small>
                </div>
                {incoming && request.status === "pending" ? (
                  <div className="button-row">
                    <button className="button primary" disabled={busyId === request.id} onClick={() => void respond(request, "accepted")}>Accept</button>
                    <button className="button ghost" disabled={busyId === request.id} onClick={() => void respond(request, "declined")}>Decline</button>
                  </div>
                ) : request.status !== "declined" ? (
                  <button className="button" disabled={busyId === request.id} onClick={() => void viewReport(request)}>
                    {busyId === request.id ? "Loading…" : "View report"}
                  </button>
                ) : <span className="section-copy">Declined—no report was created.</span>}
                {waitingReport === request.id && (
                  <div className="notice info">Waiting for acceptance. Aggregate compatibility is available only after the invited flyer consents.</div>
                )}
                {report && (
                  <div className="compat-report">
                    <strong>{Math.round(report.compatibility_score)}% compatible</strong>
                    <span>{report.shared_airports} shared airports</span>
                    <span>{report.shared_routes} shared routes</span>
                    <span>{report.shared_airlines} shared airlines</span>
                  </div>
                )}
              </article>
            );
          })}
        </div>
      )}
      {error && <div className="notice error" role="alert">{error}</div>}
      {success && <div className="notice success" role="status">{success}</div>}
    </section>
  );
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function shortId(value: string) {
  return `${value.slice(0, 8)}…${value.slice(-4)}`;
}
