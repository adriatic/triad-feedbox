import Link from "next/link";
import { safeNextPath } from "@/lib/feedbox";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { SignInForm } from "./SignInForm";

// Sign in by email link (F1 section 4). F4: bare; styled to SignIn.dc.html in F5.
export default async function SignInPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const next = safeNextPath((await searchParams).next);
  const board = await getBoard();
  const viewer = await getViewer(board?.id ?? null);
  if (viewer.role !== "visitor") {
    return (
      <>
        <h1>You are signed in</h1>
        <p>
          <Link href={next}>Continue</Link>
        </p>
      </>
    );
  }
  return <SignInForm next={next} />;
}
