# Task F4a: F4 follow-up (the Preview failed; a clear message when a setting is missing)

Date: 2026-11-15. Branch `f4-auth`, pull request #4 (not merged). New head `73f783c140875e2712248c2e1d13e9df39bb02c2`.

## In short

- **The cause:** the F4 Preview failed because Vercel had no Supabase settings when it was built. You added them at 6:39 PM. The new commit `73f783c` made Vercel build a new Preview after that, and its status is success.
- **The fix:** a missing setting is now named in plain words. Before, `proxy.ts` failed with Supabase's own "Your project's URL and Key are required". Now the log says, for example: `Missing environment variable NEXT_PUBLIC_SUPABASE_URL. Set it in Vercel (Settings, Environment Variables) for this environment and build again; see "App settings on Vercel" in CLAUDE.md.`
- **The docs:** CLAUDE.md and README.md now list the four Vercel settings. They also say that a deployment must be built again after a setting changes.
- **Your steps:** F4a-1 to F4a-9 below repeat F4-1 to F4-9 against the new Preview build.

## Steps for Nik

These steps use the Vercel Preview of pull request #4, built from commit `73f783c`: https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

**F4a-1** On the Mac, in Chrome (where you are signed in to Vercel), open a new tab (cmd+T), type this address in the address bar and press Return:
https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app
Expected: a plain, unstyled page with the heading "Lumen", a list of ideas, and near the top the words "Viewing as visitor" followed by a "Sign in" link. (Not "Internal Server Error".)
Result

**F4a-2** On the Mac, in the same Chrome tab, click **Sign in** at the top of the page. In the field **Email**, type your own email address: the one you sign in to Supabase with. Click **Send me a link**. Expected: the heading changes to "Check your email", with the line "We sent a sign-in link to (your address). It works once and expires in 15 minutes."
Result

**F4a-3** On the Mac, in Mac Mail or in Gmail, find the new email with the subject **Your Feedbox sign-in link**. It is sent by Supabase Auth, usually within a minute. If it is not in the inbox after 5 minutes, look in the Spam (Junk) folder. In the email:
- Control-click the link **Sign in to Feedbox**. Choose **Copy Link** (Mac Mail) or **Copy link address** (Gmail in Chrome). Do not click the link itself, because Mac Mail may open it in another browser.
- Go back to the Chrome tab from F4a-1, click the address bar, press cmd+V and press Return.

Expected: the address starts with https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app/auth/confirm?next=. The page shows the heading "Finish signing in" and a button **Finish signing in**. The top of the page still says "Viewing as visitor" (opening the link alone does not sign you in).
Result

**F4a-4** On the Mac, in the same Chrome tab, click **Finish signing in**. Expected: a page "Welcome to Lumen" with the field **Name shown with your ideas**, and the top of the page says "Signed in".
Result

**F4a-5** On the Mac, in the same Chrome tab, type a display name of 2 to 40 characters in the field **Name shown with your ideas**, for example `Nik I.`, and click **Continue**. Expected: the board page "Lumen" again.
Result

**F4a-6** On the Mac, in the same Chrome tab, read the top of the page, then click **Changelog** at the top and read it again. Expected: both times it says "Signed in as" followed by the name you typed in F4a-5, with a **Sign out** button next to it. The Changelog page shows the heading "Changelog" and the Lumen releases.
Result

**F4a-7** On the Mac, in the same Chrome tab, click **Sign out** at the top of the page. Expected: the board page "Lumen", and the top of the page says "Viewing as visitor" with a "Sign in" link.
Result

**F4a-8** On the Mac, in the same Chrome tab, press cmd+R to reload the page and read the top again. Expected: still "Viewing as visitor".
Result

**F4a-9** On the Mac, in the Notes app, click the note where you wrote the Results of F4a-1 to F4a-8. Click **File**, then **Export as PDF…**, choose the Desktop and click **Save**. Then, in Chrome, open the TRIAD chat on Claude.ai, click the **+** button next to the message box and choose the PDF from the Desktop. Send it with the words "F4a results". Expected: the PDF appears in the chat as an attachment and Claude.ai answers.
Result

