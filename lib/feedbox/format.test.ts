import { describe, expect, it } from "vitest";
import { formatComments, formatDate, formatNumber, formatVotes } from "./format";

describe("Dates as the screens show them", () => {
  it("a calendar date reads 'Nov 3, 2026'", () => {
    expect(formatDate("2026-11-03")).toBe("Nov 3, 2026");
    expect(formatDate("2026-09-18")).toBe("Sep 18, 2026");
  });

  it("a timestamp is shown by its UTC date, the same on server and browser", () => {
    expect(formatDate("2026-10-03T23:30:00Z")).toBe("Oct 3, 2026");
    expect(formatDate("2026-10-04T01:30:00+02:00")).toBe("Oct 3, 2026");
  });

  it("refuses something that is not a date", () => {
    expect(() => formatDate("soon")).toThrow();
  });
});

describe("Counts as the screens show them", () => {
  it("votes and comments use singular and plural correctly", () => {
    expect(formatVotes(214)).toBe("214 votes");
    expect(formatVotes(1)).toBe("1 vote");
    expect(formatVotes(0)).toBe("0 votes");
    expect(formatComments(18)).toBe("18 comments");
    expect(formatComments(1)).toBe("1 comment");
  });

  it("large numbers get thousands separators", () => {
    expect(formatNumber(1204)).toBe("1,204");
    expect(formatNumber(1234567)).toBe("1,234,567");
    expect(formatVotes(5000)).toBe("5,000 votes");
  });
});
