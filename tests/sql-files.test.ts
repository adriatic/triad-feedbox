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
      "supabase/production/owner-nik.sql",
      "supabase/checks/prod-owner.sql",
      "supabase/apply/preview-board-owner-ids.sql",
      "supabase/apply/prod-board-owner-ids.sql",
      "supabase/checks/preview-board-owner-ids.sql",
      "supabase/checks/prod-board-owner-ids.sql",
      "supabase/preview/owner-nik.sql",
      "supabase/checks/preview-owner-nik.sql",
      "supabase/people/remove-person.sql",
      "supabase/checks/person-removal.sql",
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

describe("changing scripts that check the migration", () => {
  it("owner-nik.sql uses the fingerprint block of the checks word for word", () => {
    const shared = read("supabase/checks/prod-board.sql").match(/-- shared:fingerprint:begin[\s\S]*?-- shared:fingerprint:end/)?.[0];
    expect(shared).toBeDefined();
    expect(read("supabase/production/owner-nik.sql")).toContain(shared!);
  });
});

describe("the Feedbox v1 migration", () => {
  it("is exactly the reviewed file applied on feedbox-preview (423572c), never edited", () => {
    const text = read("supabase/migrations/20261113000000_feedbox_v1.sql");
    expect(createHash("sha256").update(text).digest("hex"))
      .toBe("25077cb5974b0810601816af39297a082cdd5b97a350e842a9832970d6795384");
  });
});

describe("the O2 migration (board_owner_ids, decision F5-D1)", () => {
  const path = "supabase/migrations/20261118000000_board_owner_ids.sql";
  const migration = read(path);
  // The statements: everything after the leading comment lines.
  const statements = migration.split("\n");
  const first = statements.findIndex((l) => l !== "" && !l.startsWith("--"));
  const body = statements.slice(first).join("\n").trimEnd();

  it("is exactly the reviewed file (task O2), never edited after it has run on feedbox-preview", () => {
    expect(createHash("sha256").update(migration).digest("hex"))
      .toBe("e5b84fb52cea9182e085778f421ced8ec956e7d8dfe755d4be73ca81828cfa52");
  });

  it.each(["preview", "prod"])("supabase/apply/%s-board-owner-ids.sql runs the migration's statements word for word", (project) => {
    const pasted = read(`supabase/apply/${project}-board-owner-ids.sql`);
    const between = pasted.match(/-- migration:begin\n([\s\S]*?)\n-- migration:end/)?.[1];
    expect(between).toBe(body);
  });

  it.each(["preview", "prod"])("supabase/apply/%s-board-owner-ids.sql uses the fingerprint block of the checks word for word", (project) => {
    const shared = read("supabase/checks/prod-board.sql").match(/-- shared:fingerprint:begin[\s\S]*?-- shared:fingerprint:end/)?.[0];
    expect(shared).toBeDefined();
    expect(read(`supabase/apply/${project}-board-owner-ids.sql`)).toContain(shared!);
  });

  it.each([
    ["supabase/apply/preview-board-owner-ids.sql", "supabase/apply/prod-board-owner-ids.sql"],
    ["supabase/checks/preview-board-owner-ids.sql", "supabase/checks/prod-board-owner-ids.sql"],
  ])("%s and %s differ only in the project they are for", (preview, prod) => {
    const strip = (text: string) => text
      .split("\n").slice(1).join("\n")  // the header line names the file and its line count
      .replaceAll("feedbox-preview", "PROJECT").replaceAll("feedbox-prod", "PROJECT")
      .replaceAll("preview-board-owner-ids", "FILE").replaceAll("prod-board-owner-ids", "FILE")
      .replace(/^-- Run once[\s\S]*?\n--\n/m, "");
    expect(strip(read(prod))).toBe(strip(read(preview)));
  });
});

describe("task F6: Nik as an owner on feedbox-preview, and removing a person on request", () => {
  const shared = read("supabase/checks/prod-board.sql").match(/-- shared:fingerprint:begin[\s\S]*?-- shared:fingerprint:end/)?.[0];

  it.each(["supabase/preview/owner-nik.sql", "supabase/people/remove-person.sql"])(
    "%s uses the fingerprint block of the checks word for word, and expects the v1 + O2 fingerprint",
    (path) => {
      expect(shared).toBeDefined();
      const text = read(path);
      expect(text).toContain(shared!);
      expect(text).toContain("'ea60181fdd11e237aa19ee5d6d6c186d'");
    },
  );

  // A copy for one request may change only the lines between "request:begin" and "request:end".
  const outsideRequest = (text: string) =>
    text.split("\n").slice(1).join("\n").replace(/-- request:begin[\s\S]*?-- request:end/, "-- request")
      .replace(/-- end of [^\n]+\n$/, "");

  it("the templates hold no request: no project and the empty id", () => {
    for (const path of ["supabase/people/remove-person.sql", "supabase/checks/person-removal.sql"]) {
      const block = read(path).match(/-- request:begin[\s\S]*?-- request:end/)?.[0] ?? "";
      expect(block).toContain("'none'");
      expect(block).toContain("'00000000-0000-0000-0000-000000000000'");
    }
  });

  it("every copy for one request differs from its template only inside the block \"request\"", () => {
    const copies = pastedSqlFiles(root).filter((f) =>
      (/^supabase\/people\/remove-.+\.sql$/.test(f) && f !== "supabase/people/remove-person.sql") ||
      (/^supabase\/checks\/person-removal-.+\.sql$/.test(f)));
    for (const copy of copies) {
      const template = copy.startsWith("supabase/people/") ? "supabase/people/remove-person.sql" : "supabase/checks/person-removal.sql";
      expect(outsideRequest(read(copy)), copy).toBe(outsideRequest(read(template)));
      // The request names a person by user id, never by an email address (this repository is public).
      expect(read(copy).match(/-- request:begin[\s\S]*?-- request:end/)?.[0] ?? "", copy).not.toMatch(/@/);
    }
  });
});
