import { createClient } from "@supabase/supabase-js";

const configuredUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
const configuredAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim();

function isPlaceholder(value: string | undefined) {
  return !value || value.includes("placeholder") || value.includes("your-project");
}

export function hasSupabaseConfig(url: string | undefined, anonKey: string | undefined) {
  return !isPlaceholder(url?.trim()) && !isPlaceholder(anonKey?.trim());
}

export const isSupabaseConfigured = hasSupabaseConfig(configuredUrl, configuredAnonKey);

// Supabase validates its URL at module evaluation time. A local, non-routable
// fallback keeps static builds deterministic; callers use
// assertSupabaseConfigured() before any request is attempted.
export const supabase = createClient(
  isSupabaseConfigured ? configuredUrl! : "http://127.0.0.1:54321",
  isSupabaseConfigured ? configuredAnonKey! : "unconfigured-anon-key",
);

export function assertSupabaseConfigured() {
  if (!isSupabaseConfigured) {
    throw new Error(
      "Supabase is not configured. Add NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.",
    );
  }
}
