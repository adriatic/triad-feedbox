/**
 * Vote button state (F1 section 3). The database is the authority: one row per person per
 * idea. The screen shows the click at once (optimistic) and settles on what the server says.
 */
export interface VoteState {
  voted: boolean;
  count: number;
}

export interface VoteButton {
  /** What the server last confirmed. */
  confirmed: VoteState;
  /** What the button shows now. */
  shown: VoteState;
  /** True while a request is on its way; further clicks are ignored. */
  pending: boolean;
}

export type VoteEvent =
  | { type: "click" }
  | { type: "confirmed"; state: VoteState }
  | { type: "failed" };

export function initialVoteButton(state: VoteState): VoteButton {
  return { confirmed: state, shown: state, pending: false };
}

/** Voting adds one; voting again removes your vote. The count never goes below zero. */
export function toggled(state: VoteState): VoteState {
  return state.voted
    ? { voted: false, count: Math.max(0, state.count - 1) }
    : { voted: true, count: state.count + 1 };
}

export function voteReducer(button: VoteButton, event: VoteEvent): VoteButton {
  switch (event.type) {
    case "click":
      // A double click is harmless: the second click is ignored until the first is settled.
      if (button.pending) return button;
      return { ...button, shown: toggled(button.shown), pending: true };
    case "confirmed":
      return { confirmed: event.state, shown: event.state, pending: false };
    case "failed":
      // Roll back to what the server last confirmed.
      return { ...button, shown: button.confirmed, pending: false };
  }
}

/** Accessible label for the vote button, as in the design ("Vote, 214 votes"). */
export function voteButtonLabel(state: VoteState): string {
  const votes = `${state.count} ${state.count === 1 ? "vote" : "votes"}`;
  return state.voted ? `Remove your vote, ${votes}` : `Vote, ${votes}`;
}
