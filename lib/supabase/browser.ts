"use client";
import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "./database.types";
import { supabasePublishableKey, supabaseUrl } from "./env";

/**
 * Supabase client for Client Components (F5 uses it for voting without a page reload).
 * It reads the same session cookies as the server client, with the publishable key only.
 */
export function createClient() {
  return createBrowserClient<Database>(supabaseUrl(), supabasePublishableKey());
}
