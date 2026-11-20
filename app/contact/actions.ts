"use server";
import { getBoard } from "@/lib/supabase/data";
import { sendMessage } from "@/lib/messages/data";

export type ContactState = { status: "idle" } | { status: "sent"; at: number } | { status: "error"; message: string; body: string };

/**
 * "Send message" on /contact (task CT1). The database decides who may send
 * (a signed-in person with a display name, as themselves) and refuses a sixth
 * message in an hour; every refusal is shown in words.
 */
export async function sendToOwner(_prev: ContactState, form: FormData): Promise<ContactState> {
  const raw = String(form.get("body") ?? "");
  const board = await getBoard();
  if (!board) return { status: "error", message: "This board does not exist.", body: raw };
  const result = await sendMessage(board.id, raw);
  if (!result.ok) return { status: "error", message: result.reason, body: raw };
  return { status: "sent", at: Date.now() };
}
