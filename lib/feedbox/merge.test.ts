import { describe, expect, it } from "vitest";
import { checkMerge, mergePreview, mergeTargets, mergeVotes } from "./merge";
import { idea } from "./fixtures.test-helper";

const sync = idea({ id: 6, title: "Sync between two laptops" });
const synch = idea({ id: 20, title: "Synch notes" });

describe("Merging duplicates (F1 section 5)", () => {
  it("merges an idea into another idea on the same board", () => {
    expect(checkMerge(synch, sync).ok).toBe(true);
  });

  it("refuses to merge an idea into itself", () => {
    expect(checkMerge(sync, sync).ok).toBe(false);
  });

  it("refuses to merge across boards", () => {
    expect(checkMerge(synch, { ...sync, boardId: "board-other" }).ok).toBe(false);
  });

  it("refuses an idea that was already merged, and a target that was merged", () => {
    expect(checkMerge({ ...synch, mergedIntoId: 6 }, sync).ok).toBe(false);
    expect(checkMerge(synch, { ...sync, mergedIntoId: 3 }).ok).toBe(false);
  });

  it("refuses a hidden target", () => {
    expect(checkMerge(synch, { ...sync, hiddenAt: "2026-11-10T00:00:00Z" }).ok).toBe(false);
  });

  it("moves votes so that every person is counted once", () => {
    const r = mergeVotes(["ana", "tom", "sam"], ["tom", "mira"]);
    expect(r.added).toBe(2);
    expect([...r.targetVoters].sort()).toEqual(["ana", "mira", "sam", "tom"]);
  });

  it("the target grows by the new voters only, not by the source's total", () => {
    expect(mergeVotes(["tom", "mira"], ["tom", "mira"]).added).toBe(0);
    expect(mergeVotes([], ["tom"]).added).toBe(0);
  });
});

describe("What a merge will do, told before it happens (task F6)", () => {
  it("gives the target's new vote count as a range, since people who voted for both are counted once", () => {
    expect(mergePreview({ voteCount: 3, commentCount: 2 }, { voteCount: 10 })).toEqual({
      votesAtLeast: 10,
      votesAtMost: 13,
      commentsMoved: 2,
    });
  });

  it("never promises fewer votes than the source had", () => {
    expect(mergePreview({ voteCount: 12, commentCount: 0 }, { voteCount: 1 }).votesAtLeast).toBe(12);
  });

  it("offers as targets only visible, unmerged ideas other than the source, most votes first", () => {
    const ideas = [
      idea({ id: 1, title: "A", voteCount: 5 }),
      idea({ id: 2, title: "B", voteCount: 9 }),
      idea({ id: 3, title: "C", voteCount: 7, hiddenAt: "2026-11-01T00:00:00Z" }),
      idea({ id: 4, title: "D", voteCount: 8, mergedIntoId: 2 }),
      idea({ id: 5, title: "E", voteCount: 5 }),
    ];
    expect(mergeTargets(1, ideas).map((i) => i.id)).toEqual([2, 5]);
  });
});
