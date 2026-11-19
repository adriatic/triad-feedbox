// CT1: Contact the owner and Messages, against LOCAL Supabase (Lumen seed).
// A visitor is asked to sign in; a member sends a message (with the counter,
// the sentence about what the owner sees, errors in words and the rate limit);
// an owner sees "Messages (n)" in the header, reads the message with the
// sender's name and email, and marks it read and unread. A member and a
// visitor never reach /messages. The test people go at the end, and their
// messages with them.
import type { Browser, BrowserContext } from "@playwright/test";
import { admin, boardId, people, signIn, userId, viewerState } from "./helpers";
import { expect, test, type Page } from "./fixtures";

const who = people("messages");
const RUN = `${Date.now()}`;
const TEXT = `E2E message ${RUN}: please remove my account.`;

let ownerEmail = "";
let memberEmail = "";
let lumen = "";

test.beforeAll(async ({ browser, baseURL }) => {
  ownerEmail = who.email("owner");
  memberEmail = who.email("member");
  for (const [email, name] of [[ownerEmail, "E2E Inbox Owner"], [memberEmail, "E2E Sender"]] as const) {
    const context = await browser.newContext({ baseURL });
    await signIn(await context.newPage(), baseURL!, email, name);
    await context.close();
  }
  lumen = await boardId();
  await admin.from("board_owners").insert({ board_id: lumen, user_id: await userId(ownerEmail) }).throwOnError();
});

test.afterAll(async () => {
  await who.cleanUp();
});

async function as(browser: Browser, baseURL: string, email: string | null): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({ baseURL });
  const page = await context.newPage();
  if (email) await signIn(page, baseURL, email, null);
  return { context, page };
}

async function unreadOnLumen(): Promise<number> {
  const { count } = await admin
    .from("messages")
    .select("id", { count: "exact", head: true })
    .eq("board_id", lumen)
    .is("read_at", null)
    .throwOnError();
  return count ?? 0;
}

const footer = (page: Page) => page.locator("footer.site-footer");
// The form's own alerts (Next.js also has a role="alert" route announcer on every page).
const contactForm = (page: Page) => page.locator("form.contact-form");
/** Links on the page that lead to the page itself (there must be none, tasks F5c, F5d and CT1). */
const selfLinks = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("a[href]")].filter((a) => (a as HTMLAnchorElement).href === location.href).map((a) => a.outerHTML.slice(0, 120)),
  );
const messagesLink = (page: Page) => page.locator("header.site-header").getByTestId("messages-link");

test("a visitor is asked to sign in to contact the owner, and never reaches Messages (task CT1)", async ({ page }) => {
  await page.goto("/");
  await footer(page).getByRole("link", { name: "Contact the owner" }).click();
  await expect(page).toHaveURL(/\/contact$/);
  await expect(page.getByRole("heading", { level: 1, name: "Contact the owner" })).toBeVisible();
  await expect(page.getByText("Only signed-in people can send a message to the owner of Lumen.")).toBeVisible();
  await expect(page.getByLabel("Your message")).toHaveCount(0);
  await expect(messagesLink(page)).toHaveCount(0);

  await page.getByRole("link", { name: "Sign in to contact the owner" }).click();
  await expect(page).toHaveURL(/\/sign-in\?next=%2Fcontact$/);

  await page.goto("/messages");
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("heading", { level: 1, name: "What should Lumen do next?" })).toBeVisible();
});

