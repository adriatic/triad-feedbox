"use client";
import Link from "next/link";
import { useActionState, useEffect, useRef } from "react";
import { formatVotes, LIMITS } from "@/lib/feedbox";
import { publishEntry, type PublishState } from "./actions";

interface ReadyIdea {
  id: number;
  title: string;
  voteCount: number;
}

/** Today's date where the owner is, as YYYY-MM-DD. */
function today(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * The changelog editor (F1 section 8): a title and a release date, then the
 * Shipped ideas that are not in any entry yet, all ticked, with one line for
 * each. Laid out like Post an idea (PostIdea.dc.html), since no design exists.
 */
export function ChangelogForm({ ideas, boardName }: { ideas: ReadyIdea[]; boardName: string }) {
  const [state, action, pending] = useActionState<PublishState, FormData>(publishEntry, { status: "idle" });
  const failed = state.status === "error" ? state : null;
  // The release date starts as today where the owner is (the server cannot know the time zone).
  const dateInput = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (dateInput.current && !dateInput.current.value) dateInput.current.value = today();
  });
  return (
    <div className="post-layout">
      <form action={action} className="card post-form" key={failed ? `failed-${failed.message}` : "form"}>
        <div className="field">
          <label htmlFor="entry-title">Title</label>
          <input
            id="entry-title"
            name="title"
            type="text"
            required
            maxLength={LIMITS.changelogTitleMax}
            autoComplete="off"
            placeholder={`For example "${boardName} 2.5"`}
            className="input"
            defaultValue={failed?.title ?? ""}
          />
        </div>
        <div className="field">
          <label htmlFor="entry-date">Release date</label>
          <input
            id="entry-date"
            name="released_on"
            type="date"
            required
            className="input"
            ref={dateInput}
            defaultValue={failed?.releasedOn ?? ""}
          />
        </div>
        <fieldset className="changelog-picks">
          <legend>Shipped ideas not in the changelog yet</legend>
          <span className="hint">Untick an idea to leave it for a later entry. Write one line for each ticked idea.</span>
          {ideas.map((i) => (
            <div key={i.id} className="changelog-pick" data-testid="changelog-pick">
              <input type="hidden" name="offered" value={i.id} />
              <label className="changelog-pick-head">
                <input type="checkbox" name="idea" value={i.id} defaultChecked={failed ? failed.picked.includes(i.id) : true} />
                {i.title}
                <span className="muted" style={{ fontWeight: 400, fontSize: 13 }}>
                  {formatVotes(i.voteCount)}
                </span>
              </label>
              <label htmlFor={`note-${i.id}`} className="sr-only">
                Line for {i.title}
              </label>
              <input
                id={`note-${i.id}`}
                name={`note-${i.id}`}
                type="text"
                maxLength={LIMITS.changelogNoteMax}
                autoComplete="off"
                placeholder="One line: what changed for people"
                className="input"
                defaultValue={failed?.notes[i.id] ?? ""}
              />
            </div>
          ))}
        </fieldset>
        {failed && (
          <p className="alert" role="alert">
            {failed.message}
          </p>
        )}
        <div className="form-actions">
          <button type="submit" className="btn btn-primary" disabled={pending}>
            Publish
          </button>
          <Link href="/changelog" className="cancel-link">
            Cancel
          </Link>
        </div>
      </form>
      <aside aria-label="How the changelog works" className="similar">
        <h2>How the changelog works</h2>
        <p className="muted">
          The entry appears on the changelog page as soon as it is published, newest release first. Each line links back to its idea
          and shows its votes.
        </p>
        <p className="muted">An idea in an entry stays Shipped. Only Shipped ideas can be picked.</p>
      </aside>
    </div>
  );
}
