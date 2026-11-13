/**
 * The "next" path guard (F1 section 4). After sign-in the person returns to where they were,
 * but only to a path on this site. Anything else goes to the fallback, so a crafted link
 * cannot send someone to another site after they sign in.
 */
const MAX_LENGTH = 512;
const BASE = "http://feedbox.invalid";

export function safeNextPath(raw: string | null | undefined, fallback = "/"): string {
  if (typeof raw !== "string" || raw.length === 0 || raw.length > MAX_LENGTH) return fallback;
  // Must be a path on this site: "/" followed by something that is not "/" or "\".
  if (!raw.startsWith("/") || raw.startsWith("//") || raw.startsWith("/\\")) return fallback;
  if (raw.includes("\\")) return fallback;
  // No control characters (they can hide a different address).
  if (/[\u0000-\u001f\u007f]/.test(raw)) return fallback;

  let url: URL;
  try {
    url = new URL(raw, BASE);
  } catch {
    return fallback;
  }
  if (url.origin !== BASE) return fallback;
  // Never return into the sign-in machinery itself; that would loop.
  if (url.pathname === "/sign-in" || url.pathname.startsWith("/auth/")) return fallback;
  return url.pathname + url.search + url.hash;
}
