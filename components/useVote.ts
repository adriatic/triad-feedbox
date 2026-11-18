"use client";
import { useCallback, useReducer, useRef, useState } from "react";
import { initialVoteButton, voteReducer, type VoteState } from "@/lib/feedbox";
import { vote } from "./vote-action";

/**
 * Vote and unvote without a page reload (F1 section 3). The click shows at
 * once; the database is the authority. The vote is sent through a server
 * action (task F5b: the browser never calls Supabase itself), which reads the
 * count and the person's own vote back after each change. A second vote by
 * the same person is refused by the primary key on votes (and ignored), so a
 * double click or a second tab never counts twice.
 */
export function useVote(ideaId: number, initial: VoteState) {
  const [button, dispatch] = useReducer(voteReducer, initial, initialVoteButton);
  const [error, setError] = useState<string | null>(null);
  // A second click before React has drawn the first one (a double click) is ignored here.
  const inFlight = useRef(false);

  const send = useCallback(
    async (want: boolean) => {
      dispatch({ type: "click" });
      setError(null);
      let result;
      try {
        result = await vote(ideaId, want);
      } catch {
        result = { ok: false as const, message: "Feedbox could not be reached. Check the connection and try again." };
      }
      if (!result.ok) {
        dispatch({ type: "failed" });
        setError(result.message);
        return;
      }
      dispatch({ type: "confirmed", state: { voted: result.voted, count: result.count } });
    },
    [ideaId],
  );

  const toggle = useCallback(async () => {
    if (inFlight.current || button.pending) return;
    inFlight.current = true;
    try {
      await send(!button.shown.voted);
    } finally {
      inFlight.current = false;
    }
  }, [button.pending, button.shown.voted, send]);

  return { shown: button.shown, pending: button.pending, error, toggle };
}
