// F4: sign-in by email link, the first-sign-in name, sign-out and the three
// header states. Runs against LOCAL Supabase only (see e2e/local-supabase.ts).
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";
import { localSupabase } from "./local-supabase";

const sb = localSupabase();
// The admin client uses the LOCAL development secret key, only to make a
// sign-in link without sending email (generateLink) and to tidy up.
const admin: SupabaseClient = createClient(sb.apiUrl, sb.secretKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const run = `${Date.now()}`;
const emails: string[] = [];
function testEmail(label: string): string {
  const email = `e2e+${label}-${run}@feedbox.test`;
  emails.push(email);
  return email;
}

const viewerState = (page: Page) => page.getByTestId("viewer-state");

test.afterAll(async () => {
  // Remove the people this run created (their profile rows go with them).
  const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
  for (const u of data?.users ?? []) {
    if (u.email && emails.includes(u.email)) await admin.auth.admin.deleteUser(u.id);
  }
});

/** A sign-in link made the way the Magic Link template builds it (supabase/templates/magic_link.html). */
async function signInLink(email: string, baseURL: string, next = "/"): Promise<string> {
  const redirectTo = `${baseURL}/auth/confirm?next=${encodeURIComponent(next)}`;
  const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email, options: { redirectTo } });
  if (error) throw error;
  return `${redirectTo}&token_hash=${data.properties.hashed_token}&type=email`;
}

test("visitor, first sign-in with a name, member, owner, sign-out", async ({ page, baseURL }) => {
  // 1. Visitor.
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1, name: "Lumen" })).toBeVisible();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
  await expect(page.getByTestId("idea-list").getByRole("listitem").first()).toBeVisible();

  // 2. The link from the email. Opening it does NOT sign in.
  const email = testEmail("member");
  const link = await signInLink(email, baseURL!, "/changelog");
  await page.goto(link);
  await expect(page.getByRole("heading", { name: "Finish signing in" })).toBeVisible();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");

  // 3. Pressing the button signs in, and the name is asked first.
  await page.getByRole("button", { name: "Finish signing in" }).click();
  await expect(page).toHaveURL(/\/welcome\?next=%2Fchangelog$/);
  await expect(viewerState(page)).toHaveText("Signed in");

  // 4. Nothing else can be done before the name is set.
  await page.goto("/");
  await expect(page).toHaveURL(/\/welcome\?next=%2F$/);
  await page.goto("/ideas/new");
  await expect(page).toHaveURL(/\/welcome\?next=%2Fideas%2Fnew$/);

  // 5. The name is checked on the server (lib/feedbox validateDisplayName), then
  // saved, then on to next. (The browser itself already refuses fewer than 2 or
  // more than 40 characters.)
  await page.getByLabel("Name shown with your ideas").fill("mira@lumen.example");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page.getByText("Use a name, not an email address.")).toBeVisible();
  await expect(viewerState(page)).toHaveText("Signed in");
  await page.getByLabel("Name shown with your ideas").fill("E2E Mira");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/ideas\/new$/);
  await expect(viewerState(page)).toHaveText("Signed in as E2E Mira");

  // 6. The name is asked once: /welcome now goes straight on.
  await page.goto("/welcome?next=%2Fchangelog");
  await expect(page).toHaveURL(/\/changelog$/);
  await expect(viewerState(page)).toHaveText("Signed in as E2E Mira");

  // 7. Owner: the same person, listed in board_owners for this board.
  const { data: user } = await admin.from("profiles").select("id").eq("display_name", "E2E Mira").single();
  const { data: board } = await admin.from("boards").select("id").eq("slug", "lumen").single();
  await admin.from("board_owners").insert({ board_id: board!.id, user_id: user!.id }).throwOnError();
  await page.goto("/");
  await expect(viewerState(page)).toHaveText("Signed in as owner");
  await admin.from("board_owners").delete().eq("user_id", user!.id).throwOnError();
  await page.goto("/");
  await expect(viewerState(page)).toHaveText("Signed in as E2E Mira");

  // 8. Sign out (POST), back on the board as a visitor.
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
  await page.goto("/changelog");
  await expect(viewerState(page)).toHaveText("Viewing as visitor");

  // 9. A link works once.
  await page.goto(link);
  await page.getByRole("button", { name: "Finish signing in" }).click();
  await expect(page.getByText("This sign-in link has expired or was already used. Ask for a new one.")).toBeVisible();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
});

const FIRST_SUBJECT = "Your first Feedbox sign-in link"; // supabase/templates/confirmation.html
const LATER_SUBJECT = "Your Feedbox sign-in link"; // supabase/templates/magic_link.html

