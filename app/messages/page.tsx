import { redirect } from "next/navigation";
import { LocalDate } from "@/components/LocalDate";
import { inboxSummary, MESSAGE_WORDS, replyHref } from "@/lib/messages/core";
import { getInbox } from "@/lib/messages/data";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { MarkButton } from "./MarkButton";

// Messages (task CT1): what people sent with Contact the owner, for the
// board's owners only. Anyone else is sent to the board. Each message shows
// the sender's name and the email address they sign in with (read through the
// owner function board_messages), so the owner can answer from their own email.
export default async function MessagesPage() {
  const board = await getBoard();
  if (!board) redirect("/");
  const viewer = await getViewer(board.id);
  if (viewer.role !== "owner") redirect("/");
  const messages = await getInbox(board.id);
  return (
    <main className="page page-narrow-top">
      <h1 className="page-title">{MESSAGE_WORDS.inboxTitle}</h1>
      <p className="muted" data-testid="inbox-summary">
        {inboxSummary(messages)}
        {messages.length > 0 && " To answer, write from your own email to the address next to the sender's name."}
      </p>
      {messages.length > 0 && (
        <ol className="message-list">
          {messages.map((m) => {
            const reply = replyHref(m, board.name);
            return (
              <li key={m.id} className={m.read ? "card message" : "card message message-unread"} data-testid="message">
                <div className="message-head">
                  <span className="message-from">
                    <strong>{m.senderName}</strong>
                    {reply ? (
                      <a href={reply} className="message-email">
                        {m.senderEmail}
                      </a>
                    ) : (
                      <span className="message-email muted">no email address</span>
                    )}
                  </span>
                  <span className="message-meta">
                    {!m.read && <span className="chip chip-small chip-new">{MESSAGE_WORDS.unreadMark}</span>}
                    <span className="muted">
                      <LocalDate value={m.createdAt} />
                    </span>
                  </span>
                </div>
                <p className="message-body">{m.body}</p>
                <MarkButton messageId={m.id} read={m.read} />
              </li>
            );
          })}
        </ol>
      )}
    </main>
  );
}
