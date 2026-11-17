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
  if (!token_hash || !type) {
    return (
      <>
        <h1>Finish signing in</h1>
        <p role="alert">This sign-in link is incomplete. Ask for a new one.</p>
        <p>
          <Link href={`/sign-in?next=${encodeURIComponent(safeNext)}`}>Ask for a new link</Link>
        </p>
      </>
    );
  }
  return <ConfirmForm tokenHash={token_hash} type={type} next={safeNext} />;
}
