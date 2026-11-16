# Task F4b: a first sign-in must work (the "Confirm signup" email)

Date: 2026-11-15. Branch `f4-auth`, pull request #4 (not merged). New head `731b8a0cb7742770add58ec80ebcd1a606c7cea8`.

## In short

- **The problem:** a person's first sign-in on a hosted project gets Supabase's **Confirm signup** email, not the Magic Link email. In both projects that template is still Supabase's default. Its link goes through supabase.co and comes back to `/auth/confirm?code=…`, which the app does not accept: "This sign-in link is incomplete".
- **The fix:** the Confirm signup email is now code, in `supabase/templates/confirmation.html`. Its link has exactly the same form as the Magic Link email's: `<site>/auth/confirm?next=…&token_hash=…&type=email`. The `/auth/confirm` page is unchanged: it still shows **Finish signing in** and calls `verifyOtp` only when the button is pressed. It does not accept `code=`.
- **Your part:** paste the new subject and body into the **Confirm signup** template of feedbox-preview and of feedbox-prod (F4b-1 to F4b-4). Then test it on the Preview (F4b-5 to F4b-17).

## Why my local tests passed

- **Confirmation was off locally.** Local Supabase had `enable_confirmations = false` in `supabase/config.toml`, the CLI's default. With that setting, Supabase confirms a new person at once and sends the **Magic Link** email even on a first sign-in. The hosted projects require confirmation, so there a new person gets the **Confirm signup** email. The test "the sign-in form sends an email…" did use a brand-new address, but locally that address got the Magic Link email, so the Confirm signup email never appeared in any test.
- **The other test sent no email.** The first test made its link with `generateLink({ type: 'magiclink' })`, so it never involved a template.
- **Found while fixing this:** a freshly started local stack sends Supabase's default emails for its first few seconds. The auth service tries to load the template files before the gateway that serves them is up; its log says "connection refused", and it uses the defaults until it reloads them. CI always starts a fresh stack, so the e2e tests now wait for the Feedbox templates first (see "What changed").

## Documentation source

- **Supabase, "Password-based Auth", section on the PKCE flow:** https://supabase.com/docs/guides/auth/passwords
  - Step 1 changes the **Confirm signup** template to `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email&next={{ .RedirectTo }}`.
  - Step 2's `/auth/confirm` route calls `verifyOtp({ type, token_hash })` with that `type`. So `type=email` is right for a first sign-in.
- **Supabase, "Email Templates":** https://supabase.com/docs/guides/auth/auth-email-templates. It lists the variables `{{ .TokenHash }}` and `{{ .RedirectTo }}`, which are available in every template including Confirm signup.
- **Supabase, "Magic Link" login:** https://supabase.com/docs/guides/auth/passwordless-login/auth-magic-link. It uses the same `type: 'email'` with `token_hash` for the Magic Link.
- **How Feedbox builds the link:** like the Magic Link template from D-12, ours puts `{{ .RedirectTo }}` first, because the app's `RedirectTo` already holds `/auth/confirm?next=…`.
- **Proven locally:** a brand-new person's first sign-in through this template and `verifyOtp({ type: 'email' })` confirms the address and signs the person in (e2e test 2 below).

## Steps for Nik

**F4b-1** On the Mac, in Chrome, open a new tab (cmd+T), go to https://supabase.com/dashboard and click the project **feedbox-preview**. Check that the top of the page shows **feedbox-preview**. In the left menu, click **Authentication**, then **Emails**, then the tab **Templates**, then **Confirm signup**. Select everything in the **Subject** field (click in it, cmd+A) and type:
Your first Feedbox sign-in link
Then click in the body (the **Source** tab of the message body), press cmd+A and paste exactly these four lines:
```html
<h2>Sign in to Feedbox</h2>
<p>This is your first sign-in, so this link also confirms your email address. Click it to finish signing in. It works once and expires in 15 minutes.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email">Sign in to Feedbox</a></p>
<p>If you did not ask for this, you can ignore this email.</p>
```
Click **Save changes**. Expected: a short confirmation that the template was saved.
Result

