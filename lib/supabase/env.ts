// The app's settings (F1 section 9; CLAUDE.md "App settings on Vercel").
// Every place in the app reads them through these helpers, so a missing
// setting is named in plain words instead of failing somewhere deeper.
// Only the publishable key is ever read:
// every rule is enforced by row-level security in the database.
// NEXT_PUBLIC_* values are inlined into the browser bundle at build time, so
// they are read with literal names.

function required(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing environment variable ${name}. Set it in Vercel (Settings, Environment Variables) for this environment and build again; see "App settings on Vercel" in CLAUDE.md.`);
  return value;
}

export function supabaseUrl(): string {
  return required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL);
}

export function supabasePublishableKey(): string {
  return required("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
}

/** The one board this deployment shows (F1 decision D1): feedbox on Production, lumen on Preview and locally. */
export function boardSlug(): string {
  return required("FEEDBOX_BOARD_SLUG", process.env.FEEDBOX_BOARD_SLUG);
}
