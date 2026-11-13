import { describe, expect, it } from "vitest";
import { checkMerge, mergeVotes } from "./merge";
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
