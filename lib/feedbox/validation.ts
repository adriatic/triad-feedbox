import { ok, refuse, type Result } from "./types";

/** Limits from F1 section 2 (ideas, comments, profiles) and section 8 (changelog). */
export const LIMITS = {
  titleMin: 4,
  titleMax: 120,
  bodyMax: 4000,
  commentMin: 1,
  commentMax: 2000,
  displayNameMin: 2,
  displayNameMax: 40,
  changelogTitleMin: 1,
  changelogTitleMax: 80,
  changelogNoteMin: 1,
  changelogNoteMax: 280,
} as const;

/** Length in characters as a person counts them (an emoji counts once). */
export function charLength(s: string): number {
  return [...s].length;
}

/** One line: trims and turns every run of spaces, tabs or line breaks into one space. */
export function singleLine(s: string): string {
  return s.replace(/\s+/g, " ").trim();
}

/** Several lines: unifies line endings, trims, and keeps at most one empty line in a row. */
export function multiLine(s: string): string {
  return s
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.replace(/[ \t]+$/g, ""))
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function lengthBetween(value: string, min: number, max: number, what: string): Result<string> {
  const n = charLength(value);
  if (n < min) return refuse(min === 1 ? `${what} cannot be empty.` : `${what} needs at least ${min} characters.`);
  if (n > max) return refuse(`${what} can have at most ${max} characters (now ${n}).`);
  return ok(value);
}

/** Idea title: one line, 4 to 120 characters. */
export function validateTitle(raw: string): Result<string> {
  return lengthBetween(singleLine(raw), LIMITS.titleMin, LIMITS.titleMax, "The title");
}

/** Idea details: optional, up to 4,000 characters. */
export function validateBody(raw: string): Result<string> {
  return lengthBetween(multiLine(raw), 0, LIMITS.bodyMax, "The details");
}

/** Comment: plain text, 1 to 2,000 characters. */
export function validateComment(raw: string): Result<string> {
  return lengthBetween(multiLine(raw), LIMITS.commentMin, LIMITS.commentMax, "The comment");
}

/**
 * Display name, asked once on first sign-in (F1 section 4): 2 to 40 characters, one line.
 * It may not contain "@", so nobody publishes an email address as their name by mistake.
 */
export function validateDisplayName(raw: string): Result<string> {
  const name = singleLine(raw);
  if (name.includes("@")) return refuse("Use a name, not an email address.");
  return lengthBetween(name, LIMITS.displayNameMin, LIMITS.displayNameMax, "The name");
}

/** Board slug (F1 section 2): 2 to 40 lowercase letters, digits or hyphens. */
export function validateSlug(raw: string): Result<string> {
  return /^[a-z0-9-]{2,40}$/.test(raw) ? ok(raw) : refuse("A board slug has 2 to 40 lowercase letters, digits or hyphens.");
}

/** Changelog entry title, for example "Lumen 2.4". */
export function validateChangelogTitle(raw: string): Result<string> {
  return lengthBetween(singleLine(raw), LIMITS.changelogTitleMin, LIMITS.changelogTitleMax, "The entry title");
}

/** One line per shipped idea in a changelog entry. */
export function validateChangelogNote(raw: string): Result<string> {
  return lengthBetween(singleLine(raw), LIMITS.changelogNoteMin, LIMITS.changelogNoteMax, "The note");
}

/** Release date of a changelog entry: a real calendar date, YYYY-MM-DD. */
export function validateReleaseDate(raw: string): Result<string> {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw.trim());
  if (!m) return refuse("Use a date like 2026-11-03.");
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const date = new Date(Date.UTC(y, mo - 1, d));
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== mo - 1 || date.getUTCDate() !== d) {
    return refuse("That date does not exist.");
  }
  return ok(raw.trim());
}
