// F5: the screens, against LOCAL Supabase (Lumen seed). Visitor: read the
// board, tabs, search, sort, an idea, the changelog. Signed in: post an idea
// with similar ideas, vote twice gives one vote, unvote, comment, and the
// rate-limit message. Every change is undone by removing the test people.
import { expect, test, type Page } from "@playwright/test";
import { admin, apiAs, boardId, ideaId, people, signIn, userId, viewerState, voteCount } from "./helpers";

const who = people("screens");
test.afterAll(() => who.cleanUp());

const rows = (page: Page) => page.getByTestId("idea-row");
const titles = (page: Page) => rows(page).locator(".idea-title");
const tab = (page: Page, name: string) => page.getByRole("navigation", { name: "Ideas by status" }).getByRole("link", { name: new RegExp(`^${name} \\d+$`) });
const voteIn = (page: Page, title: string) => rows(page).filter({ hasText: title }).getByRole("button", { name: new RegExp(`: ${title}$`) });

test("a visitor reads the board: tabs, search, sort, an idea and the changelog", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1, name: "What should Lumen do next?" })).toBeVisible();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");

  // Tabs: Open is first; each tab has its count (Lumen seed: 4, 2, 1, 3).
  await expect(tab(page, "Open")).toHaveAttribute("aria-current", "page");
  await expect(tab(page, "Open")).toHaveText("Open 4");
  await expect(tab(page, "Planned")).toHaveText("Planned 2");
  await expect(tab(page, "Building")).toHaveText("Building 1");
  await expect(tab(page, "Shipped")).toHaveText("Shipped 3");
  await expect(titles(page)).toHaveText(["Sync between two laptops", "Search inside attachments", "Share a note by link", "Tag notes by colour"]);
  await expect(rows(page).first().locator(".chip")).toHaveText("Open");
  await expect(rows(page).first()).toContainText("2 comments");

  await tab(page, "Planned").click();
  await expect(page).toHaveURL(/\/\?tab=planned$/);
  await expect(titles(page)).toHaveText(["Dark mode for the editor", "Offline mode"]);
  await expect(rows(page).first().getByRole("link", { name: "Sign in to vote for Dark mode for the editor, 214 votes" })).toBeVisible();

  // Sort: Top (most votes) and New (newest first).
  await tab(page, "Open").click();
  await page.getByRole("link", { name: /^Sort: Top/ }).click();
  await expect(page).toHaveURL(/\/\?sort=new$/);
  await expect(page.getByRole("link", { name: /^Sort: New/ })).toBeVisible();
  await expect(titles(page)).toHaveText(["Tag notes by colour", "Share a note by link", "Search inside attachments", "Sync between two laptops"]);
  await page.getByRole("link", { name: /^Sort: New/ }).click();
  await expect(page).toHaveURL(/\/$/);

  // Search: similar_ideas on titles and details, within the tab; 300 ms after typing.
  const search = page.getByRole("searchbox", { name: "Search ideas" });
  await search.fill("laptop");
  await expect(page).toHaveURL(/\/\?q=laptop$/);
  await expect(titles(page)).toHaveText(["Sync between two laptops"]);
  await search.fill("pdfs");
  await expect(page).toHaveURL(/\/\?q=pdfs$/); // "PDFs" is only in the details of "Search inside attachments"
  await expect(titles(page)).toHaveText(["Search inside attachments"]);
  await search.fill("zx");
  await expect(page.getByText("Type at least 3 characters to search.")).toBeVisible();
  await search.fill("qqqqqq");
  await expect(page.getByText("No ideas match your search.")).toBeVisible();
  await page.goto("/?tab=building&q=markdown");
  await expect(titles(page)).toHaveText(["Export notes to Markdown"]);
  await expect(page.getByRole("searchbox", { name: "Search ideas" })).toHaveValue("markdown");

  // An idea: details, comments newest last, no comment box for a visitor.
  await page.goto("/?tab=planned");
  await page.getByRole("link", { name: "Dark mode for the editor", exact: true }).click();
  await expect(page.getByRole("heading", { level: 1, name: "Dark mode for the editor" })).toBeVisible();
  await expect(page.getByText("Posted by Mira K. on Oct 3, 2026")).toBeVisible();
  await expect(page.getByRole("heading", { name: "3 comments" })).toBeVisible();
  await expect(page.getByTestId("comment").locator(".comment-head")).toContainText(["Tom R.", "Sam P.", "Ana"]);
  await expect(page.getByRole("textbox", { name: "Add a comment" })).toHaveCount(0);
  await page.getByRole("link", { name: "Sign in to comment" }).click();
  await expect(page).toHaveURL(/\/sign-in\?next=%2Fideas%2F\d+$/);
  await expect(page.getByRole("heading", { name: "Sign in to vote and post" })).toBeVisible();

  // The changelog, newest first, each line linking to its idea.
  await page.goto("/changelog");
  await expect(page.getByRole("heading", { level: 1, name: "What shipped in Lumen" })).toBeVisible();
  await expect(page.getByTestId("release").locator(".release-date strong")).toHaveText(["Nov 3, 2026", "Sep 18, 2026"]);
  await page.getByRole("link", { name: "See the idea, 96 votes" }).click();
  await expect(page.getByRole("heading", { level: 1, name: "Keyboard shortcut cheat sheet" })).toBeVisible();
});

