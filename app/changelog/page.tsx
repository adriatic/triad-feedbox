import Link from "next/link";
import { formatDate, formatVotes, publishedChangelog } from "@/lib/feedbox";
import { getBoard, getChangelog, getIdeas } from "@/lib/supabase/data";

// The changelog (F4: bare page with real data; styled to Changelog.dc.html in F5).
export default async function ChangelogPage() {
  const board = await getBoard();
  if (!board) return <h1>Board not found</h1>;
  const [{ entries, items }, ideas] = await Promise.all([getChangelog(board.id), getIdeas(board.id)]);
  const releases = publishedChangelog(entries, items, ideas);
  return (
    <>
      <h1>Changelog</h1>
      <p>What shipped on {board.name}, newest first.</p>
      {releases.length === 0 ? (
        <p>Nothing has been published yet.</p>
      ) : (
        releases.map((r) => (
          <section key={r.id} data-testid="release">
            <h2>
              {r.title} ({formatDate(r.releasedOn)})
            </h2>
            <ul>
              {r.lines.map((l) => (
                <li key={l.ideaId}>
                  {l.note} (<Link href={`/ideas/${l.ideaId}`}>{l.ideaTitle}</Link>, {formatVotes(l.voteCount)})
                </li>
              ))}
            </ul>
          </section>
        ))
      )}
    </>
  );
}
