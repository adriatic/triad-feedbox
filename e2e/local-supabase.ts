// The LOCAL Supabase in Docker that the end-to-end tests run against (on the
// Mac and in CI). Never a hosted project: the address must be 127.0.0.1.
// The keys are the local development keys that `supabase status` prints for
// the stack in Docker; they are read at run time and never written to a file.
import { execFileSync } from "node:child_process";

export interface LocalSupabase {
  apiUrl: string;
  publishableKey: string;
  secretKey: string;
  mailpitUrl: string;
}

let cached: LocalSupabase | undefined;

export function localSupabase(): LocalSupabase {
  if (cached) return cached;
  let raw: string;
  try {
    raw = execFileSync("npx", ["supabase", "status", "-o", "json"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    throw new Error("Local Supabase is not running. Start it with: npm run e2e:supabase");
  }
  const s = JSON.parse(raw) as Record<string, string | undefined>;
  const apiUrl = s.API_URL ?? "";
  if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(apiUrl)) {
    throw new Error(`Refusing to run: the end-to-end tests need the local Supabase at 127.0.0.1, not ${apiUrl || "nothing"}.`);
  }
  const publishableKey = s.PUBLISHABLE_KEY ?? "";
  const secretKey = s.SECRET_KEY ?? "";
  const mailpitUrl = s.MAILPIT_URL ?? "";
  if (!publishableKey || !secretKey || !mailpitUrl) throw new Error("`supabase status` did not give the local keys and Mailpit address.");
  cached = { apiUrl, publishableKey, secretKey, mailpitUrl };
  return cached;
}
