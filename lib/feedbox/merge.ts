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

export interface MergePreview {
  /** The target's vote count after the merge is at least this (everyone who voted for the source already voted for the target)... */
  votesAtLeast: number;
  /** ...and at most this (nobody voted for both). */
  votesAtMost: number;
  /** Comments that move from the source to the target. */
  commentsMoved: number;
}

/**
 * What a merge will do, told before it happens (task F6, F1 section 5). The
 * screen cannot know how many people voted for both ideas (a person's votes
 * are readable by that person only), so the target's new count is given as a
 * range: people who voted for both are counted once. merge_ideas returns the
 * exact count, which the target's page then shows.
 */
export function mergePreview(
  source: Pick<Idea, "voteCount" | "commentCount">,
  target: Pick<Idea, "voteCount">,
): MergePreview {
  return {
    votesAtLeast: Math.max(source.voteCount, target.voteCount),
    votesAtMost: source.voteCount + target.voteCount,
    commentsMoved: source.commentCount,
  };
}

/** The ideas an idea can be merged into: visible, not merged, not the idea itself; best known first. */
export function mergeTargets<T extends Pick<Idea, "id" | "title" | "voteCount" | "hiddenAt" | "mergedIntoId">>(
  sourceId: number,
  ideas: readonly T[],
): T[] {
  return ideas
    .filter((i) => i.id !== sourceId && i.hiddenAt === null && i.mergedIntoId === null)
    .sort((a, b) => b.voteCount - a.voteCount || a.title.localeCompare(b.title) || a.id - b.id);
}
