# Task A1a: the three unused Actions secrets are deleted, and decisions A1-D1 and A1-D2 are recorded

Branch `a1-architecture`, pull request #8 (not merged): https://github.com/adriatic/triad-feedbox/pull/8. New head: `64b93b406a47bfa762b756390403bc71851b4d66` (was `e9cbd49`).
No code change, no migration and no dashboard setting changed, and nothing ran against a hosted database.

## Nik's decisions recorded (TRIAD chat, 2026-11-18, after 12:40 PM)

- **A1-D1:** delete all three unused Actions secrets ("I would prefer to add more information later than keeping unneeded data"). Done by gh, see below.
- **A1-D2:** the search limit of 20, applied to the whole board before the tab, is fixed later, with F6's database work or when a board grows; not now. Recorded in `docs/ARCHITECTURE.md` section 7.

## What gh did

Before, `env -u GH_TOKEN ~/gh-cli secret list --repo adriatic/triad-feedbox` listed three names: `SUPABASE_PREVIEW_PUBLISHABLE_KEY`, `SUPABASE_PREVIEW_SECRET_KEY`, `SUPABASE_PREVIEW_URL`.

Deleted in this order, each with `env -u GH_TOKEN ~/gh-cli secret delete <name> --repo adriatic/triad-feedbox`, and each exited with code 0:
1. `SUPABASE_PREVIEW_SECRET_KEY`
2. `SUPABASE_PREVIEW_PUBLISHABLE_KEY`
3. `SUPABASE_PREVIEW_URL`

After, `gh secret list` for the repository printed nothing (exit code 0, zero lines): the repository has no Actions secret. No value was ever read, printed or copied.

## The changes, word for word

`CLAUDE.md` had only the one mention (line 33); the other lines about secrets (rule 3, "Secrets never appear here") do not name these secrets and stay as they are. In `docs/ARCHITECTURE.md`, section 4 had the two mentions; section 1.6 ("CI uses no hosted project and no secret"), section 2 and rule 16 in section 5 say only that CI uses no secret or hosted project, which stays true. Every other part is unchanged. The copy at `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/A1/ARCHITECTURE.md` was refreshed and is identical to the file on the branch.

```diff
diff --git a/CLAUDE.md b/CLAUDE.md
index 19ff609..43ecc81 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -30,7 +30,7 @@ Feedbox is the worked example for an article about TRIAD (Tracker-Recorded, Inde
 5. CI checks (GitHub Actions workflow `CI`): `lint`, `typecheck`, `unit`, `db` (pgTAP tests and `npm run test:checks` on a local Supabase database in Docker on the runner), `e2e` (since F4: Playwright against the app built on the runner and LOCAL Supabase in Docker; a required check since M5). All five, plus Vercel's own status `Vercel`, are required on `main`.
 
 ## Three rules that are never broken
-1. **You never hold a Supabase secret key**: not in a file on the Mac, not in your shell, not in a commit. The preview secret key exists only as the GitHub Actions secret `SUPABASE_PREVIEW_SECRET_KEY`, used only by CI.
+1. **You never hold a Supabase secret key**: not in a file on the Mac, not in your shell, not in a commit. No secret key of a hosted project exists anywhere outside the Supabase dashboard. The three GitHub Actions secrets `SUPABASE_PREVIEW_SECRET_KEY`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY` and `SUPABASE_PREVIEW_URL`, which no workflow ever used, were deleted on 2026-11-18 by Nik's decision A1-D1.
 2. **You never apply a change to a hosted database.** No `supabase login`, no `supabase db push`, no SQL against `feedbox-preview` or `feedbox-prod`. You write the migration; Claude.ai reads it line by line; Nik runs it, first on Preview, then on Production. Local Supabase in Docker (colima) for tests is fine.
 3. **No secrets on the Mac for this project.** No `.env.local` with keys, no Supabase CLI login, no machine-user token. `.gitignore` excludes every `.env*` file.
 
