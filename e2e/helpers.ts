// Shared helpers for the end-to-end tests (F5). LOCAL Supabase only: the
// admin client uses the local development secret key that `supabase status`
// prints for the stack in Docker (see e2e/local-supabase.ts), only to make
// sign-in links without email, to set up a state, and to tidy up.
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, type Page } from "@playwright/test";
import { localSupabase } from "./local-supabase";

export const sb = localSupabase();

export const admin: SupabaseClient = createClient(sb.apiUrl, sb.secretKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export const viewerState = (page: Page) => page.getByTestId("viewer-state");

/** Test people of one spec file: e2e+<label>-<run>@feedbox.test, removed by cleanUp(). */
export function people(prefix: string) {
  const run = `${Date.now()}`;
  const emails: string[] = [];
  return {
    email(label: string): string {
      const email = `e2e+${prefix}-${label}-${run}@feedbox.test`;
      emails.push(email);
      return email;
    },
    /** Removes the people (and with them their ideas, votes and comments; the vote counts follow). */
    async cleanUp() {
      const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
      for (const u of data?.users ?? []) {
        if (u.email && emails.includes(u.email)) await admin.auth.admin.deleteUser(u.id);
      }
    },
  };
}

/** A sign-in link made the way the email templates build it (supabase/templates/). */
export async function signInLink(email: string, baseURL: string, next = "/"): Promise<{ href: string; tokenHash: string }> {
  const redirectTo = `${baseURL}/auth/confirm?next=${encodeURIComponent(next)}`;
  const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email, options: { redirectTo } });
  if (error) throw error;
  const tokenHash = data.properties.hashed_token;
  return { href: `${redirectTo}&token_hash=${tokenHash}&type=email`, tokenHash };
}

/**
 * Signs in through the real /auth/confirm page (the "Finish signing in"
 * button), and sets the display name if the person has none yet.
 */
export async function signIn(page: Page, baseURL: string, email: string, displayName: string | null, next = "/") {
  const { href } = await signInLink(email, baseURL, next);
  await page.goto(href);
  await page.getByRole("button", { name: "Finish signing in" }).click();
  if (displayName !== null) {
    await expect(page).toHaveURL(/\/welcome\?next=/);
    await page.getByLabel("Name shown with your ideas").fill(displayName);
    await page.getByRole("button", { name: "Continue" }).click();
  }
  await expect(viewerState(page)).not.toHaveText("Viewing as visitor");
}

/** A Supabase client signed in as this person, with the publishable key: what a hand-made API call can do. */
export async function apiAs(email: string, baseURL: string): Promise<SupabaseClient> {
  const { tokenHash } = await signInLink(email, baseURL);
  const client = createClient(sb.apiUrl, sb.publishableKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error } = await client.auth.verifyOtp({ type: "email", token_hash: tokenHash });
  if (error) throw error;
  return client;
}

export async function userId(email: string): Promise<string> {
  const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
  const id = data.users.find((u) => u.email === email)?.id;
  if (!id) throw new Error(`No user ${email}`);
  return id;
}

export async function boardId(slug = "lumen"): Promise<string> {
  const { data } = await admin.from("boards").select("id").eq("slug", slug).single().throwOnError();
  return data.id as string;
}

export async function ideaId(title: string): Promise<number> {
  const { data } = await admin.from("ideas").select("id").eq("title", title).single().throwOnError();
  return data.id as number;
}

export async function voteCount(title: string): Promise<number> {
  const { data } = await admin.from("ideas").select("vote_count").eq("title", title).single().throwOnError();
  return data.vote_count as number;
}
