"use client";
import { useActionState } from "react";
import { saveDisplayName, type WelcomeState } from "./actions";

export function WelcomeForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<WelcomeState, FormData>(saveDisplayName, { status: "idle" });
  return (
    <form action={action}>
      <input type="hidden" name="next" value={next} />
      <p>
        <label>
          Name shown with your ideas{" "}
          <input name="display_name" required minLength={2} maxLength={40} placeholder="Mira K." autoComplete="name" />
        </label>
      </p>
      <p>2 to 40 characters. Your email address is never shown.</p>
      {state.status === "error" && <p role="alert">{state.message}</p>}
      <p>
        <button type="submit" disabled={pending}>
          Continue
        </button>
      </p>
    </form>
  );
}
