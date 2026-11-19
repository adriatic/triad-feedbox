"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { boardInitial, viewerStateLabel } from "@/lib/feedbox";
import { inboxLabel } from "@/lib/messages/core";
import type { Board, ViewerInfo } from "@/lib/supabase/data";
import { SignInLink } from "./SignInLink";

/**
 * The header on every page (design brief): the board, and the sign-in state
 * in words: "Viewing as visitor", "Signed in as <name>" or "Signed in as
 * owner". Styled to the designs (task F5). Never shows an email address.
 *
 * Task F5c: the header never links to the page you are on. On the board the
 * board's name is not a link; on /changelog the header reads "Lumen
 * Changelog" and has "Back to the board" (Changelog.dc.html) instead of the
 * Changelog link; on /sign-in there is no Sign in button.
 *
 * Task CT1: an owner has "Messages", with the number of unread messages when
 * there are any ("Messages (2)"), except on /messages itself.
 */
export function Header({ board, viewer, unreadMessages = 0 }: { board: Board | null; viewer: ViewerInfo; unreadMessages?: number }) {
  const path = usePathname();
  const onBoard = path === "/";
  const onChangelog = path === "/changelog";
  const name = board?.name ?? "Feedbox";
  const pillClass = viewer.role === "owner" ? "state-pill owner" : viewer.role === "member" ? "state-pill signed-in" : "state-pill";
  const brand = (
    <>
      <span className="brand-mark" aria-hidden="true">
        {boardInitial(name)}
      </span>
      <span className="brand-name">{name}</span>
      {onChangelog ? <span className="brand-sub brand-page">Changelog</span> : <span className="brand-sub">Feedback and roadmap</span>}
    </>
  );
  return (
    <header className="site-header">
      <div className="site-header-inner">
        {onBoard || onChangelog ? (
          <div className="brand">{brand}</div>
        ) : (
          <Link href="/" className="brand" aria-label={`${name}, all ideas`}>
            {brand}
          </Link>
        )}
        {!onChangelog && (
          <Link href="/changelog" className="header-link">
            Changelog
          </Link>
        )}
        {viewer.role === "owner" && path !== "/messages" && (
          <Link href="/messages" className="header-link header-messages" data-testid="messages-link">
            {inboxLabel(unreadMessages)}
          </Link>
        )}
        <span className={pillClass} data-testid="viewer-state">
          {viewerStateLabel(viewer, viewer.displayName)}
        </span>
        {onChangelog && (
          <Link href="/" className="btn btn-small">
            Back to the board
          </Link>
        )}
        {viewer.role === "visitor" ? (
          path !== "/sign-in" && <SignInLink />
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
