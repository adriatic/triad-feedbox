// SQL is code (task F3c). Every SQL file Nik pastes into the Supabase SQL
// Editor starts with a header line and ends with a footer line:
//
//   -- <path> | <N> lines | last line: -- end of <file name>
//   ...
//   -- end of <file name>
//
// so he can see on screen that the whole file was copied. This module lists
// those files and checks the lines; tests/sql-files.test.ts runs it in CI.
//
//   node scripts/sql-files.ts          check, exit 1 on a problem
//   node scripts/sql-files.ts --fix    rewrite the line count in each header
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";

/**
 * Folders whose .sql files are pasted into the SQL Editor (paths from the repo root).
 * supabase/migrations is NOT in this list on purpose: a migration is never edited
 * after it has run on feedbox-preview (Claude.ai, 2026-11-13 9:31 PM), so the
 * Feedbox v1 migration keeps its reviewed text with no header or footer.
 */
export const PASTED_SQL_DIRS = ["supabase/production", "supabase/checks", "supabase/marker"];
/** Single pasted files. */
export const PASTED_SQL_FILES = ["supabase/seed.sql"];

export function pastedSqlFiles(root: string): string[] {
  const files = [...PASTED_SQL_FILES];
  for (const dir of PASTED_SQL_DIRS) {
    for (const name of readdirSync(join(root, dir)).sort()) {
      if (name.endsWith(".sql")) files.push(`${dir}/${name}`);
    }
  }
  return files;
}

export function headerFor(path: string, lineCount: number): string {
  return `-- ${path} | ${lineCount} lines | last line: ${footerFor(path)}`;
}

export function footerFor(path: string): string {
  return `-- end of ${basename(path)}`;
}

/** Problems with one file's header and footer; empty when it is right. */
export function headerProblems(path: string, text: string): string[] {
  const problems: string[] = [];
  if (!text.endsWith("\n")) problems.push(`${path}: the file must end with a newline`);
  const lines = text.endsWith("\n") ? text.slice(0, -1).split("\n") : text.split("\n");
  const expectedHeader = headerFor(path, lines.length);
  if (lines[0] !== expectedHeader) {
    problems.push(`${path}: first line is "${lines[0]}", expected "${expectedHeader}"`);
  }
  if (lines[lines.length - 1] !== footerFor(path)) {
    problems.push(`${path}: last line is "${lines[lines.length - 1]}", expected "${footerFor(path)}"`);
  }
  return problems;
}

/** The same file with the line count in its header set right. */
export function withFixedHeader(path: string, text: string): string {
  const lines = text.slice(0, -1).split("\n");
  if (!lines[0]?.startsWith(`-- ${path} | `)) return text;
  lines[0] = headerFor(path, lines.length);
  return lines.join("\n") + "\n";
}

const isMain = process.argv[1] !== undefined && basename(process.argv[1]) === "sql-files.ts";
if (isMain) {
  const root = process.cwd();
  const fix = process.argv.includes("--fix");
  let problems: string[] = [];
  for (const path of pastedSqlFiles(root)) {
    const full = join(root, path);
    let text = readFileSync(full, "utf8");
    if (fix) {
      const fixed = withFixedHeader(path, text);
      if (fixed !== text) writeFileSync(full, fixed);
      text = fixed;
    }
    problems = problems.concat(headerProblems(path, text));
  }
  for (const p of problems) console.error(p);
  if (problems.length > 0) process.exit(1);
  console.log("All pasted SQL files have the right header and footer.");
}
