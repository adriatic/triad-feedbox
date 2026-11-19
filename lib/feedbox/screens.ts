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

/**
 * True when the database refused a vote, an unvote or a comment because the
 * idea was just merged (task F6b: trigger refuse_merged_idea and
 * remove_my_vote, detail "merged:<target id>"). Their message is written for
 * people and names where to go instead, so it is shown as it is.
 */
export function isMergedRefusal(error: DbError | null | undefined): boolean {
  return (error?.details ?? "").startsWith("merged:");
}

/** True when the database refused a second vote by the same person (primary key on votes). */
export function isDuplicateVote(error: DbError | null | undefined): boolean {
  return error?.code === "23505";
}

/** A refusal in words a person can act on. */
export function refusalMessage(error: DbError, what: string): string {
  if (isRateLimited(error)) return RATE_LIMIT_MESSAGE;
  if (isMergedRefusal(error) && error.message) return error.message;
  return `${what} did not work. Reload the page and try again.`;
}

/**
 * Why an owner tool did not work (task F6), from the owner functions' errors
 * (migration section 6: 42501 not an owner, P0002 not found, 23514 a rule
 * refuses it, with a message written for people).
 */
export function ownerRefusalMessage(error: DbError, what: string): string {
  if (error.code === "42501") return "Only an owner of this board can do this. Reload the page: you may have been signed out.";
  if (error.code === "P0002") return `${what} did not work: it no longer exists. Reload the page.`;
  if (error.code === "23514" && error.message) return error.message;
  return refusalMessage(error, what);
}
