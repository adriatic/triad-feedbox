import { redirect } from "next/navigation";
import { formatDate } from "@/lib/feedbox";
import { getBoard, getChangelog, getViewer } from "@/lib/supabase/data";

// Write the changelog (owners only). Bare page listing drafts; the editor arrives in F6.
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
      <main className="page">
        <h1 className="page-title">Write the changelog</h1>
        <p>Only the owners of {board.name} can write the changelog.</p>
      </main>
    );
  }
  const { entries } = await getChangelog(board.id);
  const drafts = entries.filter((e) => e.publishedAt === null);
  return (
    <main className="page">
      <h1 className="page-title">Write the changelog</h1>
      <p>The editor arrives in task F6. Drafts on {board.name}:</p>
      {drafts.length === 0 ? (
        <p>No drafts.</p>
      ) : (
        <ul>
          {drafts.map((d) => (
            <li key={d.id}>
              {d.title} ({formatDate(d.releasedOn)})
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
