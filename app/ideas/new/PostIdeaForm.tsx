"use client";
import Link from "next/link";
import { useActionState, useEffect, useState } from "react";
import {
  formatNumber,
  isSearchable,
  LIMITS,
  searchText,
  SIMILAR_DEBOUNCE_MS,
  SIMILAR_LIMIT,
  similarHeading,
  type IdeaStatus,
} from "@/lib/feedbox";
import { StatusChip } from "@/components/StatusChip";
import { useVote } from "@/components/useVote";
import { createClient } from "@/lib/supabase/browser";
import { postIdea, type PostIdeaState } from "./actions";

interface Similar {
  id: number;
  title: string;
  status: IdeaStatus;
  voteCount: number;
  voted: boolean;
}

/**
 * Post an idea (PostIdea.dc.html): the form, and beside it the similar ideas
 * already on the board, asked from similar_ideas 300 ms after the last
 * keystroke once the title has 3 or more characters (F1 section 5). Each has
 * its own Vote button, so voting for an existing idea is one click.
 */
export function PostIdeaForm({ boardId }: { boardId: string }) {
  const [state, action, pending] = useActionState<PostIdeaState, FormData>(postIdea, { status: "idle" });
  const [title, setTitle] = useState(state.status === "error" ? state.title : "");
  const [similar, setSimilar] = useState<Similar[]>([]);
  const [searchedFor, setSearchedFor] = useState("");

  useEffect(() => {
    const text = searchText(title);
    if (!isSearchable(text)) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      const supabase = createClient();
      const { data, error } = await supabase.rpc("similar_ideas", { p_board_id: boardId, p_query: text, p_limit: SIMILAR_LIMIT });
      if (cancelled || error) return;
      const ids = data.map((r) => r.id);
      const { data: auth } = await supabase.auth.getUser();
      const mine =
        auth.user && ids.length
          ? ((await supabase.from("votes").select("idea_id").eq("user_id", auth.user.id).in("idea_id", ids)).data ?? [])
          : [];
      if (cancelled) return;
      const voted = new Set(mine.map((v) => v.idea_id));
      setSimilar(data.map((r) => ({ id: r.id, title: r.title, status: r.status, voteCount: r.vote_count, voted: voted.has(r.id) })));
      setSearchedFor(text);
    }, SIMILAR_DEBOUNCE_MS);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [title, boardId]);

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
          />
          <span className="hint">Check the ideas on the right first. Voting on an existing idea helps it more than a duplicate.</span>
        </div>
        <div className="field">
          <label htmlFor="idea-body">Details</label>
          <textarea
            id="idea-body"
            name="body"
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
