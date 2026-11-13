import type { Idea, Viewer } from "./types";

/**
 * Everything a person can try to do on a board (F1 section 3).
 * The database enforces the same rules with row-level security; this module lets the
 * screens show or hide buttons and explain why, so both sides read the same list.
 */
export type Action =
  | "read"
  | "vote"
  | "postIdea"
  | "comment"
  | "changeStatus"
  | "merge"
  | "hide"
  | "writeChangelog";

const OWNER_ONLY: readonly Action[] = ["changeStatus", "merge", "hide", "writeChangelog"];
const NEEDS_SIGN_IN: readonly Action[] = ["vote", "postIdea", "comment"];

export function can(viewer: Viewer, action: Action): boolean {
  if (action === "read") return true;
  if (OWNER_ONLY.includes(action)) return viewer.role === "owner";
  if (NEEDS_SIGN_IN.includes(action)) {
    return viewer.role !== "visitor" && viewer.userId !== null && viewer.hasDisplayName;
  }
  return false;
}

/** What the screen should do when the action is not allowed. */
export function blockedBecause(viewer: Viewer, action: Action): "sign-in" | "set-name" | "owner-only" | null {
  if (can(viewer, action)) return null;
  if (OWNER_ONLY.includes(action)) return "owner-only";
  if (viewer.role === "visitor" || viewer.userId === null) return "sign-in";
  return "set-name";
}

/** Hidden ideas are seen by owners only. Merged ideas are not shown; their page redirects. */
export function canSeeIdea(viewer: Viewer, idea: Pick<Idea, "hiddenAt">): boolean {
  return idea.hiddenAt === null || viewer.role === "owner";
}

/** A person can vote on an idea that is visible and not merged. */
export function canVoteOn(viewer: Viewer, idea: Pick<Idea, "hiddenAt" | "mergedIntoId">): boolean {
  return can(viewer, "vote") && idea.hiddenAt === null && idea.mergedIntoId === null;
}

/** How the header names the signed-in state (design brief: every screen shows it). */
export function viewerStateLabel(viewer: Viewer, displayName: string | null): string {
  if (viewer.role === "visitor") return "Viewing as visitor";
  if (viewer.role === "owner") return "Signed in as owner";
  return displayName ? `Signed in as ${displayName}` : "Signed in";
}
