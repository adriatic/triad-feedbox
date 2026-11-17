"use client";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { boardHref, SIMILAR_DEBOUNCE_MS, type IdeaStatus, type Sort } from "@/lib/feedbox";

/**
 * The board's search box (Main.dc.html). It searches through similar_ideas on
 * the server (F1 section 5): the address changes 300 ms after the last
 * keystroke (?q=), and the board reads it. Without JavaScript, Enter submits
 * the same address.
 */
export function SearchBox({ tab, sort, query }: { tab: IdeaStatus; sort: Sort; query: string }) {
  const router = useRouter();
  const [value, setValue] = useState(query);
  const first = useRef(true);

  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    const timer = setTimeout(() => router.replace(boardHref({ tab, sort, q: value }), { scroll: false }), SIMILAR_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [value, tab, sort, router]);

  return (
    <form role="search" action="/" method="get" onSubmit={(e) => { e.preventDefault(); router.replace(boardHref({ tab, sort, q: value }), { scroll: false }); }}>
      {tab !== "open" && <input type="hidden" name="tab" value={tab} />}
      {sort !== "top" && <input type="hidden" name="sort" value={sort} />}
      <label className="search">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-4-4" />
        </svg>
        <span className="sr-only">Search ideas</span>
        <input type="search" name="q" placeholder="Search ideas" value={value} onChange={(e) => setValue(e.target.value)} />
      </label>
    </form>
  );
}
