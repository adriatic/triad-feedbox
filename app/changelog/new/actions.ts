"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  checkChangelogPicks,
  ownerRefusalMessage,
  validateChangelogNote,
  validateChangelogTitle,
  validateReleaseDate,
} from "@/lib/feedbox";
import { getBoard, getChangelog, getIdeas } from "@/lib/supabase/data";
import { createClient } from "@/lib/supabase/server";

export type PublishState =
  | { status: "idle" }
  | { status: "error"; message: string; title: string; releasedOn: string; picked: number[]; notes: Record<number, string> };

/**
 * Publish a changelog entry (F1 section 8, task F6): a title, a release date
 * and one line for each Shipped idea that is ticked. The entry and its lines
 * are written with the owner's own session (row-level security lets only the
 * board's owners write them), then published with publish_changelog_entry.
 * Those are three separate requests, so if a later one fails, the entry
 * written by this attempt is deleted again and nothing half-made stays.
 */
export async function publishEntry(_prev: PublishState, form: FormData): Promise<PublishState> {
  const rawTitle = String(form.get("title") ?? "");
  const rawDate = String(form.get("released_on") ?? "");
  const offered = form.getAll("offered").map(Number).filter((n) => Number.isSafeInteger(n) && n > 0);
  const picked = form.getAll("idea").map(Number).filter((n) => offered.includes(n));
  const notes: Record<number, string> = {};
  for (const id of offered) notes[id] = String(form.get(`note-${id}`) ?? "");
  const back = (message: string): PublishState => ({ status: "error", message, title: rawTitle, releasedOn: rawDate, picked, notes });

  const title = validateChangelogTitle(rawTitle);
  if (!title.ok) return back(title.reason);
  const date = validateReleaseDate(rawDate);
  if (!date.ok) return back(date.reason);
  const lines: { idea_id: number; note: string; position: number }[] = [];
  for (const [position, ideaId] of picked.entries()) {
    const note = validateChangelogNote(notes[ideaId] ?? "");
    if (!note.ok) return back(`Every ticked idea needs its line. ${note.reason}`);
    lines.push({ idea_id: ideaId, note: note.value, position });
  }

  const board = await getBoard();
  if (!board) return back("This board does not exist.");
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return back("Your session has ended. Sign in again.");
  const [ideas, { items }] = await Promise.all([getIdeas(board.id), getChangelog(board.id)]);
  const picks = checkChangelogPicks(board.id, picked, ideas, items);
  if (!picks.ok) return back(picks.reason);

  const { data: entry, error: entryError } = await supabase
    .from("changelog_entries")
    .insert({ board_id: board.id, title: title.value, released_on: date.value })
    .select("id")
    .single();
  if (entryError) return back(ownerRefusalMessage(entryError, "Saving the entry"));
  const undo = async () => {
    await supabase.from("changelog_entries").delete().eq("id", entry.id);
  };
  const { error: linesError } = await supabase.from("changelog_items").insert(lines.map((l) => ({ ...l, entry_id: entry.id })));
  if (linesError) {
    await undo();
    return back(ownerRefusalMessage(linesError, "Saving the lines"));
  }
  const { error: publishError } = await supabase.rpc("publish_changelog_entry", { p_entry_id: entry.id, p_publish: true });
  if (publishError) {
    await undo();
    return back(ownerRefusalMessage(publishError, "Publishing"));
  }
  revalidatePath("/changelog");
  redirect("/changelog");
}
