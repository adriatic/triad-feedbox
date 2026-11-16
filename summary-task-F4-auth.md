# Task F4: sign-in by email link, and every route as a bare page with real data

2026-11-15 · Claude Code · branch `f4-auth` · pull request #4 · head `b3c25c1a990007a0bddc2b9bde059af7b08b7825`

- **Sign-in:** by email link, built as in F1 section 4. `/auth/confirm` signs in only when "Finish signing in" is pressed.
- **Pages:** every route from section 4 and the F4 row exists as a bare page that reads the board named by `FEEDBOX_BOARD_SLUG`.
- **Header:** always shows "Viewing as visitor", "Signed in as <name>" or "Signed in as owner".
- **Tests:** the first Playwright test runs against LOCAL Supabase in Docker. There are 3 tests, green on the Mac and in the new CI job `e2e`.
- **CI and Preview:** all checks are green, and the Vercel Preview for the pull request built.
- **Unchanged:** no database change, no hosted project touched, and no change to the migration or to any script Nik has run. Nothing was merged.

## Readiness check (before starting)

Run at 2026-11-15 3:55 PM (PST), on `main` at `cea809f`:

```
$ /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.325.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit cea809f T1: TRIAD readiness check (#3). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 123 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit 43470fd).
PASS Required checks: branch main requires lint typecheck unit db Vercel before a merge.
PASS CI on main: the latest CI run passed (commit cea809f, 2026-11-15T23:10:15Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
exit=0
```

## Steps for Nik

These steps use the Vercel Preview of pull request #4: https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

**F4-1** On the Mac, in Chrome (where you are signed in to Vercel), open a new tab (cmd+T), type this address in the address bar and press Return:
https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app
Expected: a plain, unstyled page with the heading "Lumen", a list of ideas, and near the top the words "Viewing as visitor" followed by a "Sign in" link.
Result

**F4-2** On the Mac, in the same Chrome tab, click **Sign in** at the top of the page. In the field **Email**, type your own email address: the one you sign in to Supabase with. Click **Send me a link**. Expected: the heading changes to "Check your email", with the line "We sent a sign-in link to (your address). It works once and expires in 15 minutes."
Result

**F4-3** On the Mac, in Mac Mail or in Gmail, find the new email with the subject **Your Feedbox sign-in link**. It is sent by Supabase Auth, from noreply@mail.app.supabase.io, usually within a minute. If it is not in the inbox after 5 minutes, look in the Spam (Junk) folder. In the email:
- Control-click the link **Sign in to Feedbox**. Choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail in Chrome). Do not click the link itself, because Mac Mail may open it in another browser.
- Go back to the Chrome tab from F4-1, click the address bar, press cmd+V and press Return.

Expected: the address starts with https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app/auth/confirm?next=. The page shows the heading "Finish signing in" and a button **Finish signing in**. The top of the page still says "Viewing as visitor" (opening the link alone does not sign you in).
Result

**F4-4** On the Mac, in the same Chrome tab, click **Finish signing in**. Expected: a page "Welcome to Lumen" with the field **Name shown with your ideas**, and the top of the page says "Signed in".
Result

**F4-5** On the Mac, in the same Chrome tab, type a display name of 2 to 40 characters in the field **Name shown with your ideas**, for example `Nik I.`, and click **Continue**. Expected: the board page "Lumen" again.
Result

**F4-6** On the Mac, in the same Chrome tab, read the top of the page, then click **Changelog** at the top and read it again. Expected: both times it says "Signed in as" followed by the name you typed in F4-5, with a **Sign out** button next to it. The Changelog page shows the heading "Changelog" and the Lumen releases.
Result

**F4-7** On the Mac, in the same Chrome tab, click **Sign out** at the top of the page. Expected: the board page "Lumen", and the top of the page says "Viewing as visitor" with a "Sign in" link.
Result

**F4-8** On the Mac, in the same Chrome tab, press cmd+R to reload the page and read the top again. Expected: still "Viewing as visitor".
Result

