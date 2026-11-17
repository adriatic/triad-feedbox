"use client";
import { useActionState } from "react";
import { saveDisplayName, type WelcomeState } from "./actions";

export function WelcomeForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<WelcomeState, FormData>(saveDisplayName, { status: "idle" });
  return (
    <form action={action}>
      <input type="hidden" name="next" value={next} />
      <div className="field">
        <label htmlFor="display-name">Name shown with your ideas</label>
        <input
          id="display-name"
          name="display_name"
          required
          minLength={2}
          maxLength={40}
          placeholder="Mira K."
          autoComplete="name"
          className="input"
        />
        <span className="hint">2 to 40 characters. Your email address is never shown.</span>
      </div>
      {state.status === "error" && (
        <p className="alert" role="alert">
          {state.message}
        </p>
      )}
      <button type="submit" className="btn btn-primary" disabled={pending}>
        Continue
      </button>
    </form>
  );
}
