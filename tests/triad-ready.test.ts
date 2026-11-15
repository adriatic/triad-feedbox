// TRIAD readiness check (task T1): scripts/triad-ready.sh. It only reads, so
// these tests look at its text; the script itself is run on Nik's Mac.
import { execFileSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const path = join(__dirname, "..", "scripts", "triad-ready.sh");
const text = readFileSync(path, "utf8");
// The header runs from the first "# ====" line to the second.
const header = text.slice(0, text.indexOf("\n# ====", text.indexOf("\n# ====") + 1));
const body = text.slice(header.length);
// The script's lines without comments.
const code = body.split("\n").filter((line) => !/^\s*#/.test(line)).join("\n");

describe("scripts/triad-ready.sh", () => {
  it("is valid bash and executable", () => {
    execFileSync("bash", ["-n", path]);
    expect(statSync(path).mode & 0o111).not.toBe(0);
  });

  it("documents every test override in its header", () => {
    const used = new Set(code.match(/TRIAD_[A-Z_]+/g));
    expect(used.size).toBeGreaterThan(10);
    for (const name of used) expect(header).toContain(`#   ${name} `);
  });

  it("calls GitHub only with the stored sign-in and never shows a token", () => {
    expect(code).toContain('env -u GH_TOKEN "$GH"');
    // "$GH" is run only inside gh_read; elsewhere it is only tested to exist.
    for (const line of code.split("\n").filter((l) => l.includes('"$GH"'))) {
      expect(line).toMatch(/^gh_read\(\) \{ limited "\$TIMEOUT" env -u GH_TOKEN "\$GH" "\$@"; \}$|\[ ! -x "\$GH" \]/);
    }
    expect(code).not.toMatch(/auth token|--show-token|\$GH_TOKEN|\.env/);
  });

  it("starts, changes and signs in to nothing", () => {
    // Commands that would change something; "colima start" may appear only
    // inside a message telling Nik what to type.
    expect(code).not.toMatch(/^\s*(colima|open|osascript|supabase|npm|npx|rm -rf|mkdir|git (push|commit|checkout|switch|reset|fetch|pull))\b/m);
    expect(code).not.toMatch(/\b(gh_read|"\$GH") +(auth|pr|repo +(create|edit)|api +-X)/);
    for (const line of code.split("\n").filter((l) => /colima start/.test(l))) {
      expect(line).toMatch(/fail "Docker"/);
    }
  });

  it("gives every network check a time limit", () => {
    for (const line of code.split("\n").filter((l) => /\bcurl\b/.test(l))) {
      expect(line).toMatch(/limited "\$TIMEOUT" curl .*-m "\$TIMEOUT"/);
    }
    expect(code).toMatch(/ConnectTimeout=\$TIMEOUT/);
  });
});
