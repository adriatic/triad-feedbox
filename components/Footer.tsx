"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { MESSAGE_WORDS } from "@/lib/messages/core";

/**
 * The footer on every page. Like the header (task F5c), it never links to the
 * page you are on: on /changelog the line keeps its words but has no
 * "See what shipped" link (task F5d), and on /contact it has no
 * "Contact the owner" link (task CT1).
 */
export function Footer({ boardName }: { boardName: string }) {
  const path = usePathname();
  const links = [
    path !== "/changelog" && (
      <Link key="changelog" href="/changelog">
        See what shipped
      </Link>
    ),
    path !== "/contact" && (
      <Link key="contact" href="/contact">
        {MESSAGE_WORDS.footerLink}
      </Link>
    ),
  ].filter(Boolean);
  return (
    <footer className="site-footer">
      {boardName} runs on Feedbox, a free, open-source feedback board.
      {links.map((link, i) => (
        <span key={i}>
          {i > 0 ? <span aria-hidden="true"> · </span> : " "}
          {link}
        </span>
      ))}
    </footer>
  );
}
