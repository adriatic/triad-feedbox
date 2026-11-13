import { describe, expect, it } from "vitest";
import { checkChangelogPicks, ideasReadyForChangelog, publishedChangelog } from "./changelog";
import type { ChangelogEntry, ChangelogItem } from "./types";
import { BOARD, LUMEN, idea } from "./fixtures.test-helper";

const pin = idea({ id: 30, title: "Pin notes to the top of a notebook", voteCount: 121, status: "shipped", shippedAt: "2026-09-18T10:00:00Z" });
const ideas = [...LUMEN, pin];

const entries: ChangelogEntry[] = [
  { id: "e23", boardId: BOARD, title: "Lumen 2.3", releasedOn: "2026-09-18", publishedAt: "2026-09-18T12:00:00Z" },
  { id: "e24", boardId: BOARD, title: "Lumen 2.4", releasedOn: "2026-11-03", publishedAt: "2026-11-03T12:00:00Z" },
  { id: "draft", boardId: BOARD, title: "Lumen 2.5", releasedOn: "2026-12-01", publishedAt: null },
];
const items: ChangelogItem[] = [
  { entryId: "e24", ideaId: 5, note: "A notebook with 5,000 notes now opens in 1.6 seconds, down from 7.", position: 2 },
  { entryId: "e24", ideaId: 4, note: "Press ? anywhere to see every shortcut on one page, grouped by task.", position: 1 },
  { entryId: "e23", ideaId: 30, note: "Pinned notes stay above the rest, in the order you drag them.", position: 1 },
];

describe("The public changelog (F1 section 8, design screen 5)", () => {
  it("lists published releases, newest first, as in the design", () => {
    const releases = publishedChangelog(entries, items, ideas);
    expect(releases.map((r) => r.title)).toEqual(["Lumen 2.4", "Lumen 2.3"]);
  });

  it("never shows a draft", () => {
    expect(publishedChangelog(entries, items, ideas).some((r) => r.title === "Lumen 2.5")).toBe(false);
  });

  it("keeps the owner's order of lines, and each line links back to its idea with its votes", () => {
    const [latest] = publishedChangelog(entries, items, ideas);
    expect(latest!.lines).toEqual([
      { ideaId: 4, ideaTitle: "Keyboard shortcut cheat sheet", voteCount: 96, note: "Press ? anywhere to see every shortcut on one page, grouped by task." },
      { ideaId: 5, ideaTitle: "Faster startup on large notebooks", voteCount: 88, note: "A notebook with 5,000 notes now opens in 1.6 seconds, down from 7." },
    ]);
  });

  it("leaves out a line whose idea is hidden, and a release with no lines left", () => {
    const hiddenPin = { ...pin, hiddenAt: "2026-11-10T00:00:00Z" };
    const releases = publishedChangelog(entries, items, [...LUMEN, hiddenPin]);
    expect(releases.map((r) => r.title)).toEqual(["Lumen 2.4"]);
  });
});

describe("Writing a changelog entry (owner, F1 section 8)", () => {
  it("offers Shipped ideas that are not yet in any entry, most recently shipped first", () => {
    const fresh = idea({ id: 31, title: "Word count in the status bar", status: "shipped", shippedAt: "2026-11-12T10:00:00Z" });
    const older = idea({ id: 32, title: "Print a note", status: "shipped", shippedAt: "2026-11-10T10:00:00Z" });
    const ready = ideasReadyForChangelog([...ideas, older, fresh], items);
    expect(ready.map((i) => i.title)).toEqual(["Word count in the status bar", "Print a note"]);
  });

  it("does not offer ideas that are not Shipped, hidden or merged", () => {
    const hidden = idea({ id: 33, title: "Spam", status: "shipped", shippedAt: "2026-11-12T10:00:00Z", hiddenAt: "2026-11-12T11:00:00Z" });
    const merged = idea({ id: 34, title: "Duplicate", status: "shipped", shippedAt: "2026-11-12T10:00:00Z", mergedIntoId: 4 });
    expect(ideasReadyForChangelog([...LUMEN, hidden, merged], [])).toHaveLength(2);
  });

  it("accepts Shipped ideas from this board that are in no other entry", () => {
    const fresh = idea({ id: 35, title: "Word count", status: "shipped", shippedAt: "2026-11-12T10:00:00Z" });
    expect(checkChangelogPicks(BOARD, [35], [...ideas, fresh], items).ok).toBe(true);
  });

  it("refuses an empty entry, a repeated idea, an idea that is not Shipped, and one already used", () => {
    expect(checkChangelogPicks(BOARD, [], ideas, items).ok).toBe(false);
    expect(checkChangelogPicks(BOARD, [4, 4], ideas, []).ok).toBe(false);
    expect(checkChangelogPicks(BOARD, [1], ideas, [])).toEqual({ ok: false, reason: '"Dark mode for the editor" is not Shipped yet.' });
    expect(checkChangelogPicks(BOARD, [4], ideas, items).ok).toBe(false);
  });

  it("refuses an idea from another board", () => {
    const other = idea({ id: 36, title: "Elsewhere", status: "shipped", boardId: "board-other" });
    expect(checkChangelogPicks(BOARD, [36], [...ideas, other], []).ok).toBe(false);
  });
});
