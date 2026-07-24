"use client";

import { FormEvent, useEffect, useState } from "react";
import type { User } from "@supabase/supabase-js";
import {
  assertSupabaseConfigured,
  isSupabaseConfigured,
  supabase,
} from "@/lib/supabaseClient";

export default function AuthPanel() {
  const [user, setUser] = useState<User | null>(null);
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(isSupabaseConfigured);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }
    let active = true;
    void supabase.auth.getUser().then(({ data }) => {
      if (active) {
        setUser(data.user);
        setLoading(false);
      }
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (active) setUser(session?.user ?? null);
    });
    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  async function sendMagicLink(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setMessage(null);
    try {
      assertSupabaseConfigured();
    } catch (configurationError) {
      setError(configurationError instanceof Error ? configurationError.message : "Supabase is not configured.");
      return;
    }
    setBusy(true);
    const { error: signInError } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: window.location.origin },
    });
    setBusy(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    setMessage("Check your email for a secure sign-in link.");
  }

  async function signOut() {
    setBusy(true);
    setError(null);
    const { error: signOutError } = await supabase.auth.signOut();
    setBusy(false);
    if (signOutError) {
      setError(signOutError.message);
      return;
    }
    window.location.reload();
  }

  async function copyUserId() {
    if (!user) return;
    try {
      await navigator.clipboard.writeText(user.id);
      setMessage("User ID copied. Share it only with someone you want to compare with.");
    } catch {
      setError("Copy failed. Select the user ID and copy it manually.");
    }
  }

  return (
    <section className="panel auth-panel" id="account" aria-labelledby="account-title">
      <div>
        <div className="eyebrow">Account</div>
        <h2 className="section-title" id="account-title">{user ? "You’re signed in" : "Sign in to FlightPath"}</h2>
        <p className="section-copy">
          {user
            ? "Your flights and comparisons are protected by your Supabase account."
            : "Use a password-free email link to load and save your private flight history."}
        </p>
      </div>
      {loading ? (
        <div className="notice info" aria-busy="true">Checking your session…</div>
      ) : user ? (
        <div className="account-actions">
          <div>
            <strong>{user.email}</strong>
            <label htmlFor="current-user-id">Compatibility user ID</label>
            <input id="current-user-id" readOnly value={user.id} />
          </div>
          <div className="button-row">
            <button className="button" type="button" onClick={() => void copyUserId()}>Copy user ID</button>
            <button className="button ghost" type="button" disabled={busy} onClick={() => void signOut()}>
              {busy ? "Signing out…" : "Sign out"}
            </button>
          </div>
        </div>
      ) : (
        <form className="auth-form" onSubmit={sendMagicLink}>
          <div className="field">
            <label htmlFor="sign-in-email">Email address</label>
            <input id="sign-in-email" required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" />
          </div>
          <button className="button primary" type="submit" disabled={busy || !isSupabaseConfigured}>
            {busy ? "Sending…" : "Email me a sign-in link"}
          </button>
        </form>
      )}
      {error && <div className="notice error" role="alert">{error}</div>}
      {message && <div className="notice success" role="status">{message}</div>}
    </section>
  );
}
