import { statusLabel, type IdeaStatus } from "@/lib/feedbox";

/** Four colours AND four words (design brief: colour is never the only signal). */
export function StatusChip({ status, small = false }: { status: IdeaStatus; small?: boolean }) {
  return <span className={`chip chip-${status}${small ? " chip-small" : ""}`}>{statusLabel(status)}</span>;
}
