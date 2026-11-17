import Link from "next/link";
import { boardInitial, viewerStateLabel } from "@/lib/feedbox";
import type { Board, ViewerInfo } from "@/lib/supabase/data";
import { SignInLink } from "./SignInLink";

/**
 * The header on every page (design brief): the board, and the sign-in state
 * in words: "Viewing as visitor", "Signed in as <name>" or "Signed in as
 * owner". Styled to the designs (task F5). Never shows an email address.
 */
export function Header({ board, viewer }: { board: Board | null; viewer: ViewerInfo }) {
  const name = board?.name ?? "Feedbox";
  const pillClass = viewer.role === "owner" ? "state-pill owner" : viewer.role === "member" ? "state-pill signed-in" : "state-pill";
  return (
    <header className="site-header">
      <div className="site-header-inner">
        <Link href="/" className="brand" aria-label={`${name}, all ideas`}>
          <span className="brand-mark" aria-hidden="true">
            {boardInitial(name)}
          </span>
          <span className="brand-name">{name}</span>
          <span className="brand-sub">Feedback and roadmap</span>
        </Link>
        <Link href="/changelog" className="header-link">
          Changelog
        </Link>
        <span className={pillClass} data-testid="viewer-state">
          {viewerStateLabel(viewer, viewer.displayName)}
        </span>
        {viewer.role === "visitor" ? (
          <SignInLink />
        ) : (
          <form action="/auth/sign-out" method="post" className="header-form">
            <button type="submit" className="btn btn-small">
              Sign out
            </button>
          </form>
        )}
      </div>
    </header>
  );
}
