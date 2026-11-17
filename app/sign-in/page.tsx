import Link from "next/link";
import { safeNextPath } from "@/lib/feedbox";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { SignInForm } from "./SignInForm";

// Sign in by email link (F1 section 4; SignIn.dc.html).
export default async function SignInPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const next = safeNextPath((await searchParams).next);
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  return (
    <main className="auth-page">
      <div className="card auth-card">
        {viewer.role !== "visitor" ? (
          <>
            <h1>You are signed in</h1>
            <Link href={next} className="btn btn-primary">
              Continue
            </Link>
          </>
        ) : (
          <SignInForm next={next} />
        )}
      </div>
    </main>
  );
}
