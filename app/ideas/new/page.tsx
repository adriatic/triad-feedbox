import { redirect } from "next/navigation";
import { getBoard, getViewer } from "@/lib/supabase/data";

// Post an idea (F4: bare page; the form and similar ideas arrive in F5).
export default async function NewIdeaPage() {
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  if (viewer.role === "visitor") redirect("/sign-in?next=%2Fideas%2Fnew");
  return (
    <>
      <h1>Post an idea</h1>
      <p>
        Posting to <strong>{board?.name ?? "this board"}</strong> as {viewer.displayName}.
      </p>
      <p>The form arrives in task F5.</p>
    </>
  );
}
