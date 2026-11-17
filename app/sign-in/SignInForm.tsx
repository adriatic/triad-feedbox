"use client";
import Link from "next/link";
import { useActionState, useState } from "react";
import { sendLink, type SendLinkState } from "./actions";

/** Sign in by email link (SignIn.dc.html): the form, then "Check your email". */
export function SignInForm({ next }: { next: string }) {
  const [state, action, pending] = useActionState<SendLinkState, FormData>(sendLink, { status: "idle" });
  // "Use a different email address" goes back to the form without a reload.
  const [againAfter, setAgainAfter] = useState<SendLinkState | null>(null);

  if (state.status === "sent" && againAfter !== state) {
    return (
      <>
        <h1>Check your email</h1>
        <p data-testid="link-sent">
          We sent a sign-in link to <strong>{state.email}</strong>. Open it on this device to finish signing in. The link
          works once and expires in 15 minutes.
        </p>
        <p className="muted">Nothing there? Look in your junk folder, then ask for a new link.</p>
        <button type="button" className="btn" onClick={() => setAgainAfter(state)}>
          Use a different email address
        </button>
      </>
    );
  }
  return (
    <>
      <h1>Sign in to vote and post</h1>
      <p className="muted">Enter your email address. We send you a link that signs you in. There is no password.</p>
      <form action={action}>
        <input type="hidden" name="next" value={next} />
        <div className="field">
          <label htmlFor="email">Email address</label>
          <input id="email" type="email" name="email" required autoComplete="email" placeholder="you@example.com" className="input" />
        </div>
        {state.status === "error" && (
          <p className="alert" role="alert">
            {state.message}
          </p>
        )}
        <button type="submit" className="btn btn-primary" disabled={pending}>
          Send me a link
        </button>
      </form>
      <Link href={next} className="center-link">
        Keep browsing without signing in
      </Link>
    </>
  );
}
