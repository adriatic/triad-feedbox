/** The four steps an idea moves through. Stored in lower case; shown with STATUS_LABELS. */
export type IdeaStatus = "open" | "planned" | "building" | "shipped";

/**
 * Who is looking at the board (F1 section 3).
 * - visitor: not signed in
 * - member: signed in, not an owner of this board
 * - owner: signed in and listed in board_owners for this board
 */
export type Role = "visitor" | "member" | "owner";

export interface Viewer {
  role: Role;
  userId: string | null;
  /** False until the person sets a display name on first sign-in (F1 section 4). */
  hasDisplayName: boolean;
}

export interface Idea {
  id: number;
  boardId: string;
  authorId: string;
  title: string;
  body: string;
  status: IdeaStatus;
  voteCount: number;
  commentCount: number;
  mergedIntoId: number | null;
  hiddenAt: string | null;
  /** ISO timestamp. */
  createdAt: string;
  /** ISO timestamp, set while the idea is Shipped. */
  shippedAt: string | null;
}

export interface ChangelogEntry {
  id: string;
  boardId: string;
  title: string;
  /** Calendar date, YYYY-MM-DD. */
  releasedOn: string;
  /** Null while the entry is a draft (owners only). */
  publishedAt: string | null;
}

export interface ChangelogItem {
  entryId: string;
  ideaId: number;
  note: string;
  position: number;
}

/** The outcome of a rule check: either allowed (with a value) or refused (with a reason a person can read). */
export type Result<T = undefined> = { ok: true; value: T } | { ok: false; reason: string };

export const ok = <T>(value: T): Result<T> => ({ ok: true, value });
export const refuse = <T = never>(reason: string): Result<T> => ({ ok: false, reason });
