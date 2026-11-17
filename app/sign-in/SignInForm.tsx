"use client";
import { useActionState } from "react";
import { sendLink, type SendLinkState } from "./actions";

export function SignInForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<SendLinkState, FormData>(sendLink, { status: "idle" });

  if (state.status === "sent") {
    return (
      <>
        <h1>Check your email</h1>
        <p data-testid="link-sent">
          We sent a sign-in link to <strong>{state.email}</strong>. It works once and expires in 15 minutes.
        </p>
      </>
    );
  }
  return (
    <>
      <h1>Sign in</h1>
      <p>We will email you a link. No password needed.</p>
      <form action={action}>
        <input type="hidden" name="next" value={next} />
        <p>
          <label>
            Email <input type="email" name="email" required autoComplete="email" />
          </label>
        </p>
        {state.status === "error" && <p role="alert">{state.message}</p>}
        <p>
          <button type="submit" disabled={pending}>
            Send me a link
          </button>
        </p>
      </form>
    </>
  );
}