**F4-9** On the Mac, in the Notes app, click the note where you wrote the Results of F4-1 to F4-8. Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "F4 results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

About these steps:
- **Previews are protected:** they sit behind Vercel Authentication, so I could not open the Preview's pages myself. They answer with Vercel's sign-in redirect. I checked that the deployment succeeded, and checked the same pages against the local database (see Tests).
- **What I could not check on this Mac:**
  - the sender address of Supabase's built-in email;
  - that the Magic Link subject saved in the feedbox-preview dashboard is the one in D-12;
  - the Notes menu names and the chat's + button.

## What was built

### Routes

| Route | What it does |
|---|---|
| `/` | The board: name, tagline, intro, the four tabs with counts (`?tab=`), sort Top/New (`?sort=`), and the ideas with votes and comments. Owners also see hidden ideas, marked [Hidden]. |
| `/ideas/[id]` | One idea: status, votes, comments count, "Posted by <name> on <date>", body, comments with names. A merged idea redirects to the idea it was merged into; an unknown or hidden idea gives "not found". |
| `/ideas/new` | Visitors are sent to `/sign-in?next=%2Fideas%2Fnew`. A signed-in person sees "Posting to Lumen as <name>". The form arrives in F5. |
| `/changelog` | Published releases, newest first, each line linking to its idea (`publishedChangelog` from `lib/feedbox`). |
| `/changelog/new` | Visitors go to sign-in; members see "Only the owners of Lumen can write the changelog."; owners see the drafts. The editor arrives in F6. |
| `/sign-in` | Email field and **Send me a link**, then "Check your email". The `next` path is accepted only through `safeNextPath`. A signed-in person sees "You are signed in". |
| `/auth/confirm` | Shows **Finish signing in** and does nothing on load. Only pressing the button calls `verifyOtp({ type: 'email', token_hash })`. A used or expired link shows "This sign-in link has expired or was already used. Ask for a new one." The page is `noindex` and sends no referrer, because its address holds the token. |
| `/welcome` | The display name, asked once: 2 to 40 characters, no "@" (`validateDisplayName`, and the database checks it again). Until it is set, `proxy.ts` sends every page except `/welcome` and `/auth/*` here. Once it is set, `/welcome` goes straight on. |
| `/auth/sign-out` | POST only: `signOut({ scope: 'local' })`, this device only, then 303 to `/`. A GET answers 405. |

**Header** (`components/Header.tsx`, on every page through `app/layout.tsx`):
- **Text:** "Viewing as visitor", "Signed in as <name>" or "Signed in as owner", from `viewerStateLabel` in `lib/feedbox`.
- **Owner:** the role comes from `is_board_owner(board_id)` in the database.
- **Buttons:** a visitor gets **Sign in**, which remembers the page they were on; a signed-in person gets **Sign out**.

### Files

- **Supabase clients:**
  - `lib/supabase/server.ts` and `lib/supabase/browser.ts`: the `@supabase/ssr` clients, with only the publishable key (`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`).
  - `lib/supabase/env.ts`: reads the three settings.
  - `lib/supabase/database.types.ts`: generated from the local database (`npm run db:types`).
