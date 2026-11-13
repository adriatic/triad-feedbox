import { describe, expect, it } from "vitest";
import { safeNextPath } from "./next-path";

describe("Return after sign-in (F1 section 4: the next path guard)", () => {
  it("returns to a page on this site, keeping its query and anchor", () => {
    expect(safeNextPath("/ideas/42")).toBe("/ideas/42");
    expect(safeNextPath("/?status=planned&sort=new")).toBe("/?status=planned&sort=new");
    expect(safeNextPath("/ideas/42#comments")).toBe("/ideas/42#comments");
  });

  it("never sends anyone to another site", () => {
    for (const bad of [
      "https://evil.example/",
      "//evil.example/path",
      "/\\evil.example",
      "\\\\evil.example",
      "javascript:alert(1)",
      "evil.example",
      "/ideas\\..\\@evil.example",
      "/%0a//evil.example",
    ]) {
      const result = safeNextPath(bad);
      expect(result.startsWith("/")).toBe(true);
      expect(result.startsWith("//")).toBe(false);
      expect(new URL(result, "http://feedbox.invalid").origin).toBe("http://feedbox.invalid");
    }
    expect(safeNextPath("https://evil.example/")).toBe("/");
    expect(safeNextPath("//evil.example/path")).toBe("/");
  });

  it("refuses hidden control characters", () => {
    expect(safeNextPath("/ideas/1\n//evil.example")).toBe("/");
    expect(safeNextPath("/ideas/1\t")).toBe("/");
  });

  it("does not return into sign-in itself, which would loop", () => {
    expect(safeNextPath("/sign-in")).toBe("/");
    expect(safeNextPath("/auth/confirm?token_hash=x")).toBe("/");
  });

  it("uses the fallback when nothing usable is given", () => {
    expect(safeNextPath(null)).toBe("/");
    expect(safeNextPath("")).toBe("/");
    expect(safeNextPath("/" + "a".repeat(600))).toBe("/");
    expect(safeNextPath(undefined, "/changelog")).toBe("/changelog");
  });
});
