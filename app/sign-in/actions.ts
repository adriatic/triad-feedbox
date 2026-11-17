"use server";
import { safeNextPath } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/server";
import { siteOrigin } from "@/lib/supabase/site";

export type SendLinkState = { status: "idle" } | { status: "sent"; email: string } | { status: "error"; message: string };

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * "Send me a link" (F1 section 4, step 2). The link in the email goes to
 * /auth/confirm?next=<path>. The address always holds "?next=", because both
 * email templates append "&token_hash=…&type=email" to it: "Confirm signup"
 * for a person's first sign-in, "Magic Link" for every later one
 * (supabase/templates/, task F4b).
 */
export async function sendLink(_prev: SendLinkState, form: FormData): Promise<SendLinkState> {
  const email = String(form.get("email") ?? "").trim();
  if (email.length > 254 || !EMAIL.test(email)) {
    return { status: "error", message: "Enter an email address, for example mira@example.com." };
  }
  const next = safeNextPath(String(form.get("next") ?? ""));
  const redirectTo = `${await siteOrigin()}/auth/confirm?next=${encodeURIComponent(next)}`;

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: redirectTo, shouldCreateUser: true },
  });
  if (error) {
    return {
      status: "error",
      message:
        error.status === 429
          ? "Too many sign-in emails were sent. Wait a few minutes and try again."
          : `The link could not be sent: ${error.message}`,
    };
  }
  return { status: "sent", email };
}
