import { describe, expect, it } from "vitest";
import { blockedBecause, can, canSeeIdea, canVoteOn, viewerStateLabel, type Action } from "./permissions";
import { MEMBER, NEW_MEMBER, OWNER, VISITOR } from "./fixtures.test-helper";

const OWNER_ACTIONS: Action[] = ["changeStatus", "merge", "hide", "writeChangelog"];
const MEMBER_ACTIONS: Action[] = ["vote", "postIdea", "comment"];

describe("Roles and access (F1 section 3)", () => {
  it("anyone may read the board, signed in or not", () => {
    for (const v of [VISITOR, NEW_MEMBER, MEMBER, OWNER]) expect(can(v, "read")).toBe(true);
  });

  it("a visitor who is not signed in can only read", () => {
    for (const a of [...MEMBER_ACTIONS, ...OWNER_ACTIONS]) expect(can(VISITOR, a)).toBe(false);
    expect(blockedBecause(VISITOR, "vote")).toBe("sign-in");
  });

  it("a signed-in person must set a display name before voting, posting or commenting", () => {
    for (const a of MEMBER_ACTIONS) expect(can(NEW_MEMBER, a)).toBe(false);
    expect(blockedBecause(NEW_MEMBER, "postIdea")).toBe("set-name");
  });

  it("a signed-in person with a name may vote, post ideas and comment", () => {
    for (const a of MEMBER_ACTIONS) expect(can(MEMBER, a)).toBe(true);
  });

  it("a signed-in person who is not an owner can never change status, merge, hide or write the changelog", () => {
    for (const a of OWNER_ACTIONS) {
      expect(can(MEMBER, a)).toBe(false);
      expect(blockedBecause(MEMBER, a)).toBe("owner-only");
    }
  });

  it("the owner may do everything", () => {
    for (const a of [...MEMBER_ACTIONS, ...OWNER_ACTIONS]) expect(can(OWNER, a)).toBe(true);
    expect(blockedBecause(OWNER, "merge")).toBeNull();
  });

  it("hidden ideas are seen by owners only", () => {
    const hidden = { hiddenAt: "2026-11-10T00:00:00Z" };
    expect(canSeeIdea(VISITOR, hidden)).toBe(false);
    expect(canSeeIdea(MEMBER, hidden)).toBe(false);
    expect(canSeeIdea(OWNER, hidden)).toBe(true);
    expect(canSeeIdea(VISITOR, { hiddenAt: null })).toBe(true);
  });

  it("nobody votes on a hidden or merged idea", () => {
    expect(canVoteOn(MEMBER, { hiddenAt: null, mergedIntoId: null })).toBe(true);
    expect(canVoteOn(MEMBER, { hiddenAt: "2026-11-10T00:00:00Z", mergedIntoId: null })).toBe(false);
    expect(canVoteOn(OWNER, { hiddenAt: null, mergedIntoId: 6 })).toBe(false);
  });

  it("the header always says which state the viewer is in (design brief)", () => {
    expect(viewerStateLabel(VISITOR, null)).toBe("Viewing as visitor");
    expect(viewerStateLabel(MEMBER, "Sam P.")).toBe("Signed in as Sam P.");
    expect(viewerStateLabel(OWNER, "Ana")).toBe("Signed in as owner");
  });
});
