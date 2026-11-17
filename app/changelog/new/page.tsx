import { redirect } from "next/navigation";
import { formatDate } from "@/lib/feedbox";
import { getBoard, getChangelog, getViewer } from "@/lib/supabase/data";

// Write the changelog (owners only). F4: bare page listing drafts; the editor arrives in F6.
export default async function NewChangelogPage() {
  const board = await getBoard();
  if (!board) return <h1>Board not found</h1>;
  const viewer = await getViewer(board.id);
  if (viewer.role === "visitor") redirect("/sign-in?next=%2Fchangelog%2Fnew");
  if (viewer.role !== "owner") {
    return (
      <>
        <h1>Write the changelog</h1>
        <p>Only the owners of {board.name} can write the changelog.</p>
      </>
    );
  }
  const { entries } = await getChangelog(board.id);
  const drafts = entries.filter((e) => e.publishedAt === null);
  return (
    <>
      <h1>Write the changelog</h1>
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
    </>
  );
}
