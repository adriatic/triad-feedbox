import Link from "next/link";
import {
  boardHref,
  canVoteOn,
  formatComments,
  ideasForTab,
  isSearchable,
  parseSort,
  STATUSES,
  searchText,
  statusLabel,
  tabCounts,
  tabFromParam,
  type Idea,
} from "@/lib/feedbox";
import { SearchBox } from "@/components/SearchBox";
import { SortMenu } from "@/components/SortMenu";
import { StatusChip } from "@/components/StatusChip";
import { VoteButton } from "@/components/VoteButton";
import { getBoard, getIdeas, getMyVotes, getViewer, searchIdeaIds } from "@/lib/supabase/data";
import { boardSlug } from "@/lib/supabase/env";

// The board (Main.dc.html; BoardPhone.dc.html below 640 px): tabs, search, sort, vote.
export default async function BoardPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; sort?: string; q?: string }>;
}) {
  const board = await getBoard();
  if (!board) return <BoardMissing />;
  const { tab: tabParam, sort: sortParam, q: qParam } = await searchParams;
  const tab = tabFromParam(tabParam);
  const sort = parseSort(sortParam);
  const query = searchText(typeof qParam === "string" ? qParam : "");
  const viewer = await getViewer(board.id);
  const includeHidden = viewer.role === "owner";
  const [ideas, matchIds] = await Promise.all([getIdeas(board.id), query ? searchIdeaIds(board.id, query) : Promise.resolve(null)]);
  const counts = tabCounts(ideas, { includeHidden });
  let shown: Idea[] = ideasForTab(ideas, tab, sort, { includeHidden });
  if (matchIds) {
    const matches = new Set(matchIds);
    shown = shown.filter((i) => matches.has(i.id));
  }
  const myVotes = await getMyVotes(viewer, shown.map((i) => i.id));
  const signedIn = viewer.role !== "visitor";

  return (
    <main className="page">
      <div className="board-top">
        <div className="board-heading">
          <h1 className="page-title">{board.tagline || board.name}</h1>
          {board.intro && <p>{board.intro}</p>}
        </div>
        <Link href="/ideas/new" className="btn btn-primary btn-post">
          Post an idea
        </Link>
      </div>
      <div className="toolbar">
        <nav className="tabs" aria-label="Ideas by status">
          {/* The current tab is not a link: it would lead to the page you are on (task F5d). */}
          {STATUSES.map((s) =>
            s === tab ? (
              <span key={s} className="tab" aria-current="page">
                {statusLabel(s)} <span className="tab-count">{counts[s]}</span>
              </span>
            ) : (
              <Link key={s} href={boardHref({ tab: s, sort, q: query })} className="tab">
                {statusLabel(s)} <span className="tab-count">{counts[s]}</span>
              </Link>
            ),
          )}
        </nav>
        <div className="tools">
          <SearchBox key={`${tab}-${sort}`} tab={tab} sort={sort} query={query} />
          <SortMenu tab={tab} sort={sort} query={query} />
        </div>
      </div>
      {query && !isSearchable(query) ? (
        <p className="empty">Type at least 3 characters to search.</p>
      ) : shown.length === 0 ? (
        <p className="empty">{query ? "No ideas match your search." : `No ${statusLabel(tab)} ideas yet.`}</p>
      ) : (
        <ul className="idea-list" data-testid="idea-list">
          {shown.map((idea) => (
            <li key={idea.id} className="card idea-row" data-testid="idea-row">
              <VoteButton
                ideaId={idea.id}
                title={idea.title}
                initial={{ voted: myVotes.has(idea.id), count: idea.voteCount }}
                canVote={canVoteOn(viewer, idea)}
                signedIn={signedIn}
              />
              <div className="idea-main">
                <div className="idea-title-line">
                  <Link href={`/ideas/${idea.id}`} className="idea-title">
                    {idea.title}
                  </Link>
                  <StatusChip status={idea.status} />
                  {idea.hiddenAt && <span className="chip chip-hidden">Hidden</span>}
                </div>
                {idea.body && <p className="idea-desc">{idea.body.split("\n")[0]}</p>}
                <span className="idea-meta">{formatComments(idea.commentCount)}</span>
              </div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

function BoardMissing() {
  return (
    <main className="page">
      <h1 className="page-title">Board not found</h1>
      <p>
        This deployment shows the board <code>{boardSlug()}</code> (FEEDBOX_BOARD_SLUG), and the database has no board
        with that slug.
      </p>
    </main>
  );
}
