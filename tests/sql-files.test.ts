// SQL is code (task F3c): the SQL files Nik pastes into the Supabase SQL Editor.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { headerProblems, pastedSqlFiles } from "../scripts/sql-files";

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

describe("pasted SQL files", () => {
  const files = pastedSqlFiles(root);

  it("include the seed, the production scripts, the markers and the checks", () => {
    expect(files).toEqual(expect.arrayContaining([
      "supabase/seed.sql",
      "supabase/production/board-feedbox.sql",
      "supabase/production/undo-feedbox-v1.sql",
      "supabase/marker/feedbox-preview.sql",
      "supabase/marker/feedbox-prod.sql",
      "supabase/checks/prod-before-migration.sql",
      "supabase/checks/prod-after-migration.sql",
      "supabase/checks/preview-seed.sql",
      "supabase/checks/prod-ready-for-board.sql",
      "supabase/checks/prod-board.sql",
    ]));
  });

  it.each(files)("%s names itself, its line count and its last line", (path) => {
    expect(headerProblems(path, read(path))).toEqual([]);
  });
});

describe("check scripts", () => {
  const checks = pastedSqlFiles(root).filter((f) => f.startsWith("supabase/checks/"));
  const block = (text: string, name: string) => {
    const match = text.match(new RegExp(`-- shared:${name}:begin[\\s\\S]*?-- shared:${name}:end`));
    return match?.[0];
  };

  it.each(["project", "fingerprint", "counts", "result"])("share the block %s word for word", (name) => {
    const blocks = checks.map((f) => block(read(f), name));
    expect(blocks.every((b) => b !== undefined)).toBe(true);
    expect(new Set(blocks).size).toBe(1);
  });

  it.each(checks)("%s is one read-only SELECT (no statement that changes anything)", (path) => {
    // Code only: drop comment lines and the text inside '...' string literals.
    const body = read(path)
      .split("\n").filter((l) => !l.trimStart().startsWith("--")).join("\n")
      .replace(/'(?:[^']|'')*'/g, "''");
    expect(body).not.toContain("$");
    expect(body).not.toMatch(/\b(insert|update|delete|create|drop|alter|grant|revoke|truncate|do)\s/i);
    expect(body.match(/;/g)?.length).toBe(1);
  });
});

describe("the Feedbox v1 migration", () => {
  it("is exactly the reviewed file applied on feedbox-preview (423572c), never edited", () => {
    const text = read("supabase/migrations/20261113000000_feedbox_v1.sql");
    expect(createHash("sha256").update(text).digest("hex"))
      .toBe("25077cb5974b0810601816af39297a082cdd5b97a350e842a9832970d6795384");
  });
});
