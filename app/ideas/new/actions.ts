"use server";
import { redirect } from "next/navigation";
import { refusalMessage, validateBody, validateTitle } from "@/lib/feedbox";
import { getBoard, getSimilarIdeas, getViewer, type SimilarIdea } from "@/lib/supabase/data";
import { createClient } from "@/lib/supabase/server";

export type PostIdeaState = { status: "idle" } | { status: "error"; message: string; title: string; body: string };

/**
 * "Post idea" (PostIdea.dc.html). The title and details are checked here with
 * the core library and again by the database. Posting also casts the author's
 * vote (a database trigger). The rate limit (5 ideas an hour) is a database
 * trigger; its refusal is shown in words (F1 section 6).
 */
export async function postIdea(_prev: PostIdeaState, form: FormData): Promise<PostIdeaState> {
  const rawTitle = String(form.get("title") ?? "");
  const rawBody = String(form.get("body") ?? "");
  const back = (message: string): PostIdeaState => ({ status: "error", message, title: rawTitle, body: rawBody });
  const title = validateTitle(rawTitle);
  if (!title.ok) return back(title.reason);
  const body = validateBody(rawBody);
  if (!body.ok) return back(body.reason);

  const board = await getBoard();
  if (!board) return back("This board does not exist.");
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return back("Your session has ended. Sign in again to post.");
  const { data, error } = await supabase
    .from("ideas")
    .insert({ board_id: board.id, title: title.value, body: body.value })
    .select("id")
    .single();
  if (error) return back(refusalMessage(error, "Posting your idea"));
  redirect(`/ideas/${data.id}`);
}

export type SimilarState = { ok: true; query: string; ideas: SimilarIdea[] } | { ok: false; query: string; message: string };

/**
 * The similar ideas beside the form (F1 section 5), asked 300 ms after the
 * last keystroke. Task F5b: asked on the server, like the board's search box,
 * and a failure is shown in words instead of an empty list.
 */
export async function findSimilar(query: string): Promise<SimilarState> {
  try {
    const board = await getBoard();
    if (!board) return { ok: false, query, message: "This board does not exist." };
    const viewer = await getViewer(board.id);
    return { ok: true, query, ideas: await getSimilarIdeas(board.id, viewer, query) };
  } catch (e) {
    console.error(e);
    return { ok: false, query, message: "Similar ideas could not be loaded just now. Check the ideas on the board before posting." };
  }
}
