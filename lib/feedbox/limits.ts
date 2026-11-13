import { ok, refuse, type Result } from "./types";

/**
 * Rate limits per person per hour (F1 section 6). The database enforces them with a trigger;
 * the screen uses the same numbers to explain a refusal.
 */
export const RATE_LIMITS = {
  idea: 5,
  comment: 30,
  vote: 100,
} as const;

export type RateLimitedAction = keyof typeof RATE_LIMITS;

export const RATE_LIMIT_MESSAGE = "You are posting quickly. Try again in a few minutes.";

/** `doneInLastHour` is how many of this action the person did in the last 60 minutes. */
export function checkRateLimit(action: RateLimitedAction, doneInLastHour: number): Result {
  return doneInLastHour < RATE_LIMITS[action] ? ok(undefined) : refuse(RATE_LIMIT_MESSAGE);
}
