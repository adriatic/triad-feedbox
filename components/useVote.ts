"use client";
import { useCallback, useReducer, useRef, useState } from "react";
import { initialVoteButton, isDuplicateVote, refusalMessage, voteReducer, type VoteState } from "@/lib/feedbox";
import { createClient } from "@/lib/supabase/browser";

/**
 * Vote and unvote without a page reload (F1 section 3). The click shows at
 * once; the database is the authority. A second vote by the same person is
 * refused by the primary key on votes (and ignored here), so a double click
 * or a second tab never counts twice. After each change the count and the
 * person's own vote are read back from the database.
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
      const supabase = createClient();
      const { data: auth } = await supabase.auth.getUser();
      const userId = auth.user?.id;
      if (!userId) {
        dispatch({ type: "failed" });
        setError("Your session has ended. Sign in again to vote.");
        return;
      }
      const { error: writeError } = want
        ? await supabase.from("votes").insert({ idea_id: ideaId })
        : await supabase.from("votes").delete().eq("idea_id", ideaId).eq("user_id", userId);
      if (writeError && !isDuplicateVote(writeError)) {
        dispatch({ type: "failed" });
        setError(refusalMessage(writeError, want ? "Voting" : "Removing your vote"));
        return;
      }
      const [{ data: idea }, { data: mine }] = await Promise.all([
        supabase.from("ideas").select("vote_count").eq("id", ideaId).maybeSingle(),
        supabase.from("votes").select("idea_id").eq("idea_id", ideaId).eq("user_id", userId).maybeSingle(),
      ]);
      if (!idea) {
        dispatch({ type: "failed" });
        setError("This idea is no longer on the board.");
        return;
      }
      dispatch({ type: "confirmed", state: { voted: mine !== null, count: idea.vote_count } });
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