test("a visitor on a phone (390 px) sees the board and the header state", async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, colorScheme: "dark" });
  const page = await context.newPage();
  await page.goto("/?tab=planned");
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
  await expect(page.getByRole("link", { name: "Post an idea" })).toBeVisible();
  await expect(titles(page)).toHaveText(["Dark mode for the editor", "Offline mode"]);
  // Nothing is wider than the phone.
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
  // Dark: the page background is the design's dark --bg.
  expect(await page.evaluate(() => getComputedStyle(document.body).backgroundColor)).toBe("rgb(15, 17, 21)");
  await context.close();
});

test("signed in: post with similar ideas, vote twice gives one vote, unvote, comment", async ({ page, baseURL }) => {
  const email = who.email("sam");
  await page.goto("/");
  await page.getByRole("link", { name: "Sign in", exact: true }).click();
  await signIn(page, baseURL!, email, "E2E Sam");
  await expect(viewerState(page)).toHaveText("Signed in as E2E Sam");

  // Post an idea: similar ideas appear while typing (3 or more characters).
  await page.getByRole("link", { name: "Post an idea" }).click();
  await expect(page).toHaveURL(/\/ideas\/new$/);
  const similar = page.getByRole("complementary", { name: "Similar ideas" });
  await expect(similar.getByRole("heading")).toHaveText("Similar ideas appear as you type");
  await page.getByLabel("Title").fill("Sy");
  await page.waitForTimeout(600);
  await expect(similar.getByRole("heading")).toHaveText("Similar ideas appear as you type");
  await page.getByLabel("Title").fill("Sync notes");
  await expect(similar.getByRole("heading")).toHaveText("Similar ideas already on the board");
  const syncCard = similar.getByTestId("similar-idea").filter({ hasText: "Sync between two laptops" });
  await expect(syncCard).toContainText("73");
  await expect(syncCard.locator(".chip")).toHaveText("Open");

  // Each similar idea has its own Vote button.
  await syncCard.getByRole("button", { name: "Vote for Sync between two laptops" }).click();
  await expect(syncCard.getByRole("button", { name: "Remove your vote from Sync between two laptops" })).toHaveAttribute("aria-pressed", "true");
  await expect(syncCard.getByTestId("vote-count")).toHaveText("74");
  await expect.poll(() => voteCount("Sync between two laptops")).toBe(74);

  // Post it anyway; the author's vote is cast with it.
  await page.getByLabel("Title").fill("Sync notes over the local network");
  await page.getByLabel("Details").fill("Two laptops on the same Wi-Fi should sync without a cloud account.\n\nA button is enough.");
  await page.getByRole("button", { name: "Post idea" }).click();
  await expect(page).toHaveURL(/\/ideas\/\d+$/);
  await expect(page.getByRole("heading", { level: 1, name: "Sync notes over the local network" })).toBeVisible();
  await expect(page.getByText("Posted by E2E Sam on")).toBeVisible();
  await expect(page.locator(".idea-body p")).toHaveText(["Two laptops on the same Wi-Fi should sync without a cloud account.", "A button is enough."]);
  await expect(page.getByRole("button", { name: /^Remove your vote, 1 vote: / })).toHaveAttribute("aria-pressed", "true");

  // Vote twice gives one vote: a double click, a reload, and a second insert through the API.
  await page.goto("/");
  const before = await voteCount("Search inside attachments");
  await voteIn(page, "Search inside attachments").dblclick();
  await expect(voteIn(page, "Search inside attachments")).toHaveAttribute("aria-pressed", "true");
  await expect(voteIn(page, "Search inside attachments").getByTestId("vote-count")).toHaveText(String(before + 1));
  await page.reload();
  await expect(voteIn(page, "Search inside attachments")).toHaveAttribute("aria-pressed", "true");
  await expect(voteIn(page, "Search inside attachments").getByTestId("vote-count")).toHaveText(String(before + 1));
  const api = await apiAs(email, baseURL!);
  const second = await api.from("votes").insert({ idea_id: await ideaId("Search inside attachments") });
  expect(second.error?.code).toBe("23505");
  expect(await voteCount("Search inside attachments")).toBe(before + 1);

  // Unvote.
  await voteIn(page, "Search inside attachments").click();
  await expect(voteIn(page, "Search inside attachments")).toHaveAttribute("aria-pressed", "false");
  await expect(voteIn(page, "Search inside attachments").getByTestId("vote-count")).toHaveText(String(before));
  await page.reload();
  await expect(voteIn(page, "Search inside attachments")).toHaveAttribute("aria-pressed", "false");
  expect(await voteCount("Search inside attachments")).toBe(before);

  // Comment: newest last, with the name, and the count goes up.
  await page.getByRole("link", { name: "Search inside attachments", exact: true }).click();
  await expect(page.getByRole("heading", { name: "0 comments" })).toBeVisible();
  await page.getByRole("textbox", { name: "Add a comment" }).fill("Scanned receipts would be the main use for me.");
  await page.getByRole("button", { name: "Post comment" }).click();
  await expect(page.getByRole("heading", { name: "1 comment" })).toBeVisible();
  await expect(page.getByTestId("comment").last()).toContainText("E2E Sam");
  await expect(page.getByTestId("comment").last()).toContainText("Scanned receipts would be the main use for me.");
  await expect(page.getByRole("textbox", { name: "Add a comment" })).toHaveValue("");
  await page.getByRole("button", { name: "Post comment" }).click(); // empty: the browser refuses
  await expect(page.getByTestId("comment")).toHaveCount(1);

  // Sign out.
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
});

