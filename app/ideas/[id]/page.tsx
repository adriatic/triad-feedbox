import Link from "next/link";
import { notFound, permanentRedirect } from "next/navigation";
import { boardHref, can, canSeeIdea, canVoteOn, formatComments, formatDate, formatMonthDay, paragraphs } from "@/lib/feedbox";
import { StatusChip } from "@/components/StatusChip";
import { VoteButton } from "@/components/VoteButton";
import { getBoard, getComments, getDisplayNames, getIdea, getMyVotes, getViewer } from "@/lib/supabase/data";
import { CommentForm } from "./CommentForm";

// Idea detail (Idea.dc.html): vote, comments (flat, newest last), the comment box.
// The owner tools of the design (status, merge, hide) arrive in F6.
export default async function IdeaPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: raw } = await params;
  if (!/^[1-9]\d{0,15}$/.test(raw)) notFound();
  const board = await getBoard();
  if (!board) notFound();
  const idea = await getIdea(board.id, Number(raw));
  const viewer = await getViewer(board.id);
  if (!idea || !canSeeIdea(viewer, idea)) notFound();
  // A merged idea redirects to the idea it was merged into (F1 decision D8).
  if (idea.mergedIntoId !== null) permanentRedirect(`/ideas/${idea.mergedIntoId}`);

  const [names, comments, myVotes] = await Promise.all([
    getDisplayNames([idea.authorId]),
    getComments(board.id, idea.id),
    getMyVotes(viewer, [idea.id]),
  ]);
  const signedIn = viewer.role !== "visitor";
  const body = paragraphs(idea.body);
  const shownComments = comments.filter((c) => !c.hidden || viewer.role === "owner");
  const canComment = can(viewer, "comment") && idea.hiddenAt === null;

  return (
    <main className="page page-narrow-top">
      <Link href={boardHref({ tab: idea.status, sort: "top" })} className="back-link">
        &larr; All ideas
      </Link>
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
            Posted by {names.get(idea.authorId) ?? "someone"} on {formatDate(idea.createdAt)}
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
      <section aria-label="Comments" className="comments">
        <h2>{formatComments(shownComments.length)}</h2>
        {shownComments.length > 0 && (
          <ol className="idea-list" data-testid="comment-list" style={{ gap: 12 }}>
            {shownComments.map((c) => (
              <li key={c.id} className="card comment" data-testid="comment">
                <div className="comment-head">
                  {c.authorName}
                  {c.byOwner && <span className="owner-badge">Owner</span>}
                  {c.hidden && <span className="owner-badge">Hidden</span>}
                  <span className="comment-date">
                    <time dateTime={c.createdAt} title={formatDate(c.createdAt)}>
                      {formatMonthDay(c.createdAt)}
                    </time>
                  </span>
                </div>
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