- **Proxy:** `proxy.ts` is Next.js 16's name for middleware. It refreshes the session cookies on every page and does the `/welcome` redirect.
- **Data reads:** `lib/supabase/data.ts` reads the board, the viewer, the ideas, the comments with display names, and the changelog. Everything goes through row-level security, and no email address is ever read.
- **Where the email link points:** `lib/supabase/site.ts` builds the email's return address. Production uses `NEXT_PUBLIC_SITE_URL`. A Preview, or the local app, uses the address the person is on, so the link comes back to the same deployment.
- **Pages:** the `app/` routes above, `components/Header.tsx` and `components/SignInLink.tsx`.
- **Tests:** `e2e/auth.spec.ts`, `e2e/local-supabase.ts`, `playwright.config.ts`, and the CI job `e2e` in `.github/workflows/ci.yml`.
- **New dependencies:** `@supabase/ssr` 0.12.7 (2026-09-08), `@supabase/supabase-js` 2.118.0 (2026-10-15) and `@playwright/test` 1.64.1 (2026-10-14). I chose releases at least two weeks old; the newest Playwright, 1.65.1, was two days old.
- **New npm scripts:** `e2e:supabase` (the local stack without studio, storage and the other unused services), `test:e2e` and `db:types`.
- **`supabase/config.toml`** (local only): the email rate limit went from 2 to 60 per hour, so repeated test runs do not hit it. It never reaches a hosted project.
- **Docs:** `CLAUDE.md` (CI checks, commands, layout) and `README.md` (the three settings, how to run the end-to-end tests).
- **Not changed:**
  - the migration, `supabase/seed.sql`, `supabase/production/`, `supabase/marker/` and `supabase/checks/` (`git diff cea809f b3c25c1` lists none of them);
  - `supabase/templates/magic_link.html`.

### Tests

`e2e/auth.spec.ts` has 3 Playwright tests (Chromium), all green on the Mac and in CI:

1. **"visitor, first sign-in with a name, member, owner, sign-out"** checks, in order:
   - the board as a visitor;
   - a link made with `auth.admin.generateLink` and built exactly as the Magic Link template builds it;
   - opening it does not sign in, and pressing the button does;
   - the name is asked first, and `/` and `/ideas/new` are both sent to `/welcome`;
   - an "@" name is refused, then a good name is saved, and `/welcome` is not asked again;
   - "Signed in as E2E Mira", then "Signed in as owner" while the person is in `board_owners`, then back to "Signed in as E2E Mira";
   - sign-out gives "Viewing as visitor", and a reload keeps it;
   - the same link a second time gives "expired or was already used".
2. **"the sign-in form sends an email whose link /auth/confirm accepts"**: the real `/sign-in` form sends a real email through local Supabase, with the template file that is identical to D-12, to the local mail catcher (Mailpit). The test then checks:
   - the subject is "Your Feedbox sign-in link";
   - the link has the form `<site>/auth/confirm?next=%2Fchangelog&token_hash=…&type=email`;
   - following it and pressing the button signs in, then asks for the name, then goes to `/changelog`.
3. **"every route reads the board as a visitor"**:
   - the Shipped tab and Sort New;
   - an idea page (title and "Posted by");
   - the changelog with releases;
   - `/ideas/new` and `/changelog/new` sending a visitor to sign-in;
   - an unknown idea giving "not found";
   - a GET of `/auth/sign-out` giving 405.

How the tests stay away from the hosted projects:
- **Local only:** `e2e/local-supabase.ts` takes the address and keys from `supabase status` (the stack in Docker). It refuses to run unless the address is `http://127.0.0.1:<port>`, so the tests cannot reach feedbox-preview or feedbox-prod.
- **The local secret key:** the tests use the local development secret key that `supabase status` prints. They use it only for `generateLink`, for adding and removing the test owner, and for deleting the test users afterwards. That key belongs to the Docker stack only; it is read at run time and never written to a file. No hosted key is used anywhere.
- **Test users:** `e2e+…@feedbox.test`. They are deleted after the run; 0 were left in the local database after the run on the Mac.

**Local results:**
- `npm run lint`: clean.
- `npm run typecheck`: clean.
- `npm test`: 106 unit tests passed; nothing new was needed in `lib/feedbox`.
- `npm run test:e2e`: 3 passed.
- `npm run build` without the Supabase settings: every route is built "ƒ (Dynamic)". So no page reads the database at build time.

## The Magic Link template against /auth/confirm (task item 5)

