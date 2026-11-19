/**
 * The messages part (task CT1): messages from signed-in people to the owners
 * of one board. This file holds its rules and words. It is pure TypeScript,
 * with no Supabase or Next import, so it is tested in `unit` and can be
 * carried over to another app as it is (docs/ARCHITECTURE.md, "The messages
 * part"). The database (supabase/migrations/20261119120000_messages.sql)
 * enforces the same rules; these are for the screens.
 */

/** A message: plain text, 1 to 2000 characters after trimming (the database's messages_body_check). */
export const MESSAGE_MAX = 2000;

/** At most this many messages per person per hour (the database's rate limit, kind "message"). */
export const MESSAGES_PER_HOUR = 5;

export const MESSAGE_WORDS = {
  footerLink: "Contact the owner",
  pageTitle: "Contact the owner",
  signInLink: "Sign in to contact the owner",
  label: "Your message",
  shownToOwner: "The owner will see your name and the email address you sign in with, so they can answer you.",
  send: "Send message",
  sent: "Your message was sent to the owner.",
  inboxTitle: "Messages",
  none: "No messages yet.",
  unreadMark: "New",
  markRead: "Mark as read",
  markUnread: "Mark as unread",
} as const;

export type MessageCheck = { ok: true; value: string } | { ok: false; reason: string };

/** Length in characters as a person counts them (an emoji counts once), like char_length in the database. */
export function messageLength(text: string): number {
  return [...text].length;
}

/**
 * The text as it is stored: line endings unified, spaces at the end of each
 * line dropped, at most one empty line in a row, and nothing to trim at
 * either end (the database refuses a message that starts or ends with a
 * space, tab or line break).
 */
export function cleanMessage(raw: string): string {
  return raw
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.replace(/[ \t]+$/g, ""))
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** A message ready to send, or why not, in words. */
export function checkMessage(raw: string): MessageCheck {
  const value = cleanMessage(raw);
  const n = messageLength(value);
  if (n === 0) return { ok: false, reason: "Write your message first." };
  if (n > MESSAGE_MAX) return { ok: false, reason: `A message can have at most ${MESSAGE_MAX} characters (now ${n}).` };
  return { ok: true, value };
}

/** The counter under the box, for example "12 / 2000". */
export function messageCounter(text: string): string {
  return `${messageLength(text)} / ${MESSAGE_MAX}`;
}

/** The header link for owners: "Messages", or "Messages (2)" while two are unread. */
export function inboxLabel(unread: number): string {
  return unread > 0 ? `${MESSAGE_WORDS.inboxTitle} (${unread})` : MESSAGE_WORDS.inboxTitle;
}

/** One message as the Messages page shows it (from the database function board_messages). */
export interface InboxMessage {
  id: number;
  body: string;
  createdAt: string;
  read: boolean;
  senderName: string;
  senderEmail: string | null;
}

/** The sentence at the top of the Messages page. */
export function inboxSummary(messages: readonly InboxMessage[]): string {
  if (messages.length === 0) return MESSAGE_WORDS.none;
  const unread = messages.filter((m) => !m.read).length;
  const total = messages.length === 1 ? "1 message" : `${messages.length} messages`;
  return unread === 0 ? `${total}, all read.` : `${total}, ${unread} not read yet.`;
}

/** A mailto: link to answer the sender from the owner's own email program, or null without an address. */
export function replyHref(message: Pick<InboxMessage, "senderEmail">, boardName: string): string | null {
  if (!message.senderEmail) return null;
  return `mailto:${encodeURIComponent(message.senderEmail).replace(/%40/g, "@")}?subject=${encodeURIComponent(`Your message to ${boardName}`)}`;
}
