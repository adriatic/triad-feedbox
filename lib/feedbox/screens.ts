import type { IdeaStatus } from "./types";
import { INITIAL_STATUS } from "./status";
import type { Sort } from "./list";
import { RATE_LIMIT_MESSAGE } from "./limits";

/**
 * Small rules the screens share (task F5). Pure TypeScript, so they are
 * tested in `unit` like the rest of the core library.
 */

/** Similar ideas while typing (F1 section 5): 300 ms after the last keystroke, 3 or more characters. */
export const SIMILAR_DEBOUNCE_MS = 300;
export const SIMILAR_MIN_CHARS = 3;
/** How many similar ideas Post an idea shows. */
export const SIMILAR_LIMIT = 5;
/** How many matches the board's search box asks for (the most similar_ideas returns). */
export const SEARCH_LIMIT = 20;

/** The text the similar-ideas search uses: one line, single spaces, trimmed. */
export function searchText(raw: string | null | undefined): string {
  return (raw ?? "").replace(/\s+/g, " ").trim();
}

/** True when the text is long enough to ask for similar ideas (same rule as similar_ideas in SQL). */
export function isSearchable(raw: string | null | undefined): boolean {
  return [...searchText(raw)].length >= SIMILAR_MIN_CHARS;
}

/** The heading over the similar-ideas list on Post an idea (PostIdea.dc.html). */
export function similarHeading(title: string, found: number): string {
  if (found > 0) return "Similar ideas already on the board";
  return isSearchable(title) ? "No similar ideas yet" : "Similar ideas appear as you type";
}

/** The board's address for a tab, sort and search. Defaults are left out, so "/" is the Open tab, Top. */
export function boardHref({ tab, sort, q }: { tab: IdeaStatus; sort: Sort; q?: string }): string {
  const params = new URLSearchParams();
  if (tab !== INITIAL_STATUS) params.set("tab", tab);
  if (sort !== "top") params.set("sort", sort);
  const text = searchText(q);
  if (text) params.set("q", text);
  const s = params.toString();
  return s ? `/?${s}` : "/";
}

/** The square letter in the header (the designs show "L" for Lumen). */
export function boardInitial(name: string): string {
  const first = [...name.trim()][0];
  return first ? first.toUpperCase() : "F";
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as const;

/** "Oct 9", as the comments show their date (Idea.dc.html). UTC, like formatDate. */
export function formatMonthDay(value: string): string {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) throw new Error(`Not a date: ${value}`);
  return `${MONTHS[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

/** An idea's details as paragraphs: split at empty lines, single line breaks kept inside a paragraph. */
export function paragraphs(body: string): string[] {
  return body
    .replace(/\r\n?/g, "\n")
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
}

/** What the database says when it refuses a write (PostgREST error fields). */
export interface DbError {
  code?: string | null;
  message?: string | null;
  details?: string | null;
}

/**
 * The rate-limit trigger (F1 section 6) raises P0001 with detail "rate_limit:<kind>".
 * The screens then show RATE_LIMIT_MESSAGE.
 */
export function isRateLimited(error: DbError | null | undefined): boolean {
  if (!error) return false;
  return (error.details ?? "").startsWith("rate_limit:") || error.message === RATE_LIMIT_MESSAGE;
}

/** True when the database refused a second vote by the same person (primary key on votes). */
export function isDuplicateVote(error: DbError | null | undefined): boolean {
  return error?.code === "23505";
}

/** A refusal in words a person can act on. */
export function refusalMessage(error: DbError, what: string): string {
  if (isRateLimited(error)) return RATE_LIMIT_MESSAGE;
  return `${what} did not work. Reload the page and try again.`;
}
