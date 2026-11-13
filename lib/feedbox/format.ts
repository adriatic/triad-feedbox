/**
 * Dates and counts as the screens show them: "Nov 3, 2026", "214 votes", "1 comment".
 * Formatting is done by hand in UTC, so the server, the browser and the tests always agree.
 */
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;

/** Accepts a calendar date (2026-11-03) or an ISO timestamp (2026-11-03T14:00:00Z). */
export function formatDate(value: string): string {
  const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(value);
  const d = new Date(dateOnly ? `${value}T00:00:00Z` : value);
  if (Number.isNaN(d.getTime())) throw new Error(`Not a date: ${value}`);
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
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
