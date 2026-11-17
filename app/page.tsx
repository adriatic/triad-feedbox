import Link from "next/link";
import {
  formatComments,
  formatVotes,
  ideasForTab,
  parseSort,
  SORT_LABELS,
  SORTS,
  STATUSES,
  statusLabel,
  tabCounts,
  tabFromParam,
} from "@/lib/feedbox";
import { getBoard, getIdeas, getViewer } from "@/lib/supabase/data";
import { boardSlug } from "@/lib/supabase/env";

// The board (F4: bare page with real data; styled to Main.dc.html in F5).
export default async function BoardPage({ searchParams }: { searchParams: Promise<{ tab?: string; sort?: string }> }) {
  const board = await getBoard();
  if (!board) return <BoardMissing />;
  const { tab: tabParam, sort: sortParam } = await searchParams;
  const tab = tabFromParam(tabParam);
  const sort = parseSort(sortParam);
  const viewer = await getViewer(board.id);
  const includeHidden = viewer.role === "owner";
  const ideas = await getIdeas(board.id);
  const counts = tabCounts(ideas, { includeHidden });
  const shown = ideasForTab(ideas, tab, sort, { includeHidden });

  return (
    <>
      <h1>{board.name}</h1>
      {board.tagline && <p>{board.tagline}</p>}
      {board.intro && <p>{board.intro}</p>}
      <p>
        {STATUSES.map((s, i) => (
          <span key={s}>
            {i > 0 && " · "}
            {s === tab ? (
              <strong>
                {statusLabel(s)} ({counts[s]})
              </strong>
            ) : (
              <Link href={`/?tab=${s}&sort=${sort}`}>
                {statusLabel(s)} ({counts[s]})
              </Link>
            )}
          </span>
        ))}
      </p>
      <p>
        Sort:{" "}
        {SORTS.map((s, i) => (
          <span key={s}>
            {i > 0 && " · "}
            {s === sort ? <strong>{SORT_LABELS[s]}</strong> : <Link href={`/?tab=${tab}&sort=${s}`}>{SORT_LABELS[s]}</Link>}
          </span>
        ))}
      </p>
      {shown.length === 0 ? (
        <p>No ideas here yet.</p>
      ) : (
        <ul data-testid="idea-list">
          {shown.map((idea) => (
            <li key={idea.id}>
              <Link href={`/ideas/${idea.id}`}>{idea.title}</Link> ({formatVotes(idea.voteCount)},{" "}
              {formatComments(idea.commentCount)}){idea.hiddenAt && " [Hidden]"}
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

function BoardMissing() {
  return (
    <>
      <h1>Board not found</h1>
      <p>
        This deployment shows the board <code>{boardSlug()}</code> (FEEDBOX_BOARD_SLUG), and the database has no board
        with that slug.
      </p>
    </>
  );
}
