"use client";
import Link from "next/link";
import { useActionState, useEffect, useRef, useState } from "react";
import {
  formatNumber,
  isSearchable,
  LIMITS,
  searchText,
  SIMILAR_DEBOUNCE_MS,
  similarHeading,
} from "@/lib/feedbox";
import { StatusChip } from "@/components/StatusChip";
import { useVote } from "@/components/useVote";
import type { SimilarIdea as Similar } from "@/lib/supabase/data";
import { findSimilar, postIdea, type PostIdeaState } from "./actions";

/**
 * Post an idea (PostIdea.dc.html): the form, and beside it the similar ideas
 * already on the board, asked from similar_ideas 300 ms after the last
 * keystroke once the title has 3 or more characters (F1 section 5). Each has
 * its own Vote button, so voting for an existing idea is one click.
 * Task F5b: the list is asked through a server action, and Return in Title
 * moves to Details instead of posting, so the similar ideas are seen first.
 */
export function PostIdeaForm() {
  const [state, action, pending] = useActionState<PostIdeaState, FormData>(postIdea, { status: "idle" });
  const [title, setTitle] = useState(state.status === "error" ? state.title : "");
  const [similar, setSimilar] = useState<Similar[]>([]);
  const [searchedFor, setSearchedFor] = useState("");
  const [lookupError, setLookupError] = useState<string | null>(null);
  const details = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    const text = searchText(title);
    if (!isSearchable(text)) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      let result;
      try {
        result = await findSimilar(text);
      } catch {
        result = { ok: false as const, query: text, message: "Feedbox could not be reached. Check the connection and try again." };
      }
      if (cancelled) return;
      if (!result.ok) {
        setSimilar([]);
        setLookupError(result.message);
        return;
      }
      setLookupError(null);
      setSimilar(result.ideas);
      setSearchedFor(result.query);
    }, SIMILAR_DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [title]);

  // Fewer than 3 characters: no list (what was found for an earlier title is not shown).
  const shown = isSearchable(title) ? similar : [];
  return (
    <div className="post-layout">
      <form action={action} className="card post-form">
        <div className="field">
          <label htmlFor="idea-title">Title</label>
          <input
            id="idea-title"
            name="title"
            type="text"
            required
            minLength={LIMITS.titleMin}
            maxLength={LIMITS.titleMax}
            autoComplete="off"
            placeholder="A short name for your idea"
            className="input"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            onKeyDown={(e) => {
              // Return in Title does not post (task F5b): it moves on to Details.
              if (e.key === "Enter" && !e.nativeEvent.isComposing) {
                e.preventDefault();
                details.current?.focus();
              }
            }}
          />
          <span className="hint">Check the ideas on the right first. Voting on an existing idea helps it more than a duplicate.</span>
        </div>
        <div className="field">
          <label htmlFor="idea-body">Details</label>
          <textarea
            id="idea-body"
            name="body"
            ref={details}
            rows={6}
            maxLength={LIMITS.bodyMax}
            placeholder="What are you trying to do, and what gets in the way?"
            className="textarea"
            defaultValue={state.status === "error" ? state.body : ""}
          />
        </div>
        {state.status === "error" && (
          <p className="alert" role="alert">
            {state.message}
          </p>
        )}
        <div className="form-actions">
          <button type="submit" className="btn btn-primary" disabled={pending}>
            Post idea
          </button>
          <Link href="/" className="cancel-link">
            Cancel
          </Link>
        </div>
      </form>
      <aside aria-label="Similar ideas" className="similar" aria-live="polite">
        <h2>{similarHeading(shown.length ? searchedFor : searchText(title), shown.length)}</h2>
        {lookupError && isSearchable(title) && (
          <p className="alert" role="alert">
            {lookupError}
          </p>
        )}
        {shown.length > 0 && (
          <ul className="similar-list" data-testid="similar-list">
            {shown.map((s) => (
              <SimilarIdea key={`${searchedFor}-${s.id}`} idea={s} />
            ))}
          </ul>
        )}
      </aside>
    </div>
  );
}

function SimilarIdea({ idea }: { idea: Similar }) {
  const { shown, pending, error, toggle } = useVote(idea.id, { voted: idea.voted, count: idea.voteCount });
  return (
    <li className="card similar-item" data-testid="similar-idea">
      <div className="similar-count">
        <span data-testid="vote-count">{formatNumber(shown.count)}</span>
        <small>{shown.count === 1 ? "vote" : "votes"}</small>
      </div>
      <div className="similar-main">
        <Link href={`/ideas/${idea.id}`} className="similar-title">
          {idea.title}
        </Link>
        <StatusChip status={idea.status} small />
        {error && (
          <p className="alert" role="alert">
            {error}
          </p>
        )}
      </div>
      <button
        type="button"
        className="similar-vote"
        aria-pressed={shown.voted}
        aria-busy={pending}
        aria-label={shown.voted ? `Remove your vote from ${idea.title}` : `Vote for ${idea.title}`}
        onClick={toggle}
      >
        {shown.voted ? "Voted" : "Vote"}
      </button>
    </li>
  );
}
