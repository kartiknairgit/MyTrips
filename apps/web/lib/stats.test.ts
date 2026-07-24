import { describe, expect, it } from "vitest";
import { buildFlightYearRange } from "./stats";

describe("buildFlightYearRange", () => {
  it("returns the current year and an empty flag for a new user", () => {
    expect(buildFlightYearRange([], 2026)).toEqual({
      years: [2026],
      hasFlights: false,
    });
  });

  it("spans the earliest flight through the current year", () => {
    expect(buildFlightYearRange(["2023-04-10T10:00:00Z", "2025-01-01T00:00:00Z"], 2026))
      .toEqual({
        years: [2023, 2024, 2025, 2026],
        hasFlights: true,
      });
  });

  it("keeps future-only scheduled flights selectable", () => {
    expect(buildFlightYearRange(["2028-07-01T00:00:00Z"], 2026)).toEqual({
      years: [2026, 2027, 2028],
      hasFlights: true,
    });
  });
});
