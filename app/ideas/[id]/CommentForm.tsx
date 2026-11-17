"use client";
import { useActionState } from "react";
import { LIMITS } from "@/lib/feedbox";
import { addComment, type CommentState } from "./actions";

/** The comment box for a signed-in person (Idea.dc.html). */
export function CommentForm({ ideaId }: { ideaId: number }) {
  const [state, action, pending] = useActionState<CommentState, FormData>(addComment, { status: "idle" });
  // After a successful post the form is drawn again (key), so the box is empty.
  const key = state.status === "posted" ? `posted-${state.at}` : "form";
  return (
    <form key={key} action={action} className="comment-form">
      <input type="hidden" name="idea_id" value={ideaId} />
      <label htmlFor="comment-body" className="label">
        Add a comment
      </label>
      <textarea
        id="comment-body"
        name="body"
        rows={3}
        required
        maxLength={LIMITS.commentMax}
        placeholder="What would help here?"
        className="textarea"
        defaultValue={state.status === "error" ? state.body : ""}
      />
      {state.status === "error" && (
        <p className="alert" role="alert">
          {state.message}
        </p>
      )}
      <div>
        <button type="submit" className="btn btn-primary" disabled={pending}>
          Post comment
        </button>
      </div>
    </form>
  );
}
