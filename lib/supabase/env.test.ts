// F4a: a missing setting is named in plain words, never Supabase's
// "Your project's URL and Key are required" from deep inside a request.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { boardSlug, supabasePublishableKey, supabaseUrl } from "./env";

afterEach(() => vi.unstubAllEnvs());

describe("app settings", () => {
  it.each([
    ["NEXT_PUBLIC_SUPABASE_URL", supabaseUrl],
    ["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", supabasePublishableKey],
    ["FEEDBOX_BOARD_SLUG", boardSlug],
  ] as const)("a missing %s is named in the error", (name, read) => {
    vi.stubEnv(name, "");
    expect(read).toThrow(`Missing environment variable ${name}.`);
    vi.stubEnv(name, undefined);
    expect(read).toThrow(`Missing environment variable ${name}.`);
  });

  it("each setting is returned when it is set", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:55421");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "sb_publishable_test");
    vi.stubEnv("FEEDBOX_BOARD_SLUG", "lumen");
    expect(supabaseUrl()).toBe("http://127.0.0.1:55421");
    expect(supabasePublishableKey()).toBe("sb_publishable_test");
    expect(boardSlug()).toBe("lumen");
  });

  it("the proxy, the browser client and the server client read the Supabase settings only through env.ts", () => {
    const root = join(__dirname, "..", "..");
    const files: string[] = ["proxy.ts"];
    const walk = (dir: string) => {
      for (const name of readdirSync(join(root, dir))) {
        const path = join(dir, name);
        if (statSync(join(root, path)).isDirectory()) walk(path);
        else if (/\.tsx?$/.test(name) && !name.endsWith(".test.ts")) files.push(path);
      }
    };
    ["app", "components", "lib"].forEach(walk);
    const offenders = files.filter((f) => f !== join("lib", "supabase", "env.ts"))
      .filter((f) => /process\.env\.(NEXT_PUBLIC_SUPABASE_\w+|FEEDBOX_BOARD_SLUG)|process\.env\.\w+!/.test(readFileSync(join(root, f), "utf8")));
    expect(offenders).toEqual([]);
  });
});
