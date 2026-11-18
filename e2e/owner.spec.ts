// F6: the owner tools on Idea detail and the changelog editor, against LOCAL
// Supabase (Lumen seed). An owner changes a status, merges two ideas and reads
// the counts, hides and unhides an idea and a comment, and publishes a
// changelog entry. A member and a visitor never see the panel, the hidden
// items or the editor. The Lumen seed ideas are never changed: every idea
// here belongs to a test person and goes with them at the end.
import type { Browser, BrowserContext } from "@playwright/test";
import { admin, boardId, ideaId, people, signIn, userId, viewerState } from "./helpers";
import { expect, test, type Page } from "./fixtures";

const who = people("owner");
const RELEASE = `E2E release ${Date.now()}`;

test.afterAll(async () => {
  await admin.from("changelog_entries").delete().eq("title", RELEASE).throwOnError();
  await who.cleanUp();
});

const TARGET = "E2E owner: the target idea";
const DUPLICATE = "E2E owner: a duplicate idea";
const SHIP = "E2E owner: an idea to ship";

let ownerEmail = "";
let memberEmail = "";

test.beforeAll(async ({ browser, baseURL }) => {
  ownerEmail = who.email("owner");
  memberEmail = who.email("member");
  // Sign both in once, so they exist and have a display name.
  for (const [email, name] of [[ownerEmail, "E2E Owner"], [memberEmail, "E2E Member"]] as const) {
    const context = await browser.newContext({ baseURL });
    await signIn(await context.newPage(), baseURL!, email, name);
    await context.close();
  }
  const board = await boardId();
  const owner = await userId(ownerEmail);
  const member = await userId(memberEmail);
  await admin.from("board_owners").insert({ board_id: board, user_id: owner }).throwOnError();
  // Three ideas by the owner (posting casts the author's vote: 1 vote each).
  await admin
    .from("ideas")
    .insert([TARGET, DUPLICATE, SHIP].map((title) => ({ board_id: board, author_id: owner, title })))
    .throwOnError();
  // The member votes for the duplicate and comments on it: 2 votes, 1 comment.
  await admin.from("votes").insert({ idea_id: await ideaId(DUPLICATE), user_id: member }).throwOnError();
  await admin.from("comments").insert({ idea_id: await ideaId(DUPLICATE), author_id: member, body: "E2E: the same as the other one." }).throwOnError();
});

async function as(browser: Browser, baseURL: string, email: string | null): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({ baseURL });
  const page = await context.newPage();
  if (email) await signIn(page, baseURL, email, null);
  return { context, page };
}

const tools = (page: Page) => page.getByRole("region", { name: "Owner tools" });
const comment = (page: Page, text: string) => page.getByTestId("comment").filter({ hasText: text });

