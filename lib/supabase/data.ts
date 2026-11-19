import { cache } from "react";
import { isDuplicateVote, isSearchable, mergeNotes, refusalMessage, SEARCH_LIMIT, SIMILAR_LIMIT, searchText, type ChangelogEntry, type ChangelogItem, type Idea, type MergeNote, type Role, type Viewer } from "@/lib/feedbox";
import { boardSlug } from "./env";
import { createClient } from "./server";

export interface Board {
  id: string;
  slug: string;
  name: string;
  tagline: string;
  intro: string;
}

/** The board named by FEEDBOX_BOARD_SLUG. Null if the database has no such board. */
export const getBoard = cache(async (): Promise<Board | null> => {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("boards")
    .select("id, slug, name, tagline, intro")
    .eq("slug", boardSlug())
    .maybeSingle();
  if (error) throw new Error(`Could not read the board: ${error.message}`);
  return data;
});

export interface ViewerInfo extends Viewer {
  displayName: string | null;
}

/**
 * Who is looking (F1 section 3): visitor, member or owner of this board.
 * The user comes from supabase.auth.getUser(), which asks the Auth server,
 * so a tampered cookie is not trusted.
 */
export const getViewer = cache(async (boardId: string | null): Promise<ViewerInfo> => {
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  const user = data.user;
  if (!user) return { role: "visitor", userId: null, hasDisplayName: false, displayName: null };

  const { data: profile } = await supabase.from("profiles").select("display_name").eq("id", user.id).maybeSingle();
  let role: Role = "member";
  if (boardId) {
    const { data: isOwner } = await supabase.rpc("is_board_owner", { p_board_id: boardId });
    if (isOwner === true) role = "owner";
  }
  const displayName = profile?.display_name ?? null;
  return { role, userId: user.id, hasDisplayName: displayName !== null, displayName };
});

interface IdeaRow {
  id: number;
  board_id: string;
  author_id: string;
  title: string;
  body: string;
  status: Idea["status"];
  vote_count: number;
  comment_count: number;
  merged_into_id: number | null;
  hidden_at: string | null;
  created_at: string;
  shipped_at: string | null;
}

const IDEA_COLUMNS =
  "id, board_id, author_id, title, body, status, vote_count, comment_count, merged_into_id, hidden_at, created_at, shipped_at";

function toIdea(r: IdeaRow): Idea {
  return {
    id: r.id,
    boardId: r.board_id,
    authorId: r.author_id,
    title: r.title,
    body: r.body,
    status: r.status,
    voteCount: r.vote_count,
    commentCount: r.comment_count,
    mergedIntoId: r.merged_into_id,
    hiddenAt: r.hidden_at,
    createdAt: r.created_at,
    shippedAt: r.shipped_at,
  };
}

/** Every idea on the board that row-level security lets this viewer read. */
export async function getIdeas(boardId: string): Promise<Idea[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("ideas").select(IDEA_COLUMNS).eq("board_id", boardId).returns<IdeaRow[]>();
  if (error) throw new Error(`Could not read the ideas: ${error.message}`);
  return data.map(toIdea);
}

export async function getIdea(boardId: string, id: number): Promise<Idea | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("ideas")
    .select(IDEA_COLUMNS)
    .eq("board_id", boardId)
    .eq("id", id)
    .returns<IdeaRow[]>()
    .maybeSingle();
  if (error) throw new Error(`Could not read the idea: ${error.message}`);
  return data ? toIdea(data) : null;
}

export interface CommentView {
  id: number;
  authorName: string;
  /** True when the author owns the board (see getOwnerIds; shown to every viewer since O2). */
  byOwner: boolean;
  /** The title of the idea this comment was moved from by a merge (F1 section 5), or null. */
  movedFrom: string | null;
  body: string;
  createdAt: string;
  hidden: boolean;
}

/** Comments on an idea, flat, newest last (F1 section 7). */
export async function getComments(boardId: string, ideaId: number): Promise<CommentView[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("comments")
    .select("id, author_id, body, created_at, hidden_at, moved_from_idea_id")
    .eq("idea_id", ideaId)
    .order("created_at", { ascending: true })
    .order("id", { ascending: true });
  if (error) throw new Error(`Could not read the comments: ${error.message}`);
  const movedIds = [...new Set(data.flatMap((c) => (c.moved_from_idea_id === null ? [] : [c.moved_from_idea_id])))];
  const [names, owners, movedTitles] = await Promise.all([
    getDisplayNames(data.map((c) => c.author_id)),
    getOwnerIds(boardId),
    getIdeaTitles(movedIds),
  ]);
  return data.map((c) => ({
    id: c.id,
    authorName: names.get(c.author_id) ?? "Someone",
    byOwner: owners.has(c.author_id),
    movedFrom: c.moved_from_idea_id === null ? null : (movedTitles.get(c.moved_from_idea_id) ?? null),
    body: c.body,
    createdAt: c.created_at,
    hidden: c.hidden_at !== null,
  }));
}

