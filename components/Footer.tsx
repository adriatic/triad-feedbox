"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * The footer on every page. Like the header (task F5c), it never links to the
 * page you are on: on /changelog the line keeps its words but has no
 * "See what shipped" link (task F5d).
 */
export function Footer({ boardName }: { boardName: string }) {
  const onChangelog = usePathname() === "/changelog";
  return (
    <footer className="site-footer">
      {boardName} runs on Feedbox, a free, open-source feedback board.
      {!onChangelog && (
        <>
          {" "}
          <Link href="/changelog">See what shipped</Link>
        </>
      )}
    </footer>
  );
}
