import { describe, expect, it } from "vitest";
import { initialVoteButton, toggled, voteButtonLabel, voteReducer } from "./votes";

describe("Voting (F1 section 3: one vote per person per idea)", () => {
  it("voting adds one, and voting again removes your vote", () => {
    expect(toggled({ voted: false, count: 214 })).toEqual({ voted: true, count: 215 });
    expect(toggled({ voted: true, count: 215 })).toEqual({ voted: false, count: 214 });
  });

  it("the count never goes below zero", () => {
    expect(toggled({ voted: true, count: 0 })).toEqual({ voted: false, count: 0 });
  });

  it("the button shows the click at once, before the server answers", () => {
    const b = voteReducer(initialVoteButton({ voted: false, count: 73 }), { type: "click" });
    expect(b.shown).toEqual({ voted: true, count: 74 });
    expect(b.pending).toBe(true);
  });

  it("a double click is harmless: the second click is ignored while the first is on its way", () => {
    const once = voteReducer(initialVoteButton({ voted: false, count: 73 }), { type: "click" });
    const twice = voteReducer(once, { type: "click" });
    expect(twice).toBe(once);
  });

  it("the server's answer wins, even if it differs from what the screen guessed", () => {
    const b = voteReducer(initialVoteButton({ voted: false, count: 73 }), { type: "click" });
    const settled = voteReducer(b, { type: "confirmed", state: { voted: true, count: 80 } });
    expect(settled).toEqual({ confirmed: { voted: true, count: 80 }, shown: { voted: true, count: 80 }, pending: false });
  });

  it("if the request fails, the button returns to what the server last confirmed", () => {
    const start = initialVoteButton({ voted: true, count: 41 });
    const failed = voteReducer(voteReducer(start, { type: "click" }), { type: "failed" });
    expect(failed).toEqual(start);
  });

  it("the button reads as in the design", () => {
    expect(voteButtonLabel({ voted: false, count: 214 })).toBe("Vote, 214 votes");
    expect(voteButtonLabel({ voted: true, count: 1 })).toBe("Remove your vote, 1 vote");
  });
});
