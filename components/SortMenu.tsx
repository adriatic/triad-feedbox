"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useId, useRef, useState, type KeyboardEvent } from "react";
import { boardHref, SORT_LABELS, SORTS, type IdeaStatus, type Sort } from "@/lib/feedbox";

// Icons drawn like the search icon (24 x 24, round strokes, the text colour).
function Icon({ children, size = 16 }: { children: React.ReactNode; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {children}
    </svg>
  );
}
/** Most votes: an arrow up. */
const MostVotesIcon = () => (
  <Icon>
    <path d="M12 19V5" />
    <path d="M6 11l6-6 6 6" />
  </Icon>
);
/** Newest: a clock. */
const NewestIcon = () => (
  <Icon>
    <circle cx="12" cy="12" r="8.5" />
    <path d="M12 7.5V12l3 2" />
  </Icon>
);
const SORT_ICONS: Readonly<Record<Sort, () => React.ReactElement>> = { top: MostVotesIcon, new: NewestIcon };
const Tick = () => (
  <Icon>
    <path d="M5 12.5l4.5 4.5L19 7.5" />
  </Icon>
);
const Chevron = () => (
  <Icon size={14}>
    <path d="M6 9l6 6 6-6" />
  </Icon>
);

/**
 * The board's sort control (task F5c, Nik's choice of 2026-11-17 6:35 PM):
 * one button with the order's icon and its name, "Most votes" or "Newest".
 * It opens a small menu with both orders, each with its icon, and a tick at
 * the current one. Keyboard: Return, Space or the arrow keys open it; the
 * arrow keys, Home and End move; Return chooses; Escape and Tab close it.
 * The order stays in the address (?sort=new), as before.
 *
 * Task F5d: the ticked order is not a link, because it would lead to the page
 * you are on; choosing it only closes the menu.
 */
export function SortMenu({ tab, sort, query }: { tab: IdeaStatus; sort: Sort; query: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const button = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const items = useRef<(HTMLElement | null)[]>([]);
  const menuId = useId();
  const CurrentIcon = SORT_ICONS[sort];

  const focusItem = (i: number) => items.current[(i + SORTS.length) % SORTS.length]?.focus();
  const openAt = (i: number) => {
    setOpen(true);
    requestAnimationFrame(() => focusItem(i));
  };
  const close = (returnFocus: boolean) => {
    setOpen(false);
    if (returnFocus) button.current?.focus();
  };

  // A click anywhere else closes the menu.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      const t = e.target as Node;
      if (!menu.current?.contains(t) && !button.current?.contains(t)) setOpen(false);
    };
    document.addEventListener("pointerdown", onDown);
    return () => document.removeEventListener("pointerdown", onDown);
  }, [open]);

  const onButtonKey = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      openAt(e.key === "ArrowDown" ? SORTS.indexOf(sort) : SORTS.length - 1);
    }
  };
  const onMenuKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const at = items.current.findIndex((el) => el === document.activeElement);
    if (e.key === "ArrowDown") focusItem(at + 1);
    else if (e.key === "ArrowUp") focusItem(at - 1);
    else if (e.key === "Home") focusItem(0);
    else if (e.key === "End") focusItem(SORTS.length - 1);
    else if (e.key === "Escape") close(true);
    else if (e.key === "Tab") return setOpen(false);
    else if ((e.key === " " || e.key === "Enter") && at >= 0) items.current[at]?.click();
    else return;
    e.preventDefault();
  };

  return (
    <div className="sort">
      <button
        ref={button}
        type="button"
        className="btn sort-button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        aria-label={`Sort ideas: ${SORT_LABELS[sort]}`}
        onClick={() => (open ? close(false) : openAt(SORTS.indexOf(sort)))}
        onKeyDown={onButtonKey}
      >
        <CurrentIcon />
        <span>{SORT_LABELS[sort]}</span>
        <Chevron />
      </button>
      {open && (
        <div ref={menu} id={menuId} role="menu" aria-label="Sort ideas" className="sort-menu" onKeyDown={onMenuKey}>
          {SORTS.map((s, i) => {
            const ItemIcon = SORT_ICONS[s];
            const checked = s === sort;
            const content = (
              <>
                <ItemIcon />
                <span className="sort-item-label">{SORT_LABELS[s]}</span>
                <span className="sort-tick">{checked && <Tick />}</span>
              </>
            );
            const common = {
              ref: (el: HTMLElement | null) => {
                items.current[i] = el;
              },
              role: "menuitemradio",
              "aria-checked": checked,
              tabIndex: -1,
              className: "sort-item",
            } as const;
            const choose = () => {
              setOpen(false);
              button.current?.focus();
              if (!checked) router.replace(boardHref({ tab, sort: s, q: query }), { scroll: false });
            };
            return checked ? (
              <div key={s} {...common} onClick={choose}>
                {content}
              </div>
            ) : (
              <Link
                key={s}
                {...common}
                href={boardHref({ tab, sort: s, q: query })}
                scroll={false}
                onClick={(e) => {
                  e.preventDefault();
                  choose();
                }}
              >
                {content}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
