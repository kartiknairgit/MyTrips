import { describe, expect, it } from "vitest";
import { hasSupabaseConfig } from "./supabaseClient";

describe("hasSupabaseConfig", () => {
  it("rejects missing and documented placeholder values", () => {
    expect(hasSupabaseConfig(undefined, undefined)).toBe(false);
    expect(hasSupabaseConfig("https://placeholder.supabase.co", "placeholder-anon-key")).toBe(false);
    expect(hasSupabaseConfig("https://your-project.supabase.co", "your-anon-key")).toBe(false);
  });

  it("accepts a complete project URL and public anonymous key", () => {
    expect(hasSupabaseConfig("https://example.supabase.co", "public-anon-key")).toBe(true);
  });
});
