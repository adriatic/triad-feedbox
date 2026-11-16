import { headers } from "next/headers";

/**
 * The address the sign-in email links back to.
 * Production sets NEXT_PUBLIC_SITE_URL. Previews and local runs use the address
 * the person is on, so the link returns to the same deployment. Supabase sends
 * a link only to an address listed in its Redirect URLs.
 */
export async function siteOrigin(): Promise<string> {
  const fixed = process.env.NEXT_PUBLIC_SITE_URL;
  if (fixed) return fixed.replace(/\/+$/, "");
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host");
  if (!host) throw new Error("Cannot tell this site's address: no Host header.");
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") || host.startsWith("127.0.0.1") ? "http" : "https");
  return `${proto}://${host}`;
}
