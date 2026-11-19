"use client";
import { useActionState, useState } from "react";
import { MESSAGE_MAX, MESSAGE_WORDS, messageCounter, messageLength } from "@/lib/messages/core";
import { sendToOwner, type ContactState } from "./actions";

/** The message box on /contact, for a signed-in person (task CT1). */
export function ContactForm() {
  const [state, action, pending] = useActionState<ContactState, FormData>(sendToOwner, { status: "idle" });
  // After sending, the form is drawn again (key), so the box is empty.
  const key = state.status === "sent" ? `sent-${state.at}` : "form";
  return <MessageBox key={key} state={state} action={action} pending={pending} />;
}

function MessageBox({ state, action, pending }: { state: ContactState; action: (form: FormData) => void; pending: boolean }) {
  const [text, setText] = useState(state.status === "error" ? state.body : "");
  const over = messageLength(text) > MESSAGE_MAX;
  return (
    <form action={action} className="card contact-form">
      <label htmlFor="message-body" className="label">
        {MESSAGE_WORDS.label}
      </label>
      <textarea
        id="message-body"
        name="body"
        rows={6}
        required
        maxLength={MESSAGE_MAX}
        className="textarea"
        value={text}
        onChange={(e) => setText(e.target.value)}
        aria-describedby="message-counter message-shown"
      />
      <span id="message-counter" className={over ? "hint counter counter-over" : "hint counter"} aria-live="polite" data-testid="message-counter">
        {messageCounter(text)}
      </span>
      {state.status === "sent" && (
        <p className="notice" role="status">
          {MESSAGE_WORDS.sent}
        </p>
      )}
      {state.status === "error" && (
        <p className="alert" role="alert">
          {state.message}
        </p>
      )}
      <p id="message-shown" className="muted contact-shown">
        {MESSAGE_WORDS.shownToOwner}
      </p>
      <div>
        <button type="submit" className="btn btn-primary" disabled={pending}>
          {MESSAGE_WORDS.send}
        </button>
      </div>
    </form>
  );
}
