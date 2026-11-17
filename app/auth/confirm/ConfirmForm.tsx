"use client";
import Link from "next/link";
import { useActionState } from "react";
import { finishSignIn, type ConfirmState } from "./actions";

export function ConfirmForm({ tokenHash, type, next }: { tokenHash: string; type: string; next: string }) {
  const [state, action, pending] = useActionState<ConfirmState, FormData>(finishSignIn, { status: "idle" });
  return (
    <>
      <h1>Finish signing in</h1>
      {state.status === "error" ? (
        <>
          <p role="alert">{state.message}</p>
          <p>
            <Link href={`/sign-in?next=${encodeURIComponent(next)}`}>Ask for a new link</Link>
          </p>
        </>
      ) : (
        <form action={action}>
          <input type="hidden" name="token_hash" value={tokenHash} />
          <input type="hidden" name="type" value={type} />
          <input type="hidden" name="next" value={next} />
          <p>Press the button to finish signing in on this device.</p>
          <p>
            <button type="submit" disabled={pending}>
              Finish signing in
            </button>
          </p>
        </form>
      )}
    </>
  );
}
