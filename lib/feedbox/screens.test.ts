import { describe, expect, it } from "vitest";
import {
  boardHref,
  boardInitial,
  isDuplicateVote,
  isMergedRefusal,
  isRateLimited,
  isSearchable,
  paragraphs,
  RATE_LIMIT_MESSAGE,
  ownerRefusalMessage,
  refusalMessage,
  SIMILAR_DEBOUNCE_MS,
  SIMILAR_MIN_CHARS,
  searchText,
  similarHeading,
} from "./index";

describe("similar ideas while typing (F1 section 5)", () => {
  it("waits 300 ms and needs 3 characters", () => {
    expect(SIMILAR_DEBOUNCE_MS).toBe(300);
    expect(SIMILAR_MIN_CHARS).toBe(3);
  });

  it("counts characters after trimming and joining spaces", () => {
    expect(isSearchable("sy")).toBe(false);
    expect(isSearchable("  s  y  ")).toBe(true); // "s y" is 3 characters
    expect(isSearchable("syn")).toBe(true);
    expect(isSearchable("   ")).toBe(false);
    expect(isSearchable(null)).toBe(false);
    expect(searchText("  Sync \n notes ")).toBe("Sync notes");
  });

  it("names the list as the design does", () => {
    expect(similarHeading("", 0)).toBe("Similar ideas appear as you type");
    expect(similarHeading("Sy", 0)).toBe("Similar ideas appear as you type");
    expect(similarHeading("Sync notes", 0)).toBe("No similar ideas yet");
    expect(similarHeading("Sync notes", 3)).toBe("Similar ideas already on the board");
  });
});

describe("board address", () => {
  it("leaves out the defaults", () => {
    expect(boardHref({ tab: "open", sort: "top" })).toBe("/");
    expect(boardHref({ tab: "open", sort: "top", q: "  " })).toBe("/");
  });

  it("keeps tab, sort and search", () => {
    expect(boardHref({ tab: "planned", sort: "new" })).toBe("/?tab=planned&sort=new");
    expect(boardHref({ tab: "open", sort: "top", q: " sync  notes " })).toBe("/?q=sync+notes");
    expect(boardHref({ tab: "shipped", sort: "top", q: "a&b" })).toBe("/?tab=shipped&q=a%26b");
  });
});

describe("small formats", () => {
  it("takes the board's first letter", () => {
    expect(boardInitial("Lumen")).toBe("L");
    expect(boardInitial(" feedbox")).toBe("F");
    expect(boardInitial("")).toBe("F");
  });

  it("splits details into paragraphs at empty lines", () => {
    expect(paragraphs("One.\n\nTwo,\nstill two.\r\n\r\n\r\nThree.")).toEqual(["One.", "Two,\nstill two.", "Three."]);
    expect(paragraphs("  ")).toEqual([]);
  });
});

describe("refusals from the database", () => {
  const rateLimit = { code: "P0001", message: RATE_LIMIT_MESSAGE, details: "rate_limit:vote" };

  it("recognises the rate limit (F1 section 6)", () => {
    expect(isRateLimited(rateLimit)).toBe(true);
    expect(isRateLimited({ code: "P0001", message: "other", details: "rate_limit:idea" })).toBe(true);
    expect(isRateLimited({ code: "42501", message: "new row violates row-level security policy" })).toBe(false);
    expect(isRateLimited(null)).toBe(false);
  });

  it("recognises a second vote by the same person", () => {
    expect(isDuplicateVote({ code: "23505" })).toBe(true);
    expect(isDuplicateVote({ code: "42501" })).toBe(false);
    expect(isDuplicateVote(undefined)).toBe(false);
  });

  it("explains a refusal", () => {
    expect(refusalMessage(rateLimit, "Voting")).toBe("You are posting quickly. Try again in a few minutes.");
    expect(refusalMessage({ code: "42501" }, "Voting")).toBe("Voting did not work. Reload the page and try again.");
  });
});

describe("owner tools: refusals in words (task F6)", () => {
  it("says plainly when the person is not an owner (any more)", () => {
    expect(ownerRefusalMessage({ code: "42501", message: "Only an owner of this board can do this." }, "Hiding the idea"))
      .toBe("Only an owner of this board can do this. Reload the page: you may have been signed out.");
  });

  it("says when the idea or comment is gone", () => {
    expect(ownerRefusalMessage({ code: "P0002", message: "Idea not found." }, "Merging"))
      .toBe("Merging did not work: it no longer exists. Reload the page.");
  });

  it("passes on the database's own words when a rule refuses it", () => {
    expect(ownerRefusalMessage({ code: "23514", message: "This idea is in a changelog entry. Remove it from the entry first." }, "Merging"))
      .toBe("This idea is in a changelog entry. Remove it from the entry first.");
  });

  it("falls back to the general message otherwise", () => {
    expect(ownerRefusalMessage({ code: "XX000", message: "boom" }, "Changing the status")).toBe("Changing the status did not work. Reload the page and try again.");
  });
});

describe("a vote, unvote or comment on an idea that was just merged (task F6b)", () => {
  const merged = {
    code: "P0001",
    message: "This idea was just merged into “Sync between two laptops”. Vote there.",
    details: "merged:6",
  };

  it("is recognised by the database's detail", () => {
    expect(isMergedRefusal(merged)).toBe(true);
    expect(isMergedRefusal({ code: "P0001", message: "x", details: "rate_limit:vote" })).toBe(false);
    expect(isMergedRefusal(null)).toBe(false);
  });

  it("shows the database's own words, which say where to go instead", () => {
    expect(refusalMessage(merged, "Voting")).toBe("This idea was just merged into “Sync between two laptops”. Vote there.");
  });

  it("never shows another database message as it is", () => {
    expect(refusalMessage({ code: "42501", message: "new row violates row-level security policy", details: null }, "Voting"))
      .toBe("Voting did not work. Reload the page and try again.");
  });
});
