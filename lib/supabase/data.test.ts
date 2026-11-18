// Task O2 (decision F5-D1): getOwnerIds reads the board's owners through the
// database function board_owner_ids for every viewer, and the idea page still
// loads, with no Owner mark, where that function does not exist yet.
import { afterEach, describe, expect, it, vi } from "vitest";

const rpc = vi.fn();
const getUser = vi.fn();
vi.mock("./server", () => ({ createClient: async () => ({ rpc, auth: { getUser } }) }));

const { getOwnerIds } = await import("./data");

afterEach(() => vi.clearAllMocks());

describe("getOwnerIds", () => {
  it("asks board_owner_ids for the board and returns its owners' ids, without asking who is signed in", async () => {
    rpc.mockResolvedValue({ data: ["ana-id", "bo-id"], error: null });
    const owners = await getOwnerIds("board-1");
    expect(rpc).toHaveBeenCalledWith("board_owner_ids", { p_board_id: "board-1" });
    expect([...owners].sort()).toEqual(["ana-id", "bo-id"]);
    expect(getUser).not.toHaveBeenCalled(); // the same answer for visitors, members and owners
  });

  it("returns no owners, and logs why, when the function does not exist yet (PostgREST PGRST202)", async () => {
    // The error PostgREST gives for a function that is not in its schema cache.
    rpc.mockResolvedValue({
      data: null,
      error: {
        code: "PGRST202",
        message: "Could not find the function public.board_owner_ids(p_board_id) in the schema cache",
        details: null,
        hint: null,
      },
    });
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    await expect(getOwnerIds("board-1")).resolves.toEqual(new Set());
    expect(log).toHaveBeenCalledTimes(1);
    const message = String(log.mock.calls[0]?.[0]);
    expect(message).toContain("PGRST202");
    expect(message).toContain("20261118000000_board_owner_ids.sql");
    log.mockRestore();
  });

  it("returns no owners for a board that has none", async () => {
    rpc.mockResolvedValue({ data: [], error: null });
    await expect(getOwnerIds("board-2")).resolves.toEqual(new Set());
  });
});
