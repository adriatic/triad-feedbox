import type { Metadata } from "next";
import Link from "next/link";
import { safeNextPath } from "@/lib/feedbox";
import { ConfirmForm } from "./ConfirmForm";

// The address holds a one-time token: never index it, never send it on as a referrer.
export const metadata: Metadata = { robots: { index: false, follow: false }, referrer: "no-referrer" };

// The page the sign-in email links to. It does NOT sign in on load (F1 section 4, step 4).
export default async function ConfirmPage({
  searchParams,
}: {
  searchParams: Promise<{ token_hash?: string; type?: string; next?: string }>;
}) {
  const { token_hash, type, next } = await searchParams;
  const safeNext = safeNextPath(next);
  return (
    <main className="auth-page">
      <div className="card auth-card">
        {!token_hash || !type ? (
          <>
            <h1>Finish signing in</h1>
            <p className="alert" role="alert">
              This sign-in link is incomplete. Ask for a new one.
            </p>
            <Link href={`/sign-in?next=${encodeURIComponent(safeNext)}`} className="btn">
              Ask for a new link
            </Link>
          </>
        ) : (
          <ConfirmForm tokenHash={token_hash} type={type} next={safeNext} />
        )}
      </div>
    </main>
  );
}
