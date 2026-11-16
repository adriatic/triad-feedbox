import Link from "next/link";
import { viewerStateLabel } from "@/lib/feedbox";
import type { Board, ViewerInfo } from "@/lib/supabase/data";
import { SignInLink } from "./SignInLink";

/**
 * The header on every page (design brief): the board, the pages, and the
 * sign-in state in words: "Viewing as visitor", "Signed in as <name>" or
 * "Signed in as owner". Bare in F4; styled to the designs in F5.
 */
export function Header({ board, viewer }: { board: Board | null; viewer: ViewerInfo }) {
  return (
    <header>
      <p>
        <Link href="/">{board?.name ?? "Feedbox"}</Link>
        {" · "}
        <Link href="/changelog">Changelog</Link>
        {" · "}
        <Link href="/ideas/new">Post an idea</Link>
      </p>
      <p>
        <span data-testid="viewer-state">{viewerStateLabel(viewer, viewer.displayName)}</span>{" "}
        {viewer.role === "visitor" ? (
          <SignInLink />
        ) : (
          <form action="/auth/sign-out" method="post" style={{ display: "inline" }}>
            <button type="submit">Sign out</button>
          </form>
        )}
      </p>
      <hr />
    </header>
  );
}
