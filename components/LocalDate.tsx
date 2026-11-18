"use client";
import { useSyncExternalStore } from "react";
import { formatDate, formatMonthDay } from "@/lib/feedbox";

// The viewer's time zone, as the browser knows it (task F5b). It never changes
// while the page is open, so there is nothing to subscribe to.
const noChanges = () => () => {};
const browserTimeZone = () => Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
const noTimeZoneOnServer = () => null;

/**
 * A moment shown as the date in the viewer's own time zone: "Nov 17, 2026", or
 * "Nov 17" with the full date as its tooltip (`short`, for comments). The
 * server cannot know the viewer's zone, so the page arrives with the UTC date
 * and the browser replaces it with its own as soon as the page starts (React
 * renders again right after hydration, without a warning).
 */
export function LocalDate({ value, short = false }: { value: string; short?: boolean }) {
  const zone = useSyncExternalStore(noChanges, browserTimeZone, noTimeZoneOnServer) ?? "UTC";
  const full = formatDate(value, zone);
  return (
    <time dateTime={value} title={short ? full : undefined}>
      {short ? formatMonthDay(value, zone) : full}
    </time>
  );
}
