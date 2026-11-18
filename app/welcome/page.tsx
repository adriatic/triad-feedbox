import { redirect } from "next/navigation";
import { safeNextPath } from "@/lib/feedbox";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { WelcomeForm } from "./WelcomeForm";

// First sign-in: the display name, asked once (F1 section 4). Styled like SignIn.dc.html. proxy.ts sends
// every other page here until the name is set.
export default async function WelcomePage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const next = safeNextPath((await searchParams).next);
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  if (viewer.role === "visitor") redirect(`/sign-in?next=${encodeURIComponent(next)}`);
  if (viewer.hasDisplayName) redirect(next);
  return (
    <main className="auth-page">
      <div className="card auth-card">
        <h1>Welcome to {board?.name ?? "Feedbox"}</h1>
        <p className="muted">One thing before you start: the name people see next to your ideas and comments.</p>
        <WelcomeForm next={next} />
      </div>
    </main>
  );
}
