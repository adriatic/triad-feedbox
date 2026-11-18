import { describe, expect, it } from "vitest";
import { dateParts, formatComments, formatDate, formatMonthDay, formatNumber, formatVotes } from "./format";

describe("Dates as the screens show them", () => {
  it("a calendar date reads 'Nov 3, 2026'", () => {
    expect(formatDate("2026-11-03")).toBe("Nov 3, 2026");
    expect(formatDate("2026-09-18")).toBe("Sep 18, 2026");
  });

  it("an idea posted on an evening in California shows that evening's date there, not the UTC date (task F5b)", () => {
    // 5:04 PM on Nov 17, 2026, Pacific time (PST, UTC-8) is already 01:04 on Nov 18 in UTC.
    const posted = "2026-11-18T01:04:00Z";
    expect(formatDate(posted, "America/Los_Angeles")).toBe("Nov 17, 2026");
    expect(formatMonthDay(posted, "America/Los_Angeles")).toBe("Nov 17");
    expect(formatDate(posted, "UTC")).toBe("Nov 18, 2026");
    expect(formatDate(posted, "Europe/Berlin")).toBe("Nov 18, 2026");
    // The same moment as the database sends it (timestamptz, with an offset).
    expect(formatDate("2026-11-18 01:04:00+00", "America/Los_Angeles")).toBe("Nov 17, 2026");
    expect(formatDate("2026-11-17T17:04:00-08:00", "America/Los_Angeles")).toBe("Nov 17, 2026");
  });

  it("a moment is the date in the given time zone, across months and years", () => {
    expect(formatDate("2026-10-03T23:30:00Z", "UTC")).toBe("Oct 3, 2026");
    expect(formatDate("2026-10-04T01:30:00+02:00", "UTC")).toBe("Oct 3, 2026");
    expect(formatDate("2026-12-31T23:30:00Z", "Asia/Tokyo")).toBe("Jan 1, 2027");
    expect(formatMonthDay("2026-10-09T10:00:00Z", "UTC")).toBe("Oct 9");
    expect(formatMonthDay("2026-12-31T23:30:00-02:00", "UTC")).toBe("Jan 1");
    expect(formatMonthDay("2026-11-01T06:30:00Z", "America/Los_Angeles")).toBe("Oct 31");
    expect(dateParts("2026-11-18T01:04:00Z", "America/New_York")).toEqual({ year: 2026, month: 11, day: 17 });
  });

  it("a calendar date (a changelog release) is shown as written in every time zone", () => {
    for (const zone of ["UTC", "America/Los_Angeles", "Pacific/Kiritimati", "Pacific/Pago_Pago"]) {
      expect(formatDate("2026-11-03", zone)).toBe("Nov 3, 2026");
    }
  });

  it("refuses something that is not a date", () => {
    expect(() => formatDate("soon")).toThrow("Not a date");
    expect(() => formatMonthDay("not a date")).toThrow("Not a date");
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
