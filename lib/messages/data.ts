import { createClient } from "@/lib/supabase/server";
import { checkMessage, type InboxMessage } from "./core";

/**
 * The messages part (task CT1), on the server: every read and write goes
 * through the Supabase server client with the person's own session, so the
 * database's row-level security and owner functions decide (the browser never
 * calls Supabase). What it needs from the app: a board id, and that the
 * caller is on the server.
 *
 * Database objects (supabase/migrations/20261119120000_messages.sql):
 * - table messages: a signed-in person inserts (board_id, body); the board's owners read;
 * - board_messages(board): the board's messages with each sender's name and sign-in email, owners only;
 * - set_message_read(message, read): owners only.
 */

/** What the database said when it refused (PostgREST error fields). */
interface DbError {
  code?: string | null;
  message?: string | null;
  details?: string | null;
}

export type SendResult = { ok: true } | { ok: false; reason: string };

export const RATE_LIMITED = "You are posting quickly. Try again in a few minutes.";

/** Why sending did not work, in words. */
export function sendRefusal(error: DbError): string {
  if ((error.details ?? "").startsWith("rate_limit:") || error.message === RATE_LIMITED) return RATE_LIMITED;
  return "Sending your message did not work. Reload the page and try again.";
}

/** Send a message to the owners of the board, as the signed-in person. */
export async function sendMessage(boardId: string, raw: string): Promise<SendResult> {
  const checked = checkMessage(raw);
  if (!checked.ok) return { ok: false, reason: checked.reason };
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  if (!data.user) return { ok: false, reason: "Your session has ended. Sign in again to send your message." };
  const { error } = await supabase.from("messages").insert({ board_id: boardId, body: checked.value });
  if (error) return { ok: false, reason: sendRefusal(error) };
  return { ok: true };
}

/**
 * How many of the board's messages are not read yet. Row-level security lets
 * only the board's owners read messages, so for anyone else this is 0. If the
 * table cannot be read (for example in a project where the messages
 * migration has not run yet), the header shows no count, and the reason goes
 * to the server log.
 */
export async function countUnread(boardId: string): Promise<number> {
  const supabase = await createClient();
  const { count, error } = await supabase
    .from("messages")
    .select("id", { count: "exact", head: true })
    .eq("board_id", boardId)
    .is("read_at", null);
  if (error) {
    console.error(`Feedbox: the unread messages could not be counted (${error.code ?? "no code"} ${error.message}).`);
    return 0;
  }
  return count ?? 0;
}

/** The board's messages for its owners, newest first, each with the sender's name and email. */
export async function getInbox(boardId: string): Promise<InboxMessage[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("board_messages", { p_board_id: boardId });
  if (error) throw new Error(`Could not read the messages: ${error.message}`);
  return data.map((m) => ({
    id: m.id,
    body: m.body,
    createdAt: m.created_at,
    read: m.read_at !== null,
    senderName: m.sender_name ?? "Someone",
    senderEmail: m.sender_email,
  }));
}

/** Mark one message read or unread (owners only; the database checks). */
export async function setMessageRead(messageId: number, read: boolean): Promise<SendResult> {
  if (!Number.isSafeInteger(messageId) || messageId <= 0) return { ok: false, reason: "This message no longer exists. Reload the page." };
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_message_read", { p_message_id: messageId, p_read: read });
  if (!error) return { ok: true };
  if (error.code === "42501") return { ok: false, reason: "Only an owner of this board can do this. Reload the page: you may have been signed out." };
  if (error.code === "P0002") return { ok: false, reason: "This message no longer exists. Reload the page." };
  return { ok: false, reason: "That did not work. Reload the page and try again." };
}