About these steps:
- **Previews are protected:** they sit behind Vercel Authentication, so I could not open the new Preview's pages myself. Without a Vercel sign-in it answers HTTP 302 to Vercel's sign-in. I checked that the build succeeded. I cannot see whether it picked up your new settings, because a build succeeds with or without them; F4a-1 is the first place this shows.
- **If F4a-1 still gives "Internal Server Error":** the Vercel log now names the setting that is missing for Preview.
- **Not checked on this Mac:**
  - the sender address of Supabase's built-in email;
  - the Notes menu names and the chat's + button.

## What changed

- **`proxy.ts`:** reads the Supabase URL and the publishable key through `supabaseUrl()` and `supabasePublishableKey()` from `lib/supabase/env.ts`, instead of `process.env.…!`.
- **`lib/supabase/browser.ts`:** had the same problem (`process.env.…!`) and now uses the same helpers. The names stay literal inside `env.ts`, so Next still builds the `NEXT_PUBLIC_` values into the browser code.
- **`lib/supabase/env.ts`:** the message now says where to set the value and that the deployment must be built again.
- **The other places that read a setting:**
  - `lib/supabase/server.ts` and `lib/supabase/data.ts` already used the helpers.
  - `lib/supabase/site.ts` reads `NEXT_PUBLIC_SITE_URL`. That setting is optional by design: a Preview uses its own address. It needs no change.
  - `playwright.config.ts` reads only `CI`.
  - No other file reads `process.env`.
- **`lib/supabase/env.test.ts` (new, 5 unit tests):**
  - for each of the three required settings, an empty or missing value throws `Missing environment variable <NAME>.`;
  - set values are returned;
  - no file in `app/`, `components/`, `lib/` or `proxy.ts` reads the Supabase settings or `FEEDBOX_BOARD_SLUG` except through `env.ts`, and none uses `process.env.<NAME>!`.
- **`CLAUDE.md`:** a new section "App settings on Vercel" with a table of the four settings: type Config, the Preview and Production values, and where each value comes from. It also gives the rebuild rule: push a commit, or use **Redeploy** in Vercel.
- **`README.md`:** the same table, short, and the line about the missing-setting message.
- **Not changed:** the database, the migration, every SQL file, `supabase/templates/` and the e2e tests.

The four settings, as now documented:

| Setting | Type | Preview | Production | Value from |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Config | feedbox-preview's URL | feedbox-prod's URL | Supabase dashboard: `https://<project ID>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Config | feedbox-preview's publishable key | feedbox-prod's publishable key | Supabase dashboard, Project Settings, API Keys (`sb_publishable_…`) |
| `FEEDBOX_BOARD_SLUG` | Config | `lumen` | `feedbox` | the board's slug |
| `NEXT_PUBLIC_SITE_URL` | Config | not set | `https://triad-feedbox-delta.vercel.app` | the Production address (see F4-D2) |

## Results

- **Locally:**
  - `npm run lint`: clean.
  - `npm run typecheck`: clean.
  - `npm test`: 111 passed (106 before, plus 5 new).
- **The real app without the settings:** I built it and started it with no Supabase settings, then opened `/`. It gave HTTP 500, and the log said `Error: Missing environment variable NEXT_PUBLIC_SUPABASE_URL. Set it in Vercel (Settings, Environment Variables) for this environment and build again; see "App settings on Vercel" in CLAUDE.md.` Supabase's own message no longer appears.
- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4, new head `73f783c140875e2712248c2e1d13e9df39bb02c2` (previous head `b3c25c1`). **Not merged.**
- **CI:** both runs at `73f783c` succeeded: 43793733816 (push) and 43793738621 (pull request).

  | Check | Result |
  |---|---|
  | lint | pass (18 s; 29 s) |
  | typecheck | pass (15 s; 20 s) |
  | unit | pass (24 s; 19 s) |
  | db | pass (58 s; 1 m 4 s) |
  | e2e | pass (1 m 26 s; 1 m 19 s) |
  | Vercel | pass |
  | Vercel Preview Comments | pass |

- **Vercel status of `73f783c`:** `success`, "Deployment has completed". Deployment: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/H1bGw3WNNVV3reiYDtpxUyoSsnjV. It was built after 6:39 PM, when you added the settings.
- **Preview:** https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

## Decisions for Nik

No new decisions. F4-D1 (make `e2e` a required check), F4-D2 (the feedbox-prod URLs and `NEXT_PUBLIC_SITE_URL` must name `https://triad-feedbox-delta.vercel.app`) and F4-D3 (custom email sending before going public) from the F4 report are still open. My recommendations there are unchanged.
