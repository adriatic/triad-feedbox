"use server";
import { redirect } from "next/navigation";
import { refusalMessage, validateBody, validateTitle } from "@/lib/feedbox";
import { getBoard } from "@/lib/supabase/data";
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
