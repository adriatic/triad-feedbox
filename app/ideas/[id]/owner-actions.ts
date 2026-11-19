"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { ownerRefusalMessage, parseStatus, statusLabel } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/server";

/**
 * The owner tools on Idea detail (Idea.dc.html, task F6; F1 sections 3, 5, 6).
 * Every tool is a server action that calls one owner function in the
 * database (set_idea_status, merge_ideas, undo_merge, hide_idea, unhide_idea,
 * hide_comment, unhide_comment) with the person's own session. The database
 * checks that the person owns the board and refuses anything else; the
 * browser never calls Supabase itself.
 */
export type OwnerState = { status: "idle" } | { status: "done"; message: string; at: number } | { status: "error"; message: string };

const id = (form: FormData, name: string): number | null => {
  const n = Number(form.get(name));
  return Number.isSafeInteger(n) && n > 0 ? n : null;
};

async function signedIn() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  return data.user ? supabase : null;
}

const ENDED: OwnerState = { status: "error", message: "Your session has ended. Sign in again." };

function refreshIdea(ideaId: number) {
  revalidatePath(`/ideas/${ideaId}`);
  revalidatePath("/");
}

/** Status: Open, Planned, Building or Shipped (lib/feedbox checkStatusChange; the database decides). */
export async function changeStatus(_prev: OwnerState, form: FormData): Promise<OwnerState> {
  const ideaId = id(form, "idea_id");
  const status = parseStatus(String(form.get("status") ?? ""));
  if (!ideaId || !status) return { status: "error", message: "Pick a status." };
  const supabase = await signedIn();
  if (!supabase) return ENDED;
  const { error } = await supabase.rpc("set_idea_status", { p_idea_id: ideaId, p_status: status });
  if (error) return { status: "error", message: ownerRefusalMessage(error, "Changing the status") };
  refreshIdea(ideaId);
  return { status: "done", message: `The status is now ${statusLabel(status)}.`, at: Date.now() };
}

/**
 * Merge this idea into another (F1 section 5). Afterwards the person lands on
 * the target, whose page says what was merged into it and offers Undo merge
 * (task F6a).
 */
export async function mergeInto(_prev: OwnerState, form: FormData): Promise<OwnerState> {
  const sourceId = id(form, "idea_id");
  const targetId = id(form, "target_id");
  if (!sourceId) return { status: "error", message: "This idea does not exist." };
  if (!targetId) return { status: "error", message: "Pick the idea to merge into." };
  if (sourceId === targetId) return { status: "error", message: "An idea cannot be merged into itself." };
  const supabase = await signedIn();
  if (!supabase) return ENDED;
  const { error } = await supabase.rpc("merge_ideas", { p_source_id: sourceId, p_target_id: targetId });
  if (error) return { status: "error", message: ownerRefusalMessage(error, "Merging") };
  refreshIdea(sourceId);
  refreshIdea(targetId);
  redirect(`/ideas/${targetId}?merged=${sourceId}`);
}

/** Hide or unhide the idea (F1 section 6): hidden ideas are seen by owners only, marked "Hidden". */
export async function setIdeaHidden(_prev: OwnerState, form: FormData): Promise<OwnerState> {
  const ideaId = id(form, "idea_id");
  const hide = form.get("hide") === "1";
  if (!ideaId) return { status: "error", message: "This idea does not exist." };
  const supabase = await signedIn();
  if (!supabase) return ENDED;
  const { error } = hide
    ? await supabase.rpc("hide_idea", { p_idea_id: ideaId })
    : await supabase.rpc("unhide_idea", { p_idea_id: ideaId });
  if (error) return { status: "error", message: ownerRefusalMessage(error, hide ? "Hiding the idea" : "Unhiding the idea") };
  refreshIdea(ideaId);
  return {
    status: "done",
    message: hide ? "The idea is hidden. Only owners see it now." : "The idea is visible to everyone again.",
    at: Date.now(),
  };
}

/** Hide or unhide one comment (F1 section 6). */
export async function setCommentHidden(_prev: OwnerState, form: FormData): Promise<OwnerState> {
  const ideaId = id(form, "idea_id");
  const commentId = id(form, "comment_id");
  const hide = form.get("hide") === "1";
  if (!ideaId || !commentId) return { status: "error", message: "This comment does not exist." };
  const supabase = await signedIn();
  if (!supabase) return ENDED;
  const { error } = hide
    ? await supabase.rpc("hide_comment", { p_comment_id: commentId })
    : await supabase.rpc("unhide_comment", { p_comment_id: commentId });
  if (error) return { status: "error", message: ownerRefusalMessage(error, hide ? "Hiding the comment" : "Unhiding the comment") };
  refreshIdea(ideaId);
  return { status: "done", message: hide ? "The comment is hidden." : "The comment is visible again.", at: Date.now() };
}

/**
 * Undo one merge (task F6a): undo_merge puts the merged idea back on the board
 * with its votes and comments. Afterwards the person stays on the target's
 * page, which says what came back, with a link to it.
 */
export async function undoMerge(_prev: OwnerState, form: FormData): Promise<OwnerState> {
  const mergeId = id(form, "merge_id");
  const targetId = id(form, "idea_id");
  const sourceId = id(form, "source_id");
  if (!mergeId || !targetId || !sourceId) return { status: "error", message: "This merge does not exist. Reload the page." };
  const supabase = await signedIn();
  if (!supabase) return ENDED;
  const { error } = await supabase.rpc("undo_merge", { p_merge_id: mergeId });
  if (error) return { status: "error", message: ownerRefusalMessage(error, "Undoing the merge") };
  refreshIdea(sourceId);
  refreshIdea(targetId);
  redirect(`/ideas/${targetId}?unmerged=${sourceId}`);
}