/**
 * The user ids of the board's owners, for every viewer, visitors included
 * (decision F5-D1, task O2), so the "Owner" mark on comments shows for everyone.
 * Read through the database function board_owner_ids, which returns ids only;
 * the table board_owners stays closed (an owner sees its rows, anyone else at
 * most their own).
 *
 * The mark is not essential to the page. If the read fails, for example because
 * a project does not have the function yet (its migration has not run there),
 * the page still loads and shows no mark, and the reason goes to the server log.
 */
export async function getOwnerIds(boardId: string): Promise<Set<string>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("board_owner_ids", { p_board_id: boardId });
  if (error) {
    console.error(
      `Feedbox: no Owner mark on comments, because the board's owners could not be read ` +
      `(board_owner_ids: ${error.code ?? "no code"} ${error.message}). ` +
      `Has the migration 20261118000000_board_owner_ids.sql run in this project?`,
    );
    return new Set();
  }
  return new Set(data ?? []);
}

/** Titles of ideas by id, as far as this viewer may read them (merged ideas stay readable). */
export async function getIdeaTitles(ids: readonly number[]): Promise<Map<number, string>> {
  if (ids.length === 0) return new Map();
  const supabase = await createClient();
  const { data, error } = await supabase.from("ideas").select("id, title").in("id", [...ids]);
  if (error) throw new Error(`Could not read idea titles: ${error.message}`);
  return new Map(data.map((i) => [i.id, i.title]));
}

/**
 * Owners only (task F6a): the ideas merged into this one, each with the merge
 * in the log that undoes it. Row-level security lets only the board's owners
 * read the log. If the log cannot be read (for example a database without the
 * F6a migration), the notes show without Undo merge, and the reason goes to
 * the server log.
 */
export async function getMergeNotes(ideaId: number): Promise<MergeNote[]> {
  const supabase = await createClient();
  const [ideas, merges] = await Promise.all([
    supabase.from("ideas").select("id, title").eq("merged_into_id", ideaId),
    supabase.from("idea_merges").select("id, source_id").eq("target_id", ideaId).is("undone_at", null),
  ]);
  if (ideas.error) throw new Error(`Could not read the merged ideas: ${ideas.error.message}`);
  if (merges.error) {
    console.error(`Could not read the merge log (${merges.error.code}): ${merges.error.message}. The notes show without Undo merge.`);
  }
  const open = (merges.data ?? []).flatMap((m) => (m.source_id === null ? [] : [{ id: m.id, sourceId: m.source_id }]));
  return mergeNotes(ideas.data, open);
}

/** True when the idea is a line in a changelog entry, draft or published (owners read both). */
export async function isInChangelog(ideaId: number): Promise<boolean> {
  const supabase = await createClient();
  const { count, error } = await supabase
    .from("changelog_items")
    .select("idea_id", { count: "exact", head: true })
    .eq("idea_id", ideaId);
  if (error) throw new Error(`Could not read the changelog lines: ${error.message}`);
  return (count ?? 0) > 0;
}

/** The ideas this viewer has voted for (votes are readable by their own person only). */
export async function getMyVotes(viewer: ViewerInfo, ideaIds: readonly number[]): Promise<Set<number>> {
  if (!viewer.userId || ideaIds.length === 0) return new Set();
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("votes")
    .select("idea_id")
    .eq("user_id", viewer.userId)
    .in("idea_id", [...ideaIds]);
  if (error) throw new Error(`Could not read your votes: ${error.message}`);
  return new Set(data.map((v) => v.idea_id));
}

/**
 * The board's search box (F1 section 5): the same similar_ideas function as
 * Post an idea, matching titles and details. Returns idea ids, best match first.
 */
export async function searchIdeaIds(boardId: string, query: string): Promise<number[]> {
  if (!isSearchable(query)) return [];
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("similar_ideas", {
    p_board_id: boardId,
    p_query: searchText(query),
    p_limit: SEARCH_LIMIT,
    p_include_body: true,
  });
  if (error) throw new Error(`Could not search the ideas: ${error.message}`);
  return data.map((r) => r.id);
}

