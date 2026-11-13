import { describe, expect, it } from "vitest";
import { ideasForTab, isListed, parseSort, sortIdeas, tabCounts } from "./list";
import { LUMEN, idea } from "./fixtures.test-helper";

const titles = (xs: { title: string }[]) => xs.map((x) => x.title);

describe("Board tabs (design screen 1)", () => {
  it("each tab shows only ideas with that status", () => {
    expect(titles(ideasForTab(LUMEN, "planned", "top"))).toEqual(["Dark mode for the editor", "Offline mode"]);
    expect(titles(ideasForTab(LUMEN, "building", "top"))).toEqual(["Export notes to Markdown"]);
  });

  it("tab counts match the Lumen board", () => {
    expect(tabCounts(LUMEN)).toEqual({ open: 4, planned: 2, building: 1, shipped: 2 });
  });

  it("merged ideas never appear in a list, not even for owners", () => {
    const merged = idea({ title: "Synch notes", mergedIntoId: 6 });
    expect(isListed(merged)).toBe(false);
    expect(isListed(merged, true)).toBe(false);
    expect(tabCounts([...LUMEN, merged], { includeHidden: true }).open).toBe(4);
  });

  it("hidden ideas appear only in an owner's list", () => {
    const hidden = idea({ title: "Buy cheap watches", hiddenAt: "2026-11-10T00:00:00Z" });
    expect(ideasForTab([...LUMEN, hidden], "open", "top")).toHaveLength(4);
    expect(ideasForTab([...LUMEN, hidden], "open", "top", { includeHidden: true })).toHaveLength(5);
  });
});

describe("Sorting (design screen 1: Sort Top or New)", () => {
  it("Top puts the most votes first", () => {
    expect(titles(ideasForTab(LUMEN, "open", "top"))).toEqual([
      "Sync between two laptops", "Search inside attachments", "Share a note by link", "Tag notes by colour",
    ]);
  });

  it("New puts the newest first", () => {
    expect(titles(ideasForTab(LUMEN, "open", "new"))).toEqual([
      "Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops",
    ]);
  });

  it("with equal votes, Top puts the newer idea first", () => {
    const a = idea({ title: "Older", voteCount: 10, createdAt: "2026-01-01T00:00:00Z" });
    const b = idea({ title: "Newer", voteCount: 10, createdAt: "2026-02-01T00:00:00Z" });
    expect(titles(sortIdeas([a, b], "top"))).toEqual(["Newer", "Older"]);
  });

  it("sorting does not change the list it was given", () => {
    const copy = [...LUMEN];
    sortIdeas(LUMEN, "new");
    expect(LUMEN).toEqual(copy);
  });

  it("the URL value is read without caring about case; anything unknown means Top", () => {
    expect(parseSort("New")).toBe("new");
    expect(parseSort("oldest")).toBe("top");
    expect(parseSort(null)).toBe("top");
  });
});