test("the rate limits are explained in words (F1 section 6)", async ({ page, baseURL }) => {
  const email = who.email("quick");
  await signIn(page, baseURL!, email, "E2E Quick");
  const me = await userId(email);
  const board = await boardId();
  const target = await ideaId("Tag notes by colour");

  // Five ideas in the last hour (made directly in the local database): the sixth is refused.
  await admin
    .from("ideas")
    .insert([1, 2, 3, 4, 5].map((n) => ({ board_id: board, author_id: me, title: `E2E quick idea ${n}` })))
    .throwOnError();
  await page.goto("/ideas/new");
  await page.getByLabel("Title").fill("One idea too many");
  await page.getByRole("button", { name: "Post idea" }).click();
  await expect(page.locator("p.alert")).toHaveText("You are posting quickly. Try again in a few minutes.");
  await expect(page.getByLabel("Title")).toHaveValue("One idea too many");

  // Thirty comments in the last hour: the next is refused.
  await admin
    .from("comments")
    .insert(Array.from({ length: 30 }, (_, n) => ({ idea_id: target, author_id: me, body: `E2E quick comment ${n}` })))
    .throwOnError();
  await page.goto(`/ideas/${target}`);
  await page.getByRole("textbox", { name: "Add a comment" }).fill("One comment too many");
  await page.getByRole("button", { name: "Post comment" }).click();
  await expect(page.locator("p.alert")).toHaveText("You are posting quickly. Try again in a few minutes.");

  // A hundred votes in the last hour (on the five quick ideas and the author votes): the next is refused.
  const { data: quick } = await admin.from("ideas").select("id").eq("author_id", me).throwOnError();
  const ids = (quick ?? []).map((r) => r.id as number);
  const extra = Array.from({ length: 100 - ids.length }, (_, n) => n);
  // Votes are one per idea per person, so the remaining ones go on ideas made for this purpose.
  const { data: more } = await admin
    .from("ideas")
    .insert(extra.map((n) => ({ board_id: board, author_id: me, title: `E2E vote target ${n}`, status: "planned" as const })))
    .select("id")
    .throwOnError();
  expect(ids.length + (more ?? []).length).toBe(100);
  await page.goto("/");
  await voteIn(page, "Tag notes by colour").click();
  await expect(rows(page).filter({ hasText: "Tag notes by colour" }).locator("p.alert")).toHaveText(
    "You are posting quickly. Try again in a few minutes.",
  );
  await expect(voteIn(page, "Tag notes by colour")).toHaveAttribute("aria-pressed", "false");
});

test("the header shows the owner, and owners see the Owner mark on comments", async ({ page, baseURL }) => {
  const email = who.email("owner");
  await signIn(page, baseURL!, email, "E2E Owner");
  await admin.from("board_owners").insert({ board_id: await boardId(), user_id: await userId(email) }).throwOnError();
  await page.goto(`/ideas/${await ideaId("Dark mode for the editor")}`);
  await expect(viewerState(page)).toHaveText("Signed in as owner");
  await expect(page.getByTestId("comment").filter({ hasText: "Ana" }).locator(".owner-badge")).toHaveText("Owner");
  await expect(page.getByTestId("comment").filter({ hasText: "Tom R." }).locator(".owner-badge")).toHaveCount(0);
  await admin.from("board_owners").delete().eq("user_id", await userId(email)).throwOnError();

  // Until decision F5-D1, the database does not tell anyone else who the owners are.
  await page.getByRole("button", { name: "Sign out" }).click();
  await page.goto(`/ideas/${await ideaId("Dark mode for the editor")}`);
  await expect(page.locator(".owner-badge")).toHaveCount(0);
});