export interface SimilarIdea {
  id: number;
  title: string;
  status: Idea["status"];
  voteCount: number;
  voted: boolean;
}

/**
 * Post an idea's similar ideas (F1 section 5): similar_ideas on titles, at
 * most 5, best first, each with whether the viewer has voted for it. Asked
 * on the server (task F5b), like the board's search box.
 */
export async function getSimilarIdeas(boardId: string, viewer: ViewerInfo, query: string): Promise<SimilarIdea[]> {
  if (!isSearchable(query)) return [];
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("similar_ideas", {
    p_board_id: boardId,
    p_query: searchText(query),
    p_limit: SIMILAR_LIMIT,
    p_include_body: false,
  });
  if (error) throw new Error(`Could not look for similar ideas: ${error.message}`);
  const mine = await getMyVotes(viewer, data.map((r) => r.id));
  return data.map((r) => ({ id: r.id, title: r.title, status: r.status, voteCount: r.vote_count, voted: mine.has(r.id) }));
}

export type VoteResult = { ok: true; voted: boolean; count: number } | { ok: false; message: string };

/**
 * Vote for an idea, or take the vote back, as the signed-in person; then read
 * the count and the person's own vote back from the database, which is the
 * authority. A second vote is refused by the primary key on votes (23505) and
 * ignored, so a double click or a second tab never counts twice. A vote goes
 * in as a row; a vote is taken back through remove_my_vote, which waits for a
 * merge or an undo of the idea in progress (task F6b). If the idea was just
 * merged, the database says so in words, and that is shown as it is.
 */
export async function setMyVote(ideaId: number, want: boolean): Promise<VoteResult> {
  if (!Number.isSafeInteger(ideaId) || ideaId <= 0) return { ok: false, message: "This idea is no longer on the board." };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  const userId = auth.user?.id;
  if (!userId) return { ok: false, message: "Your session has ended. Sign in again to vote." };
  const { error: writeError } = want
    ? await supabase.from("votes").insert({ idea_id: ideaId })
    : await supabase.rpc("remove_my_vote", { p_idea_id: ideaId });
  if (writeError && !isDuplicateVote(writeError)) {
    return { ok: false, message: refusalMessage(writeError, want ? "Voting" : "Removing your vote") };
  }
  const [{ data: idea, error: ideaError }, { data: mine, error: mineError }] = await Promise.all([
    supabase.from("ideas").select("vote_count").eq("id", ideaId).maybeSingle(),
    supabase.from("votes").select("idea_id").eq("idea_id", ideaId).eq("user_id", userId).maybeSingle(),
  ]);
  if (ideaError || mineError) return { ok: false, message: "Your vote was sent, but the new count could not be read. Reload the page." };
  if (!idea) return { ok: false, message: "This idea is no longer on the board." };
  return { ok: true, voted: mine !== null, count: idea.vote_count };
}

/** Display names by person (profiles never hold an email address). */
export async function getDisplayNames(ids: readonly string[]): Promise<Map<string, string>> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return new Map();
  const supabase = await createClient();
  const { data, error } = await supabase.from("profiles").select("id, display_name").in("id", unique);
  if (error) throw new Error(`Could not read names: ${error.message}`);
  return new Map(data.filter((p) => p.display_name).map((p) => [p.id, p.display_name as string]));
}

/** Changelog entries and lines this viewer may read (drafts only for owners, by RLS). */
export async function getChangelog(boardId: string): Promise<{ entries: ChangelogEntry[]; items: ChangelogItem[] }> {
  const supabase = await createClient();
  const { data: entries, error } = await supabase
    .from("changelog_entries")
    .select("id, board_id, title, released_on, published_at")
    .eq("board_id", boardId);
  if (error) throw new Error(`Could not read the changelog: ${error.message}`);
  const ids = entries.map((e) => e.id);
  const { data: items, error: itemsError } = ids.length
    ? await supabase.from("changelog_items").select("entry_id, idea_id, note, position").in("entry_id", ids)
    : { data: [], error: null };
  if (itemsError) throw new Error(`Could not read the changelog lines: ${itemsError.message}`);
  return {
    entries: entries.map((e) => ({
      id: e.id,
      boardId: e.board_id,
      title: e.title,
      releasedOn: e.released_on,
      publishedAt: e.published_at,
    })),
    items: (items ?? []).map((i) => ({ entryId: i.entry_id, ideaId: i.idea_id, note: i.note, position: i.position })),
  };
}
