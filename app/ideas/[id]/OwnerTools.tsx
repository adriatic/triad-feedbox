"use client";
import { useActionState, useId, useState } from "react";
import { formatComments, formatNumber, formatVotes, mergePreview, STATUSES, statusLabel, type IdeaStatus } from "@/lib/feedbox";
import { changeStatus, mergeInto, setCommentHidden, setIdeaHidden, undoMerge, type OwnerState } from "./owner-actions";

export interface MergeTarget {
  id: number;
  title: string;
  voteCount: number;
}

interface Props {
  idea: { id: number; title: string; status: IdeaStatus; voteCount: number; commentCount: number; hidden: boolean };
  /** The idea is a line in a changelog entry, so it stays Shipped and cannot be merged. */
  inChangelog: boolean;
  targets: MergeTarget[];
}

const IDLE: OwnerState = { status: "idle" };

function Outcome({ state }: { state: OwnerState }) {
  if (state.status === "error") {
    return (
      <p className="alert" role="alert">
        {state.message}
      </p>
    );
  }
  if (state.status === "done") {
    return (
      <p className="owner-done" role="status">
        {state.message}
      </p>
    );
  }
  return null;
}

/**
 * The Owner tools box of Idea.dc.html (task F6), shown to owners only:
 * status, merge into another idea, hide or unhide the idea.
 */
export function OwnerTools({ idea, inChangelog, targets }: Props) {
  const [statusState, statusAction, statusPending] = useActionState(changeStatus, IDLE);
  const [hideState, hideAction, hidePending] = useActionState(setIdeaHidden, IDLE);
  const [mergeOpen, setMergeOpen] = useState(false);
  const statusId = useId();
  return (
    <section aria-label="Owner tools" className="owner-tools" data-testid="owner-tools">
      <div className="owner-tools-row">
        <span className="owner-tools-title">Owner tools</span>
        <form action={statusAction} className="owner-status">
          <input type="hidden" name="idea_id" value={idea.id} />
          <label htmlFor={statusId}>Status</label>
          <select id={statusId} name="status" defaultValue={idea.status} className="select" disabled={inChangelog} key={idea.status}>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {statusLabel(s)}
              </option>
            ))}
          </select>
          <button type="submit" className="btn" disabled={statusPending || inChangelog}>
            Change status
          </button>
        </form>
        <button
          type="button"
          className="btn"
          aria-expanded={mergeOpen}
          aria-controls="merge-panel"
          onClick={() => setMergeOpen((o) => !o)}
          disabled={inChangelog}
        >
          Merge into another idea
        </button>
        <form action={hideAction}>
          <input type="hidden" name="idea_id" value={idea.id} />
          <input type="hidden" name="hide" value={idea.hidden ? "0" : "1"} />
          <button type="submit" className="btn" disabled={hidePending}>
            {idea.hidden ? "Unhide idea" : "Hide idea"}
          </button>
        </form>
      </div>
      {inChangelog && (
        <p className="hint">This idea is in a changelog entry, so it stays Shipped and cannot be merged.</p>
      )}
      <Outcome state={statusState} />
      <Outcome state={hideState} />
      {mergeOpen && !inChangelog && <MergePanel idea={idea} targets={targets} onCancel={() => setMergeOpen(false)} />}
    </section>
  );
}

function MergePanel({ idea, targets, onCancel }: { idea: Props["idea"]; targets: MergeTarget[]; onCancel: () => void }) {
  const [state, action, pending] = useActionState(mergeInto, IDLE);
  const [targetId, setTargetId] = useState<number | null>(null);
  const target = targets.find((t) => t.id === targetId) ?? null;
  const preview = target ? mergePreview(idea, target) : null;
  const pickId = useId();
  return (
    <form action={action} id="merge-panel" className="merge-panel" aria-label="Merge into another idea">
      <input type="hidden" name="idea_id" value={idea.id} />
      <div className="field">
        <label htmlFor={pickId}>Merge &ldquo;{idea.title}&rdquo; into</label>
        <select
          id={pickId}
          name="target_id"
          className="select"
          required
          value={targetId ?? ""}
          onChange={(e) => setTargetId(e.target.value ? Number(e.target.value) : null)}
        >
          <option value="">Pick an idea</option>
          {targets.map((t) => (
            <option key={t.id} value={t.id}>
              {t.title} ({formatVotes(t.voteCount)})
            </option>
          ))}
        </select>
      </div>
      {target && preview && (
        <div className="merge-preview" data-testid="merge-preview">
          <p className="label">What will happen</p>
          <ul>
            <li>
              Votes: everyone behind the {formatVotes(idea.voteCount)} on &ldquo;{idea.title}&rdquo; gets a vote on &ldquo;{target.title}&rdquo;,
              unless they already voted for it, so nobody is counted twice. &ldquo;{target.title}&rdquo; goes from{" "}
              {formatVotes(target.voteCount)} to between {formatNumber(preview.votesAtLeast)} and {formatNumber(preview.votesAtMost)} votes.
            </li>
            <li>
              Comments: {preview.commentsMoved === 0 ? "there are none to move." : `${formatComments(preview.commentsMoved)} move to “${target.title}”, marked with where they came from.`}
            </li>
            <li>&ldquo;{idea.title}&rdquo; leaves the board, and its address leads to &ldquo;{target.title}&rdquo;.</li>
          </ul>
          <p className="merge-question">
            Merge &ldquo;{idea.title}&rdquo; into &ldquo;{target.title}&rdquo;? You can undo this from that idea&rsquo;s page.
          </p>
        </div>
      )}
      <Outcome state={state} />
      <div className="form-actions">
        <button type="submit" className="btn btn-primary" disabled={pending || !target}>
          {target ? `Merge into “${target.title}”` : "Merge"}
        </button>
        <button type="button" className="cancel-link link-button" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}

/** Hide or unhide one comment (owners only). */
export function CommentHideButton({ ideaId, commentId, hidden }: { ideaId: number; commentId: number; hidden: boolean }) {
  const [state, action, pending] = useActionState(setCommentHidden, IDLE);
  return (
    <form action={action} className="comment-tool">
      <input type="hidden" name="idea_id" value={ideaId} />
      <input type="hidden" name="comment_id" value={commentId} />
      <input type="hidden" name="hide" value={hidden ? "0" : "1"} />
      <button type="submit" className="link-button" disabled={pending}>
        {hidden ? "Unhide comment" : "Hide comment"}
      </button>
      {state.status === "error" && (
        <span className="alert" role="alert">
          {state.message}
        </span>
      )}
    </form>
  );
}

/** Undo merge, in the note on the target's page (owners only, task F6a). */
export function UndoMergeButton({ mergeId, ideaId, sourceId }: { mergeId: number; ideaId: number; sourceId: number }) {
  const [state, action, pending] = useActionState(undoMerge, IDLE);
  return (
    <form action={action} className="undo-merge">
      <input type="hidden" name="merge_id" value={mergeId} />
      <input type="hidden" name="idea_id" value={ideaId} />
      <input type="hidden" name="source_id" value={sourceId} />
      <button type="submit" className="btn" disabled={pending}>
        Undo merge
      </button>
      <Outcome state={state} />
    </form>
  );
}
