import { afterEach, describe, expect, it, vi } from "vitest";
import { deriveStatus, paintForStatus } from "./flightPath";

describe("flight status rendering", () => {
  afterEach(() => vi.useRealTimers());

  it("derives scheduled, in-transit, and completed states from wall-clock time", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-24T12:00:00Z"));

    expect(deriveStatus("2026-07-24T13:00:00Z", "2026-07-24T15:00:00Z")).toBe("scheduled");
    expect(deriveStatus("2026-07-24T11:00:00Z", "2026-07-24T13:00:00Z")).toBe("in_transit");
    expect(deriveStatus("2026-07-24T09:00:00Z", "2026-07-24T11:00:00Z")).toBe("completed");
  });

  it("keeps each map state visually distinct", () => {
    expect(paintForStatus("scheduled", "#FF10F0")["line-opacity"]).toBe(0.35);
    expect(paintForStatus("in_transit", "#FF10F0")["line-dasharray"]).toEqual([2, 2]);
    expect(paintForStatus("completed", "#FF10F0")["line-width"]).toBe(2.5);
    expect(paintForStatus("completed", "#FF10F0")["line-opacity"]).toBe(1);
    expect(paintForStatus("cancelled", "#FF10F0")["line-color"]).toBe("#9ca3af");
  });
});
