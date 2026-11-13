import { ok, refuse, type ChangelogEntry, type ChangelogItem, type Idea, type Result } from "./types";
import { isListed } from "./list";

export interface ChangelogLine {
  ideaId: number;
  ideaTitle: string;
  voteCount: number;
  note: string;
}

export interface ChangelogRelease {
  id: string;
  title: string;
  releasedOn: string;
  lines: ChangelogLine[];
}

/**
 * The public changelog (F1 section 8, design screen 5): published entries only, newest release
 * first, each line linking back to its idea, in the order the owner chose.
 * Lines whose idea is hidden or gone are left out; an entry with no lines left is not shown.
 */
export function publishedChangelog(
  entries: readonly ChangelogEntry[],
  items: readonly ChangelogItem[],
  ideas: readonly Idea[],
): ChangelogRelease[] {
  const ideaById = new Map(ideas.map((i) => [i.id, i]));
  return entries
    .filter((e) => e.publishedAt !== null)
    .sort((a, b) =>
      a.releasedOn !== b.releasedOn
        ? (a.releasedOn < b.releasedOn ? 1 : -1)
        : (a.publishedAt! < b.publishedAt! ? 1 : a.publishedAt! > b.publishedAt! ? -1 : 0),
    )
    .map((e) => ({
      id: e.id,
      title: e.title,
      releasedOn: e.releasedOn,
      lines: items
        .filter((it) => it.entryId === e.id)
        .sort((a, b) => a.position - b.position)
        .flatMap((it) => {
          const idea = ideaById.get(it.ideaId);
          if (!idea || idea.hiddenAt !== null) return [];
          return [{ ideaId: idea.id, ideaTitle: idea.title, voteCount: idea.voteCount, note: it.note }];
        }),
    }))
    .filter((r) => r.lines.length > 0);
}

/**
 * The ideas the owner can add to a new changelog entry: Shipped, visible, not merged,
 * and not already in an entry. Most recently shipped first.
 */
export function ideasReadyForChangelog(ideas: readonly Idea[], items: readonly ChangelogItem[]): Idea[] {
  const used = new Set(items.map((it) => it.ideaId));
  return ideas
    .filter((i) => i.status === "shipped" && isListed(i) && !used.has(i.id))
    .sort((a, b) => ((a.shippedAt ?? "") < (b.shippedAt ?? "") ? 1 : (a.shippedAt ?? "") > (b.shippedAt ?? "") ? -1 : b.id - a.id));
}

/** Checks the ideas picked for one entry before it is saved. */
export function checkChangelogPicks(
  boardId: string,
  pickedIdeaIds: readonly number[],
  ideas: readonly Idea[],
  existingItems: readonly ChangelogItem[],
): Result {
  if (pickedIdeaIds.length === 0) return refuse("Pick at least one shipped idea.");
  if (new Set(pickedIdeaIds).size !== pickedIdeaIds.length) return refuse("An idea can appear only once in an entry.");
  const ideaById = new Map(ideas.map((i) => [i.id, i]));
  const used = new Set(existingItems.map((it) => it.ideaId));
  for (const id of pickedIdeaIds) {
    const idea = ideaById.get(id);
    if (!idea || idea.boardId !== boardId) return refuse("Every idea must be on this board.");
    if (idea.status !== "shipped") return refuse(`"${idea.title}" is not Shipped yet.`);
    if (used.has(id)) return refuse(`"${idea.title}" is already in another changelog entry.`);
  }
  return ok(undefined);
}
