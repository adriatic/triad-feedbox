import type { Idea, Viewer } from "./types";

/** The invented Lumen board from the design brief, used by every test. */
export const BOARD = "board-lumen";

let nextId = 1;
export function idea(over: Partial<Idea> & Pick<Idea, "title">): Idea {
  const id = over.id ?? nextId++;
  return {
    id,
    boardId: BOARD,
    authorId: "user-mira",
    body: "",
    status: "open",
    voteCount: 0,
    commentCount: 0,
    mergedIntoId: null,
    hiddenAt: null,
    createdAt: "2026-10-01T09:00:00Z",
    shippedAt: null,
    ...over,
  };
}

export const LUMEN: Idea[] = [
  idea({ id: 1, title: "Dark mode for the editor", voteCount: 214, status: "planned", commentCount: 18, createdAt: "2026-10-03T08:00:00Z" }),
  idea({ id: 2, title: "Export notes to Markdown", voteCount: 187, status: "building", commentCount: 24, createdAt: "2026-09-20T08:00:00Z" }),
  idea({ id: 3, title: "Offline mode", voteCount: 132, status: "planned", commentCount: 11, createdAt: "2026-09-01T08:00:00Z" }),
  idea({ id: 4, title: "Keyboard shortcut cheat sheet", voteCount: 96, status: "shipped", commentCount: 6, createdAt: "2026-08-01T08:00:00Z", shippedAt: "2026-11-03T10:00:00Z" }),
  idea({ id: 5, title: "Faster startup on large notebooks", voteCount: 88, status: "shipped", commentCount: 9, createdAt: "2026-07-01T08:00:00Z", shippedAt: "2026-11-02T10:00:00Z" }),
  idea({ id: 6, title: "Sync between two laptops", voteCount: 73, status: "open", commentCount: 14, createdAt: "2026-10-20T08:00:00Z" }),
  idea({ id: 7, title: "Search inside attachments", voteCount: 58, status: "open", commentCount: 5, createdAt: "2026-10-25T08:00:00Z" }),
  idea({ id: 8, title: "Share a note by link", voteCount: 49, status: "open", commentCount: 8, createdAt: "2026-11-01T08:00:00Z" }),
  idea({ id: 9, title: "Tag notes by colour", voteCount: 41, status: "open", commentCount: 3, createdAt: "2026-11-05T08:00:00Z" }),
];

export const VISITOR: Viewer = { role: "visitor", userId: null, hasDisplayName: false };
export const NEW_MEMBER: Viewer = { role: "member", userId: "user-sam", hasDisplayName: false };
export const MEMBER: Viewer = { role: "member", userId: "user-sam", hasDisplayName: true };
export const OWNER: Viewer = { role: "owner", userId: "user-ana", hasDisplayName: true };