diff --git a/docs/ARCHITECTURE.md b/docs/ARCHITECTURE.md
index e690b8d..b9567f6 100644
--- a/docs/ARCHITECTURE.md
+++ b/docs/ARCHITECTURE.md
@@ -328,10 +328,10 @@ flowchart LR
 | Key | Where it is used | Where it lives |
 |---|---|---|
 | Publishable key of feedbox-preview or feedbox-prod (`sb_publishable_…`) | The app's server only: `lib/supabase/server.ts:12`, `proxy.ts:17-19`, read through `lib/supabase/env.ts:18-20` | Vercel setting `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, per environment (CLAUDE.md, "App settings on Vercel") |
-| Secret key of either hosted project | **Nowhere in the app, CI or the Mac.** No file reads one (`lib/supabase/env.ts:4-5`: "Only the publishable key is ever read") | Only in the Supabase dashboard, plus the GitHub Actions secret below |
+| Secret key of either hosted project | **Nowhere in the app, CI or the Mac.** No file reads one (`lib/supabase/env.ts:4-5`: "Only the publishable key is ever read") | Only in the Supabase dashboard (the GitHub Actions secrets below were deleted on 2026-11-18) |
 | Local development keys (publishable and secret) of the Supabase stack in Docker | Playwright and the e2e helpers, read at run time from `npx supabase status` and never written to a file (`e2e/local-supabase.ts:1-4`). The local secret key is used only by `e2e/helpers.ts:11-13`, to make sign-in links without email, set up a state, and tidy up | Printed by the local stack; valid only at 127.0.0.1 |
 | Resend API keys `feedbox-preview` and `feedbox-prod` | Supabase Auth's SMTP password, one key per project | Only in Supabase and Resend (CLAUDE.md, Resend) |
-| GitHub Actions secrets `SUPABASE_PREVIEW_URL`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY`, `SUPABASE_PREVIEW_SECRET_KEY` (created 2026-11-13) | **Nothing uses them.** `.github/workflows/ci.yml` has no `secrets.` line, and no commit on any branch ever used them in a workflow | GitHub, repository settings (names seen with `gh secret list`; values never read) |
+| GitHub Actions secrets `SUPABASE_PREVIEW_URL`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY`, `SUPABASE_PREVIEW_SECRET_KEY` (created 2026-11-13) | **Deleted on 2026-11-18** by Nik's decision A1-D1 (task A1a). Nothing ever used them: `.github/workflows/ci.yml` has no `secrets.` line, and no commit on any branch ever used them in a workflow | Nowhere. The repository has no Actions secret (`gh secret list` shows none); values were never read |
 
 **About the `NEXT_PUBLIC_` names:**
 
@@ -383,3 +383,4 @@ The database functions for all of these exist (migration lines 457-677) and are
 **Open decisions** (from the F5 report; not repeated here):
 - **F5-D1:** whether everyone may read who the board's owners are, so that the Owner mark shows for every viewer (see 3.10).
 - **F5-D2:** whether to build an end-to-end runner against the hosted Preview (`playwright.config.ts:4-7`).
+- **A1-D2 (decided 2026-11-18, fixed later):** the search limit of 20 applies to the whole board before the tab is chosen (see 3.2); it is fixed later, with F6's database work or when a board grows, not now.
```

## Results

- **Commit:** `64b93b406a47bfa762b756390403bc71851b4d66` on `a1-architecture`, pull request #8: https://github.com/adriatic/triad-feedbox/pull/8
- **CI on 64b93b4:** all green, unchanged from before the deletion.

  | Check | push run 44394318691 | pull request run 44394329834 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on 64b93b4, "Deployment has completed".

## Steps for Nik

No steps for Nik: gh deleted all three secrets.

## Decisions for Nik

No new decision. F5-D1 and F5-D2 stay open as written in the F5 report.
