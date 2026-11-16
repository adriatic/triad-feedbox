import { cache } from "react";
import type { ChangelogEntry, ChangelogItem, Idea, Role, Viewer } from "@/lib/feedbox";
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
  body: string;
  createdAt: string;
  hidden: boolean;
}

export async function getComments(ideaId: number): Promise<CommentView[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("comments")
    .select("id, author_id, body, created_at, hidden_at")
    .eq("idea_id", ideaId)
    .order("created_at", { ascending: true });
  if (error) throw new Error(`Could not read the comments: ${error.message}`);
  const names = await getDisplayNames(data.map((c) => c.author_id));
  return data.map((c) => ({
    id: c.id,
    authorName: names.get(c.author_id) ?? "Someone",
    body: c.body,
    createdAt: c.created_at,
    hidden: c.hidden_at !== null,
  }));
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
