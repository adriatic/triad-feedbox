"use client";
import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { formatNumber, formatVotes, voteButtonLabel, type VoteState } from "@/lib/feedbox";
import { useVote } from "./useVote";

function UpArrow({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M6 15l6-6 6 6" />
    </svg>
  );
}

/** "/sign-in?next=<this page>", so a visitor comes back here after signing in. */
export function useSignInHref(): string {
  const path = usePathname();
  const search = useSearchParams().toString();
  const here = search ? `${path}?${search}` : path;
  return here === "/" ? "/sign-in" : `/sign-in?next=${encodeURIComponent(here)}`;
}

/**
 * The vote button with its count (Main.dc.html, Idea.dc.html). Pressed means
 * "you voted"; pressing again removes your vote. A visitor's button leads to
 * sign-in. `canVote` is false for a visitor, and on a hidden or merged idea.
 */
export function VoteButton({
  ideaId,
  title,
  initial,
  canVote,
  signedIn,
  large = false,
}: {
  ideaId: number;
  title: string;
  initial: VoteState;
  canVote: boolean;
  signedIn: boolean;
  large?: boolean;
}) {
  const signInHref = useSignInHref();
  const { shown, pending, error, toggle } = useVote(ideaId, initial);
  const className = large ? "vote vote-large" : "vote";
  const arrow = <UpArrow size={large ? 20 : 18} />;
  const count = <span data-testid="vote-count">{formatNumber(shown.count)}</span>;

  if (!signedIn) {
    return (
      <Link href={signInHref} className={className} aria-label={`Sign in to vote for ${title}, ${formatVotes(shown.count)}`}>
        {arrow}
        {count}
      </Link>
    );
  }
  return (
    <div className="vote-wrap">
      <button
        type="button"
        className={className}
        aria-pressed={shown.voted}
        aria-label={`${voteButtonLabel(shown)}: ${title}`}
        aria-busy={pending}
        disabled={!canVote}
        onClick={toggle}
      >
        {arrow}
        {count}
      </button>
      {error && (
        <p className="alert" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