test("a member sends a message: counter, what the owner sees, sent, errors in words, the limit (task CT1)", async ({ browser, baseURL }) => {
  const { context, page } = await as(browser, baseURL!, memberEmail);
  await expect(viewerState(page)).toHaveText("Signed in as E2E Sender");
  await expect(messagesLink(page)).toHaveCount(0);

  await footer(page).getByRole("link", { name: "Contact the owner" }).click();
  await expect(page).toHaveURL(/\/contact$/);
  const box = page.getByLabel("Your message");
  await expect(box).toHaveValue("");
  await expect(page.getByTestId("message-counter")).toHaveText("0 / 2000");
  await expect(page.getByText("The owner will see your name and the email address you sign in with, so they can answer you.")).toBeVisible();
  expect(await selfLinks(page)).toEqual([]);

  // Only spaces: refused in words, and the text stays.
  await box.fill("   ");
  await page.getByRole("button", { name: "Send message" }).click();
  await expect(contactForm(page).getByRole("alert")).toHaveText("Write your message first.");

  // The message, with spaces around it that are trimmed before it is stored.
  await box.fill(`  ${TEXT}\n`);
  await expect(page.getByTestId("message-counter")).toHaveText(`${[...TEXT].length + 3} / 2000`);
  await page.getByRole("button", { name: "Send message" }).click();
  await expect(contactForm(page).getByRole("status")).toHaveText("Your message was sent to the owner.");
  await expect(page.getByLabel("Your message")).toHaveValue("");
  await expect(page.getByTestId("message-counter")).toHaveText("0 / 2000");
  const member = await userId(memberEmail);
  const { data: stored } = await admin.from("messages").select("body, read_at, author_id").eq("author_id", member).throwOnError();
  expect(stored).toEqual([{ body: TEXT, read_at: null, author_id: member }]);

  // The member cannot read messages, not even their own, and is sent back to the board from /messages.
  await page.goto("/messages");
  await expect(page).toHaveURL(/\/$/);

  // The rate limit: 5 an hour. Four more stored now (as the database owner, which is never limited, but they count).
  await admin
    .from("messages")
    .insert([1, 2, 3, 4].map((n) => ({ board_id: lumen, author_id: member, body: `E2E filler ${RUN} ${n}` })))
    .throwOnError();
  await page.goto("/contact");
  await page.getByLabel("Your message").fill("One more.");
  await page.getByRole("button", { name: "Send message" }).click();
  await expect(contactForm(page).getByRole("alert")).toHaveText("You are posting quickly. Try again in a few minutes.");
  await expect(page.getByLabel("Your message")).toHaveValue("One more.");
  await admin.from("messages").delete().like("body", `E2E filler ${RUN} %`).throwOnError();
  await context.close();
});

test("an owner sees Messages (n), reads the message with the sender's name and email, marks it read and unread (task CT1)", async ({ browser, baseURL }) => {
  const { context, page } = await as(browser, baseURL!, ownerEmail);
  const unread = await unreadOnLumen();
  expect(unread).toBeGreaterThan(0);
  await expect(viewerState(page)).toHaveText("Signed in as owner");
  await expect(messagesLink(page)).toHaveText(`Messages (${unread})`);

  await messagesLink(page).click();
  await expect(page).toHaveURL(/\/messages$/);
  await expect(page.getByRole("heading", { level: 1, name: "Messages" })).toBeVisible();
  // No link to the page you are on: not in the header here, nor anywhere else on it.
  await expect(messagesLink(page)).toHaveCount(0);
  await expect(page.getByTestId("message").first()).toBeVisible();
  expect(await selfLinks(page)).toEqual([]);

  const message = page.getByTestId("message").filter({ hasText: TEXT });
  await expect(message).toHaveCount(1);
  await expect(message).toContainText("E2E Sender");
  await expect(message.getByRole("link", { name: memberEmail })).toHaveAttribute("href", /^mailto:/);
  await expect(message.locator("time")).toHaveText(/^[A-Z][a-z]{2} \d{1,2}, \d{4}$/);
  await expect(message.getByText("New", { exact: true })).toBeVisible();
  // Newest first: the member's message is above the seeded ones.
  await expect(page.getByTestId("message").first()).toContainText(TEXT);

  await message.getByRole("button", { name: "Mark as read" }).click();
  await expect(message.getByRole("button", { name: "Mark as unread" })).toBeVisible();
  await expect(message.getByText("New", { exact: true })).toHaveCount(0);
  const { data: read } = await admin.from("messages").select("read_at").eq("body", TEXT).single().throwOnError();
  expect(read.read_at).not.toBeNull();
  await page.goto("/");
  await expect(messagesLink(page)).toHaveText(unread - 1 > 0 ? `Messages (${unread - 1})` : "Messages");

  await page.goto("/messages");
  await message.getByRole("button", { name: "Mark as unread" }).click();
  await expect(message.getByRole("button", { name: "Mark as read" })).toBeVisible();
  await expect(message.getByText("New", { exact: true })).toBeVisible();
  await page.goto("/");
  await expect(messagesLink(page)).toHaveText(`Messages (${unread})`);
  await context.close();
});

test("the owner's Messages link stays in the header on a phone (390 px) (task CT1)", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ baseURL, viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await signIn(page, baseURL!, ownerEmail, null);
  await expect(messagesLink(page)).toBeVisible();
  await expect(messagesLink(page)).toHaveText(/^Messages/);
  await context.close();
});
