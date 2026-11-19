import Link from "next/link";
import { formatDate, formatVotes, publishedChangelog } from "@/lib/feedbox";
import { StatusChip } from "@/components/StatusChip";
import { getBoard, getChangelog, getIdeas, getViewer } from "@/lib/supabase/data";

// The changelog (Changelog.dc.html). Owners also get a link to the editor, /changelog/new (task F6).
export default async function ChangelogPage() {
  const board = await getBoard();
  if (!board) {
    return (
      <main className="page">
        <h1 className="page-title">Board not found</h1>
      </main>
    );
  }
  const [{ entries, items }, ideas, viewer] = await Promise.all([getChangelog(board.id), getIdeas(board.id), getViewer(board.id)]);
  const releases = publishedChangelog(entries, items, ideas);
  return (
    <main className="page" style={{ gap: 28 }}>
      <div>
        <div className="page-title-row">
          <h1 className="page-title">What shipped in {board.name}</h1>
          {viewer.role === "owner" && (
            <Link href="/changelog/new" className="btn btn-primary btn-post">
              Write a changelog entry
            </Link>
          )}
        </div>
        <p className="muted" style={{ margin: "6px 0 0" }}>
          Every entry started as an idea on the board. Newest first.
        </p>
      </div>
      {releases.length === 0 ? (
        <p className="empty">Nothing has been published yet.</p>
      ) : (
        releases.map((r) => (
          <section key={r.id} aria-label={r.title} className="release" data-testid="release">
            <div className="release-date">
              <strong>{formatDate(r.releasedOn)}</strong>
              <span className="muted" style={{ fontSize: 13 }}>
                {r.title}
              </span>
            </div>
            <div className="release-lines">
              {r.lines.map((l) => (
                <div key={l.ideaId} className="card release-line">
                  <div className="idea-title-line">
                    <span className="idea-title">{l.ideaTitle}</span>
                    <StatusChip status="shipped" />
                  </div>
                  <p>{l.note}</p>
                  <Link href={`/ideas/${l.ideaId}`} className="release-link">
                    See the idea, {formatVotes(l.voteCount)}
                  </Link>
                </div>
              ))}
            </div>
          </section>
        ))
      )}
    </main>
  );
}
