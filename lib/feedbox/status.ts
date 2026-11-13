import { ok, refuse, type IdeaStatus, type Result } from "./types";

/** The statuses in board order. These are also the four tabs. */
export const STATUSES: readonly IdeaStatus[] = ["open", "planned", "building", "shipped"] as const;

/** The exact words shown on chips and tabs (design brief: "Open, Planned, Building, Shipped"). */
export const STATUS_LABELS: Readonly<Record<IdeaStatus, string>> = {
  open: "Open",
  planned: "Planned",
  building: "Building",
  shipped: "Shipped",
};

/** Every new idea starts here. */
export const INITIAL_STATUS: IdeaStatus = "open";

export function statusLabel(status: IdeaStatus): string {
  return STATUS_LABELS[status];
}

export function isIdeaStatus(value: unknown): value is IdeaStatus {
  return typeof value === "string" && (STATUSES as readonly string[]).includes(value);
}

/** Reads a status from a URL parameter such as ?status=Planned. Unknown values give null. */
export function parseStatus(value: string | null | undefined): IdeaStatus | null {
  if (typeof value !== "string") return null;
  const v = value.trim().toLowerCase();
  return isIdeaStatus(v) ? v : null;
}

/** The tab shown when the URL names none, or names an unknown one. */
export function tabFromParam(value: string | null | undefined): IdeaStatus {
  return parseStatus(value) ?? INITIAL_STATUS;
}

export interface StatusChange {
  from: IdeaStatus;
  to: IdeaStatus;
  /** True when the idea is listed in a changelog entry (draft or published). */
  inChangelog: boolean;
}

/**
 * Status changes (owner only; permission is checked separately in permissions.ts).
 * - The owner may move an idea to any other status, forward or back, to correct mistakes.
 * - Setting the same status again is refused, so nothing is recorded twice.
 * - An idea listed in a changelog entry must stay Shipped; remove it from the entry first.
 */
export function checkStatusChange({ from, to, inChangelog }: StatusChange): Result {
  if (from === to) return refuse(`The idea is already ${statusLabel(to)}.`);
  if (from === "shipped" && inChangelog) {
    return refuse("This idea is in a changelog entry, so it stays Shipped. Remove it from the entry first.");
  }
  return ok(undefined);
}

/** shipped_at is set when an idea becomes Shipped and cleared when it leaves Shipped. */
export function shippedAtAfterChange(to: IdeaStatus, previous: string | null, now: string): string | null {
  if (to !== "shipped") return null;
  return previous ?? now;
}
