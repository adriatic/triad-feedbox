"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { safeNextPath } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/server";

export type ConfirmState = { status: "idle" } | { status: "error"; message: string };

/**
 * "Finish signing in" (F1 section 4, step 4). Runs only when the person presses
 * the button, never on page load, so a mail scanner that opens the link in
 * advance cannot use up the one-time link.
 */
export async function finishSignIn(_prev: ConfirmState, form: FormData): Promise<ConfirmState> {
  const tokenHash = String(form.get("token_hash") ?? "");
  const type = String(form.get("type") ?? "");
  const next = safeNextPath(String(form.get("next") ?? ""));
  if (!tokenHash || type !== "email") {
    return { status: "error", message: "This sign-in link is incomplete. Ask for a new one." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.verifyOtp({ type: "email", token_hash: tokenHash });
  if (error || !data.user) {
    return {
      status: "error",
      message: "This sign-in link has expired or was already used. Ask for a new one.",
    };
  }
  const { data: profile } = await supabase.from("profiles").select("display_name").eq("id", data.user.id).maybeSingle();
  revalidatePath("/", "layout");
  // First sign-in: the display name is asked once, before anything else (F1 section 4).
  redirect(profile?.display_name ? next : `/welcome?next=${encodeURIComponent(next)}`);
}
