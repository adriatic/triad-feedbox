/**
 * Dates and counts as the screens show them: "Nov 3, 2026", "214 votes", "1 comment".
 *
 * A moment (an ISO timestamp, such as when an idea was posted) is shown as the
 * date in the given time zone: the viewer's own, read in the browser
 * (components/LocalDate.tsx; task F5b). An idea posted at 5 PM on Nov 17 in
 * California is "Nov 17" there, although it is already Nov 18 in UTC. A
 * calendar date (2026-11-03, such as a changelog release date) has no time
 * zone and is shown as written, the same everywhere.
 */
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;

const CALENDAR_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Year, month (1 to 12) and day of a calendar date, or of a moment in a time zone (an IANA name such as America/Los_Angeles). */
export function dateParts(value: string, timeZone: string): { year: number; month: number; day: number } {
  const calendar = CALENDAR_DATE.exec(value);
  const d = new Date(calendar ? `${value}T00:00:00Z` : value);
  if (Number.isNaN(d.getTime())) throw new Error(`Not a date: ${value}`);
  if (calendar) return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
  const parts = new Intl.DateTimeFormat("en-US", { timeZone, year: "numeric", month: "numeric", day: "numeric" }).formatToParts(d);
  const part = (type: Intl.DateTimeFormatPartTypes) => Number(parts.find((p) => p.type === type)?.value);
  return { year: part("year"), month: part("month"), day: part("day") };
}

/** "Nov 3, 2026". A calendar date (2026-11-03) as written; a timestamp (2026-11-03T14:00:00Z) as the date in `timeZone`. */
export function formatDate(value: string, timeZone = "UTC"): string {
  const { year, month, day } = dateParts(value, timeZone);
  return `${MONTHS[month - 1]} ${day}, ${year}`;
}

/** "Oct 9", as the comments show their date (Idea.dc.html), in `timeZone`. */
export function formatMonthDay(value: string, timeZone = "UTC"): string {
  const { month, day } = dateParts(value, timeZone);
  return `${MONTHS[month - 1]} ${day}`;
}

/** 1204 → "1,204". */
export function formatNumber(n: number): string {
  const sign = n < 0 ? "-" : "";
  return sign + String(Math.trunc(Math.abs(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

export function formatCount(n: number, singular: string, plural: string): string {
  return `${formatNumber(n)} ${n === 1 ? singular : plural}`;
}

export const formatVotes = (n: number): string => formatCount(n, "vote", "votes");
export const formatComments = (n: number): string => formatCount(n, "comment", "comments");