- **The text:** the template in F1 Setup step D-12 is, line for line, the file `supabase/templates/magic_link.html` (compared with `diff`: identical). Its link is `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`.
- **The link the app makes:** the app always sends `emailRedirectTo` = `<site>/auth/confirm?next=<path>`, which always contains "?". The email link is therefore `<site>/auth/confirm?next=<path>&token_hash=…&type=email`. These are exactly the three values `/auth/confirm` reads. Test 2 proves this end to end with that template on the local stack.
- **"Expires in 15 minutes":** this matches the 900-second OTP expiry (D-9 in Setup; locally `otp_expiry = 900`).
- **Nothing in the template has to change.**

One condition is outside the template, in each project's URL settings. If the address in `emailRedirectTo` is not in that project's **Redirect URLs**, Supabase quietly uses the **Site URL** instead. The link then becomes `<Site URL>&token_hash=…`, which is broken (for feedbox-preview: `http://localhost:3000&token_hash=…`).
- **feedbox-preview:** F1 step D-10 adds `https://triad-feedbox-*-nikolaj-ivancics-projects.vercel.app/**`, which covers this pull request's Preview address. Steps F4-1 to F4-8 test exactly this.
- **feedbox-prod:** F1 step D-10 named `https://triad-feedbox.vercel.app`, but Production is `https://triad-feedbox-delta.vercel.app`. See F4-D2.

## Pull request and CI

- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4 ("F4: sign-in by email link, and every route as a bare page"). Head `b3c25c1a990007a0bddc2b9bde059af7b08b7825`, base `main` at `cea809f` (tag `t1`).
- **CI:** runs 43778093965 (push) and 43778110033 (pull request) at the head. All checks passed:

  | Check | Result |
  |---|---|
  | lint | pass (1 m 7 s; 1 m 0 s) |
  | typecheck | pass (56 s; 58 s) |
  | unit | pass (42 s; 1 m 6 s), 106 tests |
  | db | pass (1 m 44 s; 1 m 31 s) |
  | e2e (new) | pass (1 m 57 s; 2 m 4 s), 3 Playwright tests |
  | Vercel | pass (Preview deployment completed) |
  | Vercel Preview Comments | pass |

- **Vercel Preview:** https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app (deployment https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/FHzvo3RSoiShKF6rjusHUFxEcawZ, status success). Without a Vercel sign-in it answers HTTP 302 to Vercel's sign-in, as Deployment Protection intends.
- **Not merged.**

## Decisions for Nik

- **F4-D1: should `e2e` become a required check on `main`? Your decision.** Recommended: **yes**, after this pull request is merged (in M5). It runs only against local Supabase on the runner, takes about 2 minutes, and is the only check that exercises sign-in. Without it, a pull request that breaks sign-in could still be merged with all required checks green. Making it required means adding `e2e` to the ruleset "main", as `db` was added in M3. The readiness check's list of required checks would then gain `e2e` too.
- **F4-D2: the feedbox-prod URL settings before Production sign-in. Your decision.** I cannot see the dashboard or Vercel's values. For sign-in to work on Production after F4 is merged, three settings must all name `https://triad-feedbox-delta.vercel.app` (F1 wrote `https://triad-feedbox.vercel.app`):
  - feedbox-prod, Authentication, URL Configuration: Site URL `https://triad-feedbox-delta.vercel.app`;
  - the same page: Redirect URLs including `https://triad-feedbox-delta.vercel.app/**`;
  - Vercel, Environment Variables: `NEXT_PUBLIC_SITE_URL` (Production) = `https://triad-feedbox-delta.vercel.app`.

  If any of them still names `triad-feedbox.vercel.app`, the email link would be broken or would point at another site. Recommended: Claude.ai checks the three values with you from screenshots before the M5 merge, and changes them only if they differ. Nothing for feedbox-preview needs to change.
- **F4-D3: built-in Supabase email on Production. Your decision.** Supabase's built-in email sends only to members of the Supabase organisation, and only a few emails an hour (F1 section 9). With it, only you, not visitors, can sign in on Production. That is enough for testing F4 to F6. Recommended: keep it through F6, and decide on custom SMTP (F1 decision D4) before the Production board is opened to the public.
