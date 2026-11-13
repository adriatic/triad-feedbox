import type { Idea, IdeaStatus } from "./types";
import { STATUSES } from "./status";

export type Sort = "top" | "new";

/** The order of the sort control on the board ("Sort: Top", "Sort: New"). */
export const SORTS: readonly Sort[] = ["top", "new"] as const;
export const SORT_LABELS: Readonly<Record<Sort, string>> = { top: "Top", new: "New" };

/** Reads ?sort= from the URL. Anything unknown means Top. */
export function parseSort(value: string | null | undefined): Sort {
  return value?.trim().toLowerCase() === "new" ? "new" : "top";
}

/** Merged ideas never appear in lists. Hidden ideas appear only when the viewer is an owner. */
export function isListed(idea: Pick<Idea, "hiddenAt" | "mergedIntoId">, includeHidden = false): boolean {
  if (idea.mergedIntoId !== null) return false;
  return includeHidden || idea.hiddenAt === null;
}

function newestFirst(a: Idea, b: Idea): number {
  if (a.createdAt !== b.createdAt) return a.createdAt < b.createdAt ? 1 : -1;
  return b.id - a.id;
}

/**
 * Top: most votes first; equal votes, newest first.
 * New: newest first.
 * Returns a new array; the input is not changed.
 */
export function sortIdeas(ideas: readonly Idea[], sort: Sort): Idea[] {
  const copy = [...ideas];
  if (sort === "new") return copy.sort(newestFirst);
  return copy.sort((a, b) => b.voteCount - a.voteCount || newestFirst(a, b));
}

/** The ideas on one tab, sorted. */
export function ideasForTab(
  ideas: readonly Idea[],
  tab: IdeaStatus,
  sort: Sort,
  { includeHidden = false }: { includeHidden?: boolean } = {},
): Idea[] {
  return sortIdeas(
    ideas.filter((i) => i.status === tab && isListed(i, includeHidden)),
    sort,
  );
}

/** The number on each tab. Counts only what the viewer can see in the lists. */
export function tabCounts(
  ideas: readonly Idea[],
  { includeHidden = false }: { includeHidden?: boolean } = {},
): Record<IdeaStatus, number> {
  const counts = Object.fromEntries(STATUSES.map((s) => [s, 0])) as Record<IdeaStatus, number>;
  for (const idea of ideas) {
    if (isListed(idea, includeHidden)) counts[idea.status] += 1;
  }
  return counts;
}