test("an owner changes the status, merges two ideas and reads the counts (task F6)", async ({ page, baseURL }) => {
  await signIn(page, baseURL!, ownerEmail, null);
  await page.goto(`/ideas/${await ideaId(TARGET)}`);
  await expect(viewerState(page)).toHaveText("Signed in as owner");
  await expect(tools(page)).toBeVisible();

  // Status: Open to Planned, through set_idea_status.
  await tools(page).getByLabel("Status").selectOption("planned");
  await tools(page).getByRole("button", { name: "Change status" }).click();
  await expect(tools(page).getByRole("status")).toHaveText("The status is now Planned.");
  await expect(page.locator(".idea-title-line .chip").first()).toHaveText("Planned");
  const { data: planned } = await admin.from("ideas").select("status").eq("title", TARGET).single().throwOnError();
  expect(planned.status).toBe("planned");
  // The same status again is refused in words by the database.
  await tools(page).getByRole("button", { name: "Change status" }).click();
  await expect(tools(page).getByRole("alert")).toHaveText("The idea is already Planned.");

  // Merge the duplicate (2 votes, 1 comment) into the target (1 vote): the owner voted for both.
  const duplicate = await ideaId(DUPLICATE);
  const target = await ideaId(TARGET);
  await page.goto(`/ideas/${duplicate}`);
  await tools(page).getByRole("button", { name: "Merge into another idea" }).click();
  await tools(page).getByLabel(`Merge “${DUPLICATE}” into`).selectOption(String(target));
  const preview = page.getByTestId("merge-preview");
  await expect(preview).toContainText(`goes from 1 vote to between 2 and 3 votes`);
  await expect(preview).toContainText(`1 comment move to “${TARGET}”`);
  await expect(preview).toContainText("There is no undo.");
  await tools(page).getByRole("button", { name: `Merge into “${TARGET}”` }).click();

  // On the target, with the note and the exact count: the owner is counted once, the member is new.
  await expect(page).toHaveURL(new RegExp(`/ideas/${target}\\?merged=${duplicate}$`));
  await expect(page.getByTestId("merged-note")).toHaveText(`“${DUPLICATE}” was merged into this idea. Its votes and comments are here now: 2 votes in all.`);
  await expect(page.getByRole("button", { name: /2 votes/ }).first()).toBeVisible();
  await expect(comment(page, "E2E: the same as the other one.")).toContainText(`From the merged idea “${DUPLICATE}”`);
  const { data: counts } = await admin.from("ideas").select("vote_count, comment_count").eq("id", target).single().throwOnError();
  expect(counts).toEqual({ vote_count: 2, comment_count: 1 });

  // The duplicate's old address leads to the target, with the note.
  await page.goto(`/ideas/${duplicate}`);
  await expect(page).toHaveURL(new RegExp(`/ideas/${target}\\?merged=${duplicate}$`));
  await expect(page.getByTestId("merged-note")).toBeVisible();
  // The duplicate has left the board.
  await page.goto("/?tab=open");
  await expect(page.getByTestId("idea-row").filter({ hasText: DUPLICATE })).toHaveCount(0);
});

test("an owner hides and unhides an idea and a comment; members and visitors never see them (task F6)", async ({ page, browser, baseURL }) => {
  const target = await ideaId(TARGET);
  await signIn(page, baseURL!, ownerEmail, null);
  await page.goto(`/ideas/${target}`);

  // Hide the comment, then the idea.
  await comment(page, "E2E: the same as the other one.").getByRole("button", { name: "Hide comment" }).click();
  await expect(comment(page, "E2E: the same as the other one.").locator(".chip-hidden")).toHaveText("Hidden");
  await tools(page).getByRole("button", { name: "Hide idea" }).click();
  await expect(tools(page).getByRole("status")).toHaveText("The idea is hidden. Only owners see it now.");
  await expect(page.locator(".idea-title-line .chip-hidden")).toHaveText("Hidden");
  await page.goto("/?tab=planned");
  await expect(page.getByTestId("idea-row").filter({ hasText: TARGET }).locator(".chip-hidden")).toHaveText("Hidden");

  // A member and a visitor: the idea is gone from the board, its page is not found, and nothing of the panel shows.
  for (const email of [memberEmail, null]) {
    const { context, page: other } = await as(browser, baseURL!, email);
    await other.goto("/?tab=planned");
    await expect(other.getByTestId("idea-row").filter({ hasText: TARGET })).toHaveCount(0);
    await other.goto(`/ideas/${target}`);
    await expect(other.getByRole("heading", { name: "This page could not be found." })).toBeVisible();
    await context.close();
  }

  // Unhide the idea: back for everyone, but the comment is still hidden from them.
  await page.goto(`/ideas/${target}`);
  await tools(page).getByRole("button", { name: "Unhide idea" }).click();
  await expect(tools(page).getByRole("status")).toHaveText("The idea is visible to everyone again.");
  for (const email of [memberEmail, null]) {
    const { context, page: other } = await as(browser, baseURL!, email);
    await other.goto(`/ideas/${target}`);
    await expect(other.getByRole("heading", { level: 1, name: TARGET })).toBeVisible();
    await expect(comment(other, "E2E: the same as the other one.")).toHaveCount(0);
    await expect(other.getByRole("heading", { name: "0 comments" })).toBeVisible();
    await expect(other.getByRole("region", { name: "Owner tools" })).toHaveCount(0);
    await expect(other.getByRole("button", { name: /hide comment/i })).toHaveCount(0);
    await context.close();
  }

  // Unhide the comment: back for everyone.
  await comment(page, "E2E: the same as the other one.").getByRole("button", { name: "Unhide comment" }).click();
  await expect(comment(page, "E2E: the same as the other one.").locator(".chip-hidden")).toHaveCount(0);
  const { context, page: visitor } = await as(browser, baseURL!, null);
  await visitor.goto(`/ideas/${target}`);
  await expect(comment(visitor, "E2E: the same as the other one.")).toBeVisible();
  await context.close();
});