**F4b-2** On the Mac, in the same Chrome tab, still in feedbox-preview (check the name at the top), press cmd+R to reload. Click **Confirm signup** again. Expected: the subject is "Your first Feedbox sign-in link", and the body's first line is `<h2>Sign in to Feedbox</h2>` and its third line contains `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`. Then click **Magic Link**. Expected: the subject is still "Your Feedbox sign-in link", the body you pasted in D-12.
Result

**F4b-3** On the Mac, in the same Chrome tab, switch to the project **feedbox-prod** with the project selector at the top of the page. Check that the top of the page shows **feedbox-prod**. Click **Authentication**, then **Emails**, then **Templates**, then **Confirm signup**. Select everything in the **Subject** field (cmd+A) and type:
Your first Feedbox sign-in link
Then click in the body (the **Source** tab), press cmd+A and paste exactly the same four lines as in F4b-1:
```html
<h2>Sign in to Feedbox</h2>
<p>This is your first sign-in, so this link also confirms your email address. Click it to finish signing in. It works once and expires in 15 minutes.</p>
<p><a href="{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email">Sign in to Feedbox</a></p>
<p>If you did not ask for this, you can ignore this email.</p>
```
Click **Save changes**. Expected: a short confirmation that the template was saved.
Result

**F4b-4** On the Mac, in the same Chrome tab, still in feedbox-prod (check the name at the top), press cmd+R to reload. Click **Confirm signup** again. Expected: the subject is "Your first Feedbox sign-in link", the first line of the body is `<h2>Sign in to Feedbox</h2>` and the third line contains `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`. Then click **Magic Link**. Expected: the subject is "Your Feedbox sign-in link" and the body is the D-12 text, with the same `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email` link.
Result

**F4b-5** On the Mac, in the same Chrome tab, switch back to the project **feedbox-preview** and check that its name shows at the top. Click **Authentication**, then **Users**. In the search field, type your own email address (the one you sign in to Supabase with). On your row, click the **⋯** menu, choose **Delete user** and confirm. Expected: searching for your address finds no user. (This only removes your test person from feedbox-preview, so that your next sign-in there is a true first sign-in. You have posted nothing there yet, so nothing else is lost.)
Result

**F4b-6** On the Mac, in Chrome (where you are signed in to Vercel), open a new tab (cmd+T), type this address in the address bar and press Return:
https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app
Expected: a plain, unstyled page with the heading "Lumen", a list of ideas, and near the top the words "Viewing as visitor" followed by a "Sign in" link.
Result

**F4b-7** On the Mac, in the same Chrome tab, click **Sign in** at the top of the page. In the field **Email**, type your own email address: the one you sign in to Supabase with. Click **Send me a link**. Expected: the heading changes to "Check your email", with the line "We sent a sign-in link to (your address). It works once and expires in 15 minutes."
Result

**F4b-8** On the Mac, in Mac Mail or in Gmail, find the new email with the subject **Your first Feedbox sign-in link**. It is sent by Supabase Auth, usually within a minute. If it is not in the inbox after 5 minutes, look in the Spam (Junk) folder. Its text starts "Sign in to Feedbox. This is your first sign-in, so this link also confirms your email address." In the email:
- Control-click the link **Sign in to Feedbox**. Choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail in Chrome). Do not click the link itself, because Mac Mail may open it in another browser.
- Go back to the Chrome tab from F4b-6, click the address bar, press cmd+V and press Return.

Expected: the address starts with https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app/auth/confirm?next= and contains `token_hash=` (not `code=`). The page shows the heading "Finish signing in" and a button **Finish signing in**. The top of the page still says "Viewing as visitor" (opening the link alone does not sign you in).
Result

**F4b-9** On the Mac, in the same Chrome tab, click **Finish signing in**. Expected: a page "Welcome to Lumen" with the field **Name shown with your ideas**, and the top of the page says "Signed in".
Result

