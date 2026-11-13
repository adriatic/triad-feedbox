import { describe, expect, it } from "vitest";
import { STATUSES, STATUS_LABELS, checkStatusChange, parseStatus, shippedAtAfterChange, tabFromParam, INITIAL_STATUS } from "./status";

describe("Statuses (F1 section 2, design brief)", () => {
  it("are Open, Planned, Building and Shipped, in that order, with exactly those words", () => {
    expect(STATUSES.map((s) => STATUS_LABELS[s])).toEqual(["Open", "Planned", "Building", "Shipped"]);
  });

  it("every new idea starts as Open", () => {
    expect(INITIAL_STATUS).toBe("open");
  });

  it("are read from the URL without caring about case; anything else is not a status", () => {
    expect(parseStatus("Planned")).toBe("planned");
    expect(parseStatus(" SHIPPED ")).toBe("shipped");
    expect(parseStatus("done")).toBeNull();
    expect(parseStatus(undefined)).toBeNull();
  });

  it("the board opens on the Open tab when the URL names no tab or an unknown one", () => {
    expect(tabFromParam(null)).toBe("open");
    expect(tabFromParam("archived")).toBe("open");
    expect(tabFromParam("building")).toBe("building");
  });
});

describe("Status changes (owner only, F1 sections 3 and 8)", () => {
  it("the owner may move an idea forward to any later status", () => {
    expect(checkStatusChange({ from: "open", to: "planned", inChangelog: false }).ok).toBe(true);
    expect(checkStatusChange({ from: "open", to: "shipped", inChangelog: false }).ok).toBe(true);
  });

  it("the owner may move an idea back, to correct a mistake", () => {
    expect(checkStatusChange({ from: "building", to: "open", inChangelog: false }).ok).toBe(true);
    expect(checkStatusChange({ from: "shipped", to: "building", inChangelog: false }).ok).toBe(true);
  });

  it("setting the same status again is refused", () => {
    const r = checkStatusChange({ from: "planned", to: "planned", inChangelog: false });
    expect(r).toEqual({ ok: false, reason: "The idea is already Planned." });
  });

  it("an idea listed in a changelog entry stays Shipped", () => {
    const r = checkStatusChange({ from: "shipped", to: "building", inChangelog: true });
    expect(r.ok).toBe(false);
  });

  it("shipped_at is set when an idea becomes Shipped, kept if it already was, and cleared when it leaves", () => {
    const now = "2026-11-13T12:00:00Z";
    expect(shippedAtAfterChange("shipped", null, now)).toBe(now);
    expect(shippedAtAfterChange("shipped", "2026-11-03T10:00:00Z", now)).toBe("2026-11-03T10:00:00Z");
    expect(shippedAtAfterChange("building", "2026-11-03T10:00:00Z", now)).toBeNull();
  });
});