/** Fills the real /sign-in form and returns the link from the email Mailpit caught, after checking its subject. */
async function linkFromForm(page: Page, baseURL: string, email: string, subject: string, next: string): Promise<string> {
  const before = await mailIds(email);
  await page.goto(`/sign-in?next=${encodeURIComponent(next)}`);
  await page.getByLabel("Email").fill(email);
  await page.getByRole("button", { name: "Send me a link" }).click();
  await expect(page.getByRole("heading", { name: "Check your email" })).toBeVisible();
  await expect(page.getByTestId("link-sent")).toContainText(email);

  let message: { ID: string; Subject: string } | undefined;
  await expect
    .poll(async () => {
      message = (await mailFor(email)).find((m) => !before.includes(m.ID));
      return message?.Subject;
    }, { timeout: 15_000 })
    .toBe(subject);
  const full = (await (await fetch(`${sb.mailpitUrl}/api/v1/message/${message!.ID}`)).json()) as {
    HTML: string;
    From: { Name: string; Address: string };
  };
  // The sender, as on the hosted projects: Feedbox <feedbox@pactresearch.net> (supabase/config.toml, task C1).
  expect(full.From).toEqual({ Name: "Feedbox", Address: "feedbox@pactresearch.net" });
  const href = /href="([^"]+)"/.exec(full.HTML)?.[1]?.replaceAll("&amp;", "&");
  // The same form for a first and a later sign-in: <site>/auth/confirm?next=…&token_hash=…&type=email
  expect(href).toMatch(
    new RegExp(`^${baseURL.replaceAll(".", "\\.")}/auth/confirm\\?next=${encodeURIComponent(next)}&token_hash=[^&]+&type=email$`),
  );
  return href!;
}

async function mailFor(email: string): Promise<{ ID: string; Subject: string }[]> {
  const res = await fetch(`${sb.mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`);
  return ((await res.json()) as { messages?: { ID: string; Subject: string }[] }).messages ?? [];
}
const mailIds = async (email: string) => (await mailFor(email)).map((m) => m.ID);

/** Opens the link (which must not sign in by itself) and presses the button. */
async function finishSignIn(page: Page, href: string) {
  await page.goto(href);
  await expect(page.getByRole("heading", { name: "Finish signing in" })).toBeVisible();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");
  await page.getByRole("button", { name: "Finish signing in" }).click();
}

test("a brand-new person signs in through the form and the Confirm signup email", async ({ page, baseURL }) => {
  // Local Supabase requires email confirmation, like the hosted projects
  // (supabase/config.toml), so a first sign-in gets the "Confirm signup" email.
  const email = testEmail("new");
  const href = await linkFromForm(page, baseURL!, email, FIRST_SUBJECT, "/changelog");
  await finishSignIn(page, href);
  await expect(page).toHaveURL(/\/welcome\?next=%2Fchangelog$/);
  await page.getByLabel("Name shown with your ideas").fill("E2E New");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(page).toHaveURL(/\/changelog$/);
  await expect(viewerState(page)).toHaveText("Signed in as E2E New");

  const { data } = await admin.auth.admin.listUsers({ perPage: 1000 });
  expect(data.users.find((u) => u.email === email)?.email_confirmed_at).toBeTruthy();
});

test("a person who already exists signs in through the form and the Magic Link email", async ({ page, baseURL }) => {
  // First sign-in, name and sign-out, then a second sign-in as the same person.
  const email = testEmail("again");
  await finishSignIn(page, await linkFromForm(page, baseURL!, email, FIRST_SUBJECT, "/"));
  await page.getByLabel("Name shown with your ideas").fill("E2E Again");
  await page.getByRole("button", { name: "Continue" }).click();
  await expect(viewerState(page)).toHaveText("Signed in as E2E Again");
  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(viewerState(page)).toHaveText("Viewing as visitor");

  const href = await linkFromForm(page, baseURL!, email, LATER_SUBJECT, "/changelog");
  await finishSignIn(page, href);
  // The name is not asked again.
  await expect(page).toHaveURL(/\/changelog$/);
  await expect(viewerState(page)).toHaveText("Signed in as E2E Again");
});

test("a person who exists but never confirmed gets the Confirm signup email again, and it works", async ({ page, baseURL }) => {
  // Nik's case on feedbox-preview: the person was created by an earlier
  // sign-in whose email link was never used.
  const email = testEmail("unconfirmed");
  await admin.auth.admin.createUser({ email, email_confirm: false }).then(({ error }) => { if (error) throw error; });
  const href = await linkFromForm(page, baseURL!, email, FIRST_SUBJECT, "/");
  await finishSignIn(page, href);
  await expect(page).toHaveURL(/\/welcome\?next=%2F$/);
  await expect(viewerState(page)).toHaveText("Signed in");
});

test("every route reads the board as a visitor", async ({ page }) => {
  await page.goto("/?tab=shipped&sort=new");
  await expect(page.getByText(/^Shipped \(\d+\)$/)).toBeVisible();
  const first = page.getByTestId("idea-list").getByRole("link").first();
  const title = await first.textContent();
  await first.click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(title!);
  await expect(page.getByText(/^Posted by /)).toBeVisible();

  await page.goto("/changelog");
  await expect(page.getByRole("heading", { level: 1, name: "Changelog" })).toBeVisible();
  await expect(page.getByTestId("release").first()).toBeVisible();

  await page.goto("/ideas/new");
  await expect(page).toHaveURL(/\/sign-in\?next=%2Fideas%2Fnew$/);
  await page.goto("/changelog/new");
  await expect(page).toHaveURL(/\/sign-in\?next=%2Fchangelog%2Fnew$/);
  await page.goto("/ideas/999999999");
  await expect(page.getByText("This page could not be found.")).toBeVisible();

  const signOut = await page.request.get("/auth/sign-out");
  expect(signOut.status()).toBe(405);
});
