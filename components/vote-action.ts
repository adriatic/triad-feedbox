"use server";
import { setMyVote, type VoteResult } from "@/lib/supabase/data";

/**
 * The vote button's server action (task F5b). Votes go through the server,
 * with the person's session cookies and the publishable key, like posting an
 * idea or a comment, so the browser never calls Supabase itself.
 */
export async function vote(ideaId: number, want: boolean): Promise<VoteResult> {
  return setMyVote(ideaId, want);
}