test("an owner publishes a changelog entry; members and visitors cannot write one (task F6)", async ({ page, browser, baseURL }) => {
  await signIn(page, baseURL!, ownerEmail, null);
  // Ship the idea with the owner tools.
  const ship = await ideaId(SHIP);
  await page.goto(`/ideas/${ship}`);
  await tools(page).getByLabel("Status").selectOption("shipped");
  await tools(page).getByRole("button", { name: "Change status" }).click();
  await expect(tools(page).getByRole("status")).toHaveText("The status is now Shipped.");

  // From the changelog to the editor.
  await page.goto("/changelog");
  await page.getByRole("link", { name: "Write a changelog entry" }).click();
  await expect(page).toHaveURL(/\/changelog\/new$/);
  await expect(page.getByRole("heading", { level: 1, name: "Write the changelog" })).toBeVisible();
  // The Shipped ideas not in any entry, all ticked; the Lumen seed's shipped ideas are all in entries already.
  const pick = page.getByTestId("changelog-pick").filter({ hasText: SHIP });
  await expect(pick.getByRole("checkbox")).toBeChecked();
  for (const other of await page.getByTestId("changelog-pick").filter({ hasNotText: SHIP }).all()) {
    await other.getByRole("checkbox").uncheck();
  }
  await page.getByLabel("Title").fill(RELEASE);
  await page.getByLabel("Release date").fill("2026-11-18");
  // A ticked idea needs its line.
  await page.getByRole("button", { name: "Publish" }).click();
  await expect(page.locator("p.alert")).toHaveText("Every ticked idea needs its line. The note cannot be empty.");
  await page.getByLabel(`Line for ${SHIP}`).fill("Ideas can now be shipped from the owner tools.");
  await page.getByRole("button", { name: "Publish" }).click();

  // Published: on /changelog for everyone.
  await expect(page).toHaveURL(/\/changelog$/);
  const release = page.getByRole("region", { name: RELEASE });
  await expect(release).toContainText("Nov 18, 2026");
  await expect(release).toContainText("Ideas can now be shipped from the owner tools.");
  await expect(release.getByRole("link", { name: "See the idea, 1 vote" })).toHaveAttribute("href", `/ideas/${ship}`);
  // In an entry, the idea stays Shipped: the status cannot be changed.
  await page.goto(`/ideas/${ship}`);
  await expect(tools(page).getByLabel("Status")).toBeDisabled();
  await expect(tools(page)).toContainText("This idea is in a changelog entry, so it stays Shipped and cannot be merged.");

  for (const email of [memberEmail, null]) {
    const { context, page: other } = await as(browser, baseURL!, email);
    await other.goto("/changelog");
    await expect(other.getByRole("region", { name: RELEASE })).toContainText("Ideas can now be shipped from the owner tools.");
    await expect(other.getByRole("link", { name: "Write a changelog entry" })).toHaveCount(0);
    await other.goto("/changelog/new");
    if (email) {
      await expect(other.getByText("Only the owners of Lumen can write the changelog.")).toBeVisible();
      await expect(other.getByRole("button", { name: "Publish" })).toHaveCount(0);
    } else {
      await expect(other).toHaveURL(/\/sign-in\?next=%2Fchangelog%2Fnew$/);
    }
    await context.close();
  }
});