**F4b-10** On the Mac, in the same Chrome tab, type a display name of 2 to 40 characters in the field **Name shown with your ideas**, for example `Nik I.`, and click **Continue**. Expected: the board page "Lumen" again.
Result

**F4b-11** On the Mac, in the same Chrome tab, read the top of the page, then click **Changelog** at the top and read it again. Expected: both times it says "Signed in as" followed by the name you typed in F4b-10, with a **Sign out** button next to it. The Changelog page shows the heading "Changelog" and the Lumen releases.
Result

**F4b-12** On the Mac, in the same Chrome tab, click **Sign out** at the top of the page. Expected: the board page "Lumen", and the top of the page says "Viewing as visitor" with a "Sign in" link.
Result

**F4b-13** On the Mac, in the same Chrome tab, press cmd+R to reload the page and read the top again. Expected: still "Viewing as visitor".
Result

**F4b-14** On the Mac, in the same Chrome tab, click **Sign in**, type the same email address in **Email** and click **Send me a link**. Then, in Mac Mail or Gmail, find the new email. Expected: its subject is **Your Feedbox sign-in link** (without "first"), because you now exist in feedbox-preview.
Result

**F4b-15** On the Mac, in that email, Control-click **Sign in to Feedbox** and choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail). Go back to the Chrome tab, click the address bar, press cmd+V and press Return. Click **Finish signing in**. Expected: you go straight to the board "Lumen" (your name is not asked again), and the top says "Signed in as" followed by your name from F4b-10.
Result

**F4b-16** On the Mac, in the same Chrome tab, click **Sign out** and then press cmd+R. Expected: the top of the page says "Viewing as visitor".
Result

**F4b-17** On the Mac, in the Notes app, click the note where you wrote the Results of F4b-1 to F4b-16. Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "F4b results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

About these steps:
- **Testing a first sign-in on the Preview:** your address already exists in feedbox-preview after your F4a attempt. So F4b-5 deletes that person, and F4b-7 to F4b-11 become a true first sign-in. F4b-14 and F4b-15 then test a later sign-in. Why not a second email address: Supabase's built-in email sends only to members of your Supabase organisation (F4-D3), so it would not arrive. See F4b-D1.
- **What I could not check:**
  - the dashboard's exact labels ("Subject", "Source", "Save changes", "Delete user"), because I never open a hosted project;
  - the Preview's pages, which sit behind Vercel's sign-in;
  - the Notes menu names and the chat's + button.
- **No rebuild needed:** the templates live in the Supabase dashboard, not in the app. The Preview of `731b8a0` already holds the code.

## What changed

- **`supabase/templates/confirmation.html` (new):** the Confirm signup email, in the same plain wording as `magic_link.html`, with the same single link `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`. Its subject is "Your first Feedbox sign-in link". The subject differs from the Magic Link's so that a test can tell which email was sent; the body tells the person this is their first sign-in.
- **`supabase/config.toml`** (local only):
  - `enable_confirmations = true`, as on the hosted projects;
  - `[auth.email.template.confirmation]` with the new subject and file, next to the existing `magic_link` template.
- **`e2e/auth.spec.ts`:** 5 tests (3 before). Every new test signs in through the real `/sign-in` form and the email that Mailpit caught. Each checks the subject, checks that the link is `<site>/auth/confirm?next=…&token_hash=…&type=email`, and checks that opening it does not sign in.
  1. "visitor, first sign-in with a name, member, owner, sign-out" (unchanged).
  2. **"a brand-new person signs in through the form and the Confirm signup email" (new):** the subject is "Your first Feedbox sign-in link". The test then checks the name page, "Signed in as", and that the address is confirmed in the database.
  3. **"a person who already exists signs in through the form and the Magic Link email" (new):**
     - a first sign-in, a name, then sign-out;
     - a second sign-in, whose subject is "Your Feedbox sign-in link";
     - the second sign-in goes straight to the page without asking the name.
  4. **"a person who exists but never confirmed gets the Confirm signup email again, and it works" (new):** a person created earlier whose link was never used. That would have been your case if you had not clicked the default email's link.
  5. "every route reads the board as a visitor" (unchanged).

  The old "the sign-in form sends an email…" test is replaced by tests 2 and 3.
