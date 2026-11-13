import { ok, refuse, type Idea, type Result } from "./types";

type MergeIdea = Pick<Idea, "id" | "boardId" | "mergedIntoId" | "hiddenAt">;

/**
 * Merging duplicates (F1 section 5): the source idea is merged into the target.
 * There is no undo in version 1, so the screen asks for confirmation first.
 */
export function checkMerge(source: MergeIdea, target: MergeIdea): Result {
  if (source.id === target.id) return refuse("An idea cannot be merged into itself.");
  if (source.boardId !== target.boardId) return refuse("Both ideas must be on the same board.");
  if (source.mergedIntoId !== null) return refuse("This idea has already been merged.");
  if (target.mergedIntoId !== null) return refuse("The target idea has itself been merged. Merge into the idea it was merged into.");
  if (target.hiddenAt !== null) return refuse("The target idea is hidden. Unhide it first, or pick another idea.");
  return ok(undefined);
}

export interface MergedVotes {
  /** Everyone who now has a vote on the target. */
  targetVoters: string[];
  /** People who voted only on the source and gain a vote on the target. */
  added: number;
}

/**
 * Every person who voted on the source gets a vote on the target, unless they already have one.
 * Nobody is counted twice: the target grows by the number of new voters, not by the source's total.
 */
export function mergeVotes(sourceVoters: readonly string[], targetVoters: readonly string[]): MergedVotes {
  const target = new Set(targetVoters);
  let added = 0;
  for (const voter of new Set(sourceVoters)) {
    if (!target.has(voter)) {
      target.add(voter);
      added += 1;
    }
  }
  return { targetVoters: [...target], added };
}
