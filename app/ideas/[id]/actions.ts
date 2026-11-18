"use server";
import { revalidatePath } from "next/cache";
import { refusalMessage, validateComment } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/server";

export type CommentState = { status: "idle" } | { status: "posted"; at: number } | { status: "error"; message: string; body: string };

/**
 * "Post comment" (Idea.dc.html; F1 section 7: plain text, flat, newest last).
 * Row-level security decides who may comment; the rate limit (30 an hour) is a
 * database trigger, and its refusal is shown in words (F1 section 6).
 */
export async function addComment(_prev: CommentState, form: FormData): Promise<CommentState> {
  const ideaId = Number(form.get("idea_id"));
  const raw = String(form.get("body") ?? "");
  if (!Number.isSafeInteger(ideaId) || ideaId < 1) return { status: "error", message: "This idea does not exist.", body: raw };
  const checked = validateComment(raw);
  if (!checked.ok) return { status: "error", message: checked.reason, body: raw };

  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  if (!data.user) return { status: "error", message: "Your session has ended. Sign in again to comment.", body: raw };
  const { error } = await supabase.from("comments").insert({ idea_id: ideaId, body: checked.value });
  if (error) return { status: "error", message: refusalMessage(error, "Posting your comment"), body: raw };
  revalidatePath(`/ideas/${ideaId}`);
  return { status: "posted", at: Date.now() };
}
