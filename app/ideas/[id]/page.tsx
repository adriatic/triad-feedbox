import Link from "next/link";
import { notFound, permanentRedirect } from "next/navigation";
import { canSeeIdea, formatComments, formatDate, formatVotes, statusLabel } from "@/lib/feedbox";
import { getBoard, getComments, getDisplayNames, getIdea, getViewer } from "@/lib/supabase/data";

// Idea detail (F4: bare page with real data; styled to Idea.dc.html in F5).
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

  const names = await getDisplayNames([idea.authorId]);
  const comments = await getComments(idea.id);
  return (
    <>
      <p>
        <Link href={`/?tab=${idea.status}`}>Back to {statusLabel(idea.status)}</Link>
      </p>
      <h1>{idea.title}</h1>
      <p>
        {statusLabel(idea.status)} · {formatVotes(idea.voteCount)} · {formatComments(idea.commentCount)}
        {idea.hiddenAt && " · Hidden"}
      </p>
      <p>
        Posted by {names.get(idea.authorId) ?? "someone"} on {formatDate(idea.createdAt)}
      </p>
      {idea.body && <p style={{ whiteSpace: "pre-wrap" }}>{idea.body}</p>}
      <h2>Comments</h2>
      {comments.length === 0 ? (
        <p>No comments yet.</p>
      ) : (
        <ul data-testid="comment-list">
          {comments.map((c) => (
            <li key={c.id}>
              <strong>{c.authorName}</strong> ({formatDate(c.createdAt)}){c.hidden && " [Hidden]"}:{" "}
              <span style={{ whiteSpace: "pre-wrap" }}>{c.body}</span>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
