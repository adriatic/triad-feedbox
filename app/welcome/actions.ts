"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { safeNextPath, validateDisplayName } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/server";

export type WelcomeState = { status: "idle" } | { status: "error"; message: string };

/** Saves the display name, asked once on first sign-in (F1 section 4, decision D6). */
export async function saveDisplayName(_prev: WelcomeState, form: FormData): Promise<WelcomeState> {
  const next = safeNextPath(String(form.get("next") ?? ""));
  const checked = validateDisplayName(String(form.get("display_name") ?? ""));
  if (!checked.ok) return { status: "error", message: checked.reason };

  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  if (!data.user) redirect(`/sign-in?next=${encodeURIComponent(next)}`);
  const { error } = await supabase.from("profiles").update({ display_name: checked.value }).eq("id", data.user.id);
  if (error) return { status: "error", message: `The name could not be saved: ${error.message}` };
  revalidatePath("/", "layout");
  redirect(next);
}
