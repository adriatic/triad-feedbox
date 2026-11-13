import { describe, expect, it } from "vitest";
import { RATE_LIMITS, RATE_LIMIT_MESSAGE, checkRateLimit } from "./limits";

describe("Rate limits per person per hour (F1 section 6)", () => {
  it("are 5 ideas, 30 comments and 100 votes", () => {
    expect(RATE_LIMITS).toEqual({ idea: 5, comment: 30, vote: 100 });
  });

  it("the 5th idea in an hour is allowed and the 6th is refused", () => {
    expect(checkRateLimit("idea", 4).ok).toBe(true);
    expect(checkRateLimit("idea", 5)).toEqual({ ok: false, reason: RATE_LIMIT_MESSAGE });
  });

  it("the 31st comment and the 101st vote in an hour are refused", () => {
    expect(checkRateLimit("comment", 29).ok).toBe(true);
    expect(checkRateLimit("comment", 30).ok).toBe(false);
    expect(checkRateLimit("vote", 99).ok).toBe(true);
    expect(checkRateLimit("vote", 100).ok).toBe(false);
  });
});
