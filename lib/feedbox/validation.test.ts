import { describe, expect, it } from "vitest";
import {
  validateBody, validateChangelogNote, validateChangelogTitle, validateComment,
  validateDisplayName, validateReleaseDate, validateSlug, validateTitle,
} from "./validation";

describe("Idea title (F1 section 2)", () => {
  it("is trimmed and kept on one line", () => {
    expect(validateTitle("  Dark   mode\nfor the editor ")).toEqual({ ok: true, value: "Dark mode for the editor" });
  });

  it("needs at least 4 characters", () => {
    expect(validateTitle("  Sy ").ok).toBe(false);
    expect(validateTitle("Sync").ok).toBe(true);
  });

  it("can have at most 120 characters, counting an emoji once", () => {
    expect(validateTitle("a".repeat(120)).ok).toBe(true);
    expect(validateTitle("a".repeat(121))).toEqual({ ok: false, reason: "The title can have at most 120 characters (now 121)." });
    expect(validateTitle("🌙".repeat(120)).ok).toBe(true);
  });
});

describe("Idea details (F1 section 2)", () => {
  it("are optional", () => {
    expect(validateBody("   ")).toEqual({ ok: true, value: "" });
  });

  it("keep paragraphs but not runs of empty lines", () => {
    expect(validateBody("First line\r\n\r\n\r\n\r\nSecond line  ")).toEqual({ ok: true, value: "First line\n\nSecond line" });
  });

  it("can have at most 4,000 characters", () => {
    expect(validateBody("x".repeat(4000)).ok).toBe(true);
    expect(validateBody("x".repeat(4001)).ok).toBe(false);
  });
});

describe("Comments (F1 section 7)", () => {
  it("cannot be empty", () => {
    expect(validateComment(" \n ")).toEqual({ ok: false, reason: "The comment cannot be empty." });
  });

  it("can have at most 2,000 characters", () => {
    expect(validateComment("y".repeat(2000)).ok).toBe(true);
    expect(validateComment("y".repeat(2001)).ok).toBe(false);
  });
});

describe("Display name, asked once at first sign-in (F1 section 4)", () => {
  it("is 2 to 40 characters on one line", () => {
    expect(validateDisplayName(" Mira   K. ")).toEqual({ ok: true, value: "Mira K." });
    expect(validateDisplayName("M").ok).toBe(false);
    expect(validateDisplayName("M".repeat(41)).ok).toBe(false);
  });

  it("may not be an email address, so emails are never published", () => {
    expect(validateDisplayName("sam@mail.example")).toEqual({ ok: false, reason: "Use a name, not an email address." });
  });
});

describe("Board slug (F1 section 2)", () => {
  it("is 2 to 40 lowercase letters, digits or hyphens", () => {
    expect(validateSlug("lumen").ok).toBe(true);
    expect(validateSlug("feedbox").ok).toBe(true);
    expect(validateSlug("my-app-2").ok).toBe(true);
    expect(validateSlug("Lumen").ok).toBe(false);
    expect(validateSlug("a").ok).toBe(false);
    expect(validateSlug("lumen/../x").ok).toBe(false);
  });
});

describe("Changelog entries (F1 section 8)", () => {
  it("have a title such as 'Lumen 2.4' of up to 80 characters", () => {
    expect(validateChangelogTitle(" Lumen 2.4 ")).toEqual({ ok: true, value: "Lumen 2.4" });
    expect(validateChangelogTitle("").ok).toBe(false);
    expect(validateChangelogTitle("v".repeat(81)).ok).toBe(false);
  });

  it("have one line of up to 280 characters per shipped idea", () => {
    expect(validateChangelogNote("Press ? anywhere to see every shortcut on one page, grouped by task.").ok).toBe(true);
    expect(validateChangelogNote("").ok).toBe(false);
    expect(validateChangelogNote("n".repeat(281)).ok).toBe(false);
  });

  it("have a real release date", () => {
    expect(validateReleaseDate("2026-11-03")).toEqual({ ok: true, value: "2026-11-03" });
    expect(validateReleaseDate("2026-02-30").ok).toBe(false);
    expect(validateReleaseDate("3 Nov 2026").ok).toBe(false);
  });
});