- **`e2e/global-setup.ts` (new, used by `playwright.config.ts`):** before the tests, it waits until local Supabase sends both Feedbox emails, for a new person and for a known one, and then deletes its warm-up people.
  - On a stack I had just started, its first two attempts got Supabase's defaults ("Confirm your email address", "Your sign-in link"), and the third, about 6 seconds later, got the Feedbox ones. Only then did the tests start.
  - It gives up with a clear message after 2 minutes.
- **`tests/email-templates.test.ts` (new, 3 unit tests):**
  - both templates have exactly one link, the `/auth/confirm` link with `token_hash` and `type=email`, and never `{{ .ConfirmationURL }}`;
  - `config.toml` requires confirmation and uses both templates with their subjects.
- **`app/sign-in/actions.ts`:** a comment only (both templates append to the redirect address).
- **`CLAUDE.md`:** a new section "Sign-in emails", and the layout. **`README.md`:** one line about the two templates.
- **Not changed:**
  - `/auth/confirm`, which still accepts only `token_hash` with `type=email` and signs in only on the button;
  - the database, the migration, every SQL file and `magic_link.html`.

## Results

- **Locally:**
  - `npm run lint`: clean.
  - `npm run typecheck`: clean.
  - `npm test`: 114 passed (111 before, plus 3).
  - `npm run test:e2e`: 5 passed, on a freshly started local stack and on a stack already running.
- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4, new head `731b8a0cb7742770add58ec80ebcd1a606c7cea8` (previous head `73f783c`). **Not merged.**
- **CI at `731b8a0`:** runs 43797981940 (push) and 43797986885 (pull request). Both ended in success.
  - **One rerun:** in the push run, the first try of `e2e` failed before any test ran. On that GitHub runner, Docker could not start local Supabase: "failed to bind host port 0.0.0.0:55422/tcp: address already in use". I re-ran only that job, and it passed (1 m 39 s).

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass (31 s) | pass (18 s) |
  | typecheck | pass (25 s) | pass (26 s) |
  | unit | pass (35 s) | pass (27 s) |
  | db | pass (1 m 9 s) | pass (56 s) |
  | e2e | pass on rerun (1 m 39 s) | pass (1 m 22 s) |
  | Vercel | pass | pass |

- **Vercel status of `731b8a0`:** `success`. Deployment: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/9XVpe6BcVP6UoBCmiUNX5V75envR
- **Preview:** https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

## Decisions for Nik

**F4b-D1: test a true first sign-in on the Preview by deleting your own person in feedbox-preview (step F4b-5). Your decision.**
- **Why it is needed:** your address already exists in feedbox-preview after F4a, so without F4b-5 your next sign-in there is a later sign-in, not a first one. A second address of yours would not get the email, because the built-in email reaches only members of your Supabase organisation (F4-D3).
- **What it removes:** only your person and its profile in feedbox-preview. You have posted no ideas, votes or comments there.
- **If you decide no:** leave out F4b-5. The email in F4b-8 is then "Your Feedbox sign-in link" and F4b-9 goes straight to the board, so the first-sign-in case is proven only by e2e tests 2 and 4.
- **My recommendation:** yes. The broken case appeared only on a hosted project, so it should be seen working on one.

**Still open from F4:** F4-D1 (make `e2e` a required check), F4-D2 (the feedbox-prod URLs and `NEXT_PUBLIC_SITE_URL` must name `https://triad-feedbox-delta.vercel.app`) and F4-D3 (custom email sending before going public). My recommendations there are unchanged.
- **For F4-D1:** this task adds a reason for yes. The bug it fixes is exactly the kind only `e2e` can catch.
- **The one rerun above:** it was a runner fault, not a test fault. It shows that a required `e2e` will now and then need a rerun of one job.
