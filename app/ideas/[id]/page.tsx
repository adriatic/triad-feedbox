import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { boardHref, can, canSeeIdea, canVoteOn, formatComments, formatVotes, mergeTargets, paragraphs } from "@/lib/feedbox";
import { LocalDate } from "@/components/LocalDate";
import { StatusChip } from "@/components/StatusChip";
import { VoteButton } from "@/components/VoteButton";
import { getBoard, getComments, getDisplayNames, getIdea, getIdeas, getMyVotes, getViewer, isInChangelog } from "@/lib/supabase/data";
import { CommentForm } from "./CommentForm";
import { CommentHideButton, OwnerTools } from "./OwnerTools";

// Idea detail (Idea.dc.html): vote, comments (flat, newest last), the comment box,
// and for owners the Owner tools (task F6): status, merge, hide or unhide the idea
// and each comment.
export default async function IdeaPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ merged?: string | string[] }>;
}) {
  const { id: raw } = await params;
  const { merged: rawMerged } = await searchParams;
  if (!/^[1-9]\d{0,15}$/.test(raw)) notFound();
  const board = await getBoard();
  if (!board) notFound();
  const idea = await getIdea(board.id, Number(raw));
  const viewer = await getViewer(board.id);
  if (!idea || !canSeeIdea(viewer, idea)) notFound();
  // A merged idea's address leads to the idea it was merged into, which says so
  // (F1 section 5). Not a permanent redirect: a wrong merge can be repaired by hand.
  if (idea.mergedIntoId !== null) redirect(`/ideas/${idea.mergedIntoId}?merged=${idea.id}`);

  const isOwner = viewer.role === "owner";
  const mergedId = typeof rawMerged === "string" && /^[1-9]\d{0,15}$/.test(rawMerged) ? Number(rawMerged) : null;
  const [names, comments, myVotes, mergedSource, inChangelog, boardIdeas] = await Promise.all([
    getDisplayNames([idea.authorId]),
    getComments(board.id, idea.id),
    getMyVotes(viewer, [idea.id]),
    mergedId === null ? Promise.resolve(null) : getIdea(board.id, mergedId),
    isOwner ? isInChangelog(idea.id) : Promise.resolve(false),
    isOwner ? getIdeas(board.id) : Promise.resolve([]),
  ]);
  // The note only for an idea that really was merged into this one.
  const mergedNote = mergedSource && mergedSource.mergedIntoId === idea.id ? mergedSource.title : null;
  const signedIn = viewer.role !== "visitor";
  const body = paragraphs(idea.body);
  const shownComments = comments.filter((c) => !c.hidden || isOwner);
  const canComment = can(viewer, "comment") && idea.hiddenAt === null;

  return (
    <main className="page page-narrow-top">
      <Link href={boardHref({ tab: idea.status, sort: "top" })} className="back-link">
        &larr; All ideas
      </Link>
      {mergedNote && (
        <p className="merged-note" role="status" data-testid="merged-note">
          &ldquo;{mergedNote}&rdquo; was merged into this idea. Its votes and comments are here now: {formatVotes(idea.voteCount)} in all.
        </p>
      )}
      <article className="card idea-article">
        <VoteButton
          ideaId={idea.id}
          title={idea.title}
          initial={{ voted: myVotes.has(idea.id), count: idea.voteCount }}
          canVote={canVoteOn(viewer, idea)}
          signedIn={signedIn}
          large
        />
        <div className="idea-article-main">
          <div className="idea-title-line">
            <h1>{idea.title}</h1>
            <StatusChip status={idea.status} />
            {idea.hiddenAt && <span className="chip chip-hidden">Hidden</span>}
          </div>
          <p className="idea-byline">
            Posted by {names.get(idea.authorId) ?? "someone"} on <LocalDate value={idea.createdAt} />
          </p>
          {body.length > 0 && (
            <div className="idea-body">
              {body.map((p, i) => (
                <p key={i}>{p}</p>
              ))}
            </div>
          )}
        </div>
      </article>
      {isOwner && (
        <OwnerTools
          idea={{
            id: idea.id,
            title: idea.title,
            status: idea.status,
            voteCount: idea.voteCount,
            commentCount: idea.commentCount,
            hidden: idea.hiddenAt !== null,
          }}
          inChangelog={inChangelog}
          targets={mergeTargets(idea.id, boardIdeas).map((t) => ({ id: t.id, title: t.title, voteCount: t.voteCount }))}
        />
      )}
      <section aria-label="Comments" className="comments">
        <h2>{formatComments(shownComments.length)}</h2>
        {shownComments.length > 0 && (
          <ol className="idea-list" data-testid="comment-list" style={{ gap: 12 }}>
            {shownComments.map((c) => (
              <li key={c.id} className="card comment" data-testid="comment">
                <div className="comment-head">
                  {c.authorName}
                  {c.byOwner && <span className="owner-badge">Owner</span>}
                  {c.hidden && <span className="chip chip-hidden chip-small">Hidden</span>}
                  <span className="comment-date">
                    <LocalDate value={c.createdAt} short />
                  </span>
                  {isOwner && <CommentHideButton ideaId={idea.id} commentId={c.id} hidden={c.hidden} />}
                </div>
                {c.movedFrom && <p className="comment-moved">From the merged idea &ldquo;{c.movedFrom}&rdquo;</p>}
                <p>{c.body}</p>
              </li>
            ))}
          </ol>
        )}
        {canComment ? (
          <CommentForm ideaId={idea.id} />
        ) : !signedIn ? (
          <p className="muted">
            <Link href={`/sign-in?next=${encodeURIComponent(`/ideas/${idea.id}`)}`} className="release-link">
              Sign in to comment
            </Link>
          </p>
        ) : null}
      </section>
    </main>
  );
}
