import Link from "next/link";
import { redirect } from "next/navigation";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { PostIdeaForm } from "./PostIdeaForm";

// Post an idea (PostIdea.dc.html), for a signed-in person with a display name.
export default async function NewIdeaPage() {
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  if (viewer.role === "visitor") redirect("/sign-in?next=%2Fideas%2Fnew");
  if (!board) {
    return (
      <main className="page">
        <h1 className="page-title">Board not found</h1>
      </main>
    );
  }
  return (
    <main className="page page-narrow-top">
      <Link href="/" className="back-link">
        &larr; All ideas
      </Link>
      <h1 className="page-title">Post an idea</h1>
      <PostIdeaForm />
    </main>
  );
}
