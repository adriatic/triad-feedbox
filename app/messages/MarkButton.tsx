"use client";
import { useActionState } from "react";
import { MESSAGE_WORDS } from "@/lib/messages/core";
import { markMessage, type MarkState } from "./actions";

/** Mark as read, or Mark as unread, for one message (owners only, task CT1). */
export function MarkButton({ messageId, read }: { messageId: number; read: boolean }) {
  const [state, action, pending] = useActionState<MarkState, FormData>(markMessage, { status: "idle" });
  return (
    <form action={action} className="message-tool">
      <input type="hidden" name="message_id" value={messageId} />
      <input type="hidden" name="read" value={read ? "0" : "1"} />
      <button type="submit" className="btn btn-small" disabled={pending}>
        {read ? MESSAGE_WORDS.markUnread : MESSAGE_WORDS.markRead}
      </button>
      {state.status === "error" && (
        <span className="alert" role="alert">
          {state.message}
        </span>
      )}
    </form>
  );
}
