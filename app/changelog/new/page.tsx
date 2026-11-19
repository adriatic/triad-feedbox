import Link from "next/link";
import { redirect } from "next/navigation";
import { ideasReadyForChangelog } from "@/lib/feedbox";
import { getBoard, getChangelog, getIdeas, getViewer } from "@/lib/supabase/data";
import { ChangelogForm } from "./ChangelogForm";

// The changelog editor (F1 section 8, task F6), for the board's owners. No
// design exists for it; it reuses the Post an idea layout (PostIdea.dc.html).
export default async function NewChangelogPage() {
  const board = await getBoard();
  if (!board) {
    return (
      <main className="page">
        <h1 className="page-title">Board not found</h1>
      </main>
    );
  }
  const viewer = await getViewer(board.id);
  if (viewer.role === "visitor") redirect("/sign-in?next=%2Fchangelog%2Fnew");
  if (viewer.role !== "owner") {
    return (
      <main className="page page-narrow-top">
        <Link href="/changelog" className="back-link">
          &larr; The changelog
        </Link>
        <h1 className="page-title">Write the changelog</h1>
        <p>Only the owners of {board.name} can write the changelog.</p>
      </main>
    );
  }
  const [ideas, { items }] = await Promise.all([getIdeas(board.id), getChangelog(board.id)]);
  const ready = ideasReadyForChangelog(ideas, items).map((i) => ({ id: i.id, title: i.title, voteCount: i.voteCount }));
  return (
    <main className="page page-narrow-top">
      <Link href="/changelog" className="back-link">
        &larr; The changelog
      </Link>
      <h1 className="page-title">Write the changelog</h1>
      {ready.length === 0 ? (
        <p className="empty">
          No Shipped idea is waiting for the changelog. Move an idea to Shipped with the Owner tools on its page first.
        </p>
      ) : (
        <ChangelogForm ideas={ready} boardName={board.name} />
      )}
    </main>
  );
}
