# Task A1: the Feedbox architecture description (docs/ARCHITECTURE.md)

Branch `a1-architecture` from `main` at `1a13023` (tag `f5`), pull request #8 (not merged). Head: `e9cbd4976fe8adecd27e203c6bc135611d4505ac`.
There was no code change, no migration and no dashboard setting change, and nothing ran against a hosted database.

## Readiness first

`/Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh` was run on 2026-11-18 before any work, on `main`. Result: READY.

```
PASS macOS version: macOS 27.2.1 (build 26B131). Information only.
PASS Claude desktop app: running (this check cannot see whether its link to Claude.ai works).
PASS Chrome: running.
PASS Claude Code: installed, version 2.1.326.
PASS Node.js: v24.15.0, the major version 24 that the project's .nvmrc asks for.
PASS Project folder: /Users/nikolajivancic/Work/triad-feedbox is a clone of adriatic/triad-feedbox, on branch main.
PASS Git working tree: clean; last commit 1a13023 F5: the screens, styled to the six designs (#7). Information only.
PASS Reports folder: /Users/nikolajivancic/CC reports and tasks exists and has write permission (nothing was written); it holds feedbox-inputs and 139 summary-task reports.
PASS Obsidian vault: /Users/nikolajivancic/Obsidian/pact-web and its TRIAD folder (with TRIAD setup.md) exist.
PASS Docker: running (Docker 29.5.2). The local database itself is not looked at.
PASS GitHub sign-in: the stored GitHub sign-in is account adriatic, and it can read adriatic/triad-feedbox.
PASS git over SSH: the project folder can read branch main from GitHub over SSH (Claude Code pushes over SSH; a push was not tried).
PASS Reports branch: cc-reports exists on GitHub (latest commit dab0b0c).
PASS Required checks: branch main requires lint typecheck unit db e2e Vercel before a merge.
PASS CI on main: the latest CI run passed (commit 1a13023, 2026-11-18T05:58:07Z).
PASS Vercel Production: https://triad-feedbox-delta.vercel.app answers HTTP 200 and the page contains the word Feedbox.
PASS Vercel build of main: Vercel's status on the latest commit of main is success.
PASS Supabase feedbox-preview: the address of project qrbeiveyomidfafivuta answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
PASS Supabase feedbox-prod: the address of project imlitxtkpvrcmijgdsrw answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at).
READY: all 19 checks passed.
```

## What was done

- **`docs/ARCHITECTURE.md` (new, 385 lines, about 4,700 words):**
  - Written from the code at `1a13023`, not from the F1 design report or memory.
  - Every statement names the file it comes from, and the lines where that helps.
  - Two short names are used: "the migration" for `supabase/migrations/20261113000000_feedbox_v1.sql`, and "data.ts" for `lib/supabase/data.ts`.
- **A copy for Claude.ai** is at `/Users/nikolajivancic/CC reports and tasks/feedbox-inputs/A1/ARCHITECTURE.md` (not in git). It is identical to the file at the head commit.
- **CLAUDE.md:** two additions, word for word below.
- **Two commits on the branch:**
  - `05c82d2`: the file and the two CLAUDE.md lines.
  - `e9cbd49`: one sentence added to section 3.2 about the search limit (see finding 2).

## Outline of docs/ARCHITECTURE.md

The numbers are lines per section.

- Title and introduction: what the file is, the two short names, and "if the file and the code disagree, the code is right" (11 lines). Contents (10).
- **1. The parts**
  - 1.1 The visitor's browser (16): no Supabase client in the browser; the client-side files listed.
  - 1.2 The Next.js app (16): a table of pages, server actions, the route handler, `proxy.ts` and the server-side Supabase access; the core library; one board per deployment.
  - 1.3 Supabase (32): the eight tables, RLS and grants, the functions the app calls, the triggers 5a to 5g, the `private` schema, the project marker, and Supabase Auth with the two email templates.
  - 1.4 Resend (6).
  - 1.5 Vercel: Preview and Production (13): a table of addresses, Supabase projects, boards and settings.
  - 1.6 GitHub (11): the repository, the five CI jobs, the six required checks, cc-reports.
  - 1.7 The local setup (11): Docker Supabase and Playwright.
- **2. Who talks to whom** (44): one Mermaid diagram, then the same picture in five numbered sentences.
- **3. The paths**, each a short numbered sequence:
  - 3.1 Reading the board (18)
  - 3.2 Searching (12)
  - 3.3 Similar ideas while typing a title (9)
  - 3.4 Posting an idea (16)
  - 3.5 Voting and unvoting (15)
  - 3.6 Commenting (13)
  - 3.7 Signing in by email link (41): request, email, /auth/confirm with the button, welcome name, session cookies and their refresh
  - 3.8 Signing out (6)
  - 3.9 The changelog (10)
  - 3.10 What an owner sees today (11)
- **4. Keys: which key is used where** (16): the publishable key on the server only; no hosted secret key in the app, CI or the Mac; the local development keys; the Resend keys; the three GitHub Actions secrets and that nothing uses them.
- **5. Rules that hold everywhere** (23): 16 "never" rules, each with the test or check that guards it.
- **6. Where settings live** (10): points to CLAUDE.md "Dashboard settings" and to the environment variables, without values.
- **7. Not built yet, and open decisions** (11): the F6 owner tools and changelog editor; F5-D1 and F5-D2 named in one line each.

**Facts checked by running something while writing:**
- A fresh build of this code (2026-11-18) has no Supabase address, no key and no Supabase client anywhere in `.next/static/`, the files sent to the browser. Six server files do read the settings.
- `gh secret list` shows the names and creation times of three Actions secrets (values are never shown).
- `git log -S` shows that no workflow ever used those secrets.

## CLAUDE.md, the two additions (section "Reports", word for word)

> - **Architecture description (task A1):** every task that changes how the parts connect (a new path, a new service, a key, or a rule in the "never" list) updates `docs/ARCHITECTURE.md` in the same pull request, and its report says so.

> - **Steps check links by clicking (Nik, F5d-3, 2026-11-17):** a step checks what a link does by clicking it, never by Chrome's hover address box, which did not show on Nik's Mac.

## Found while describing the code (not fixed here)

1. **Three GitHub Actions secrets that nothing uses.**
   - The secrets are `SUPABASE_PREVIEW_URL`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY` and `SUPABASE_PREVIEW_SECRET_KEY`, all created 2026-11-13.
   - `.github/workflows/ci.yml` has no `secrets.` line, and no commit on any branch ever used them in a workflow. Since F4, CI runs only against a local Supabase in Docker.
   - CLAUDE.md line 33 still says the preview secret key exists "only as the GitHub Actions secret `SUPABASE_PREVIEW_SECRET_KEY`, used only by CI", which is no longer accurate.
   - An unused copy of a secret key is risk with no use. See decision A1-D1.
2. **The board's search can miss matches on a tab.**
   - `searchIdeaIds` asks `similar_ideas` for at most 20 matches for the whole board (`lib/supabase/data.ts:170-181`; `similar_ideas` itself caps at 20, migration line 716). Only then does the page keep the current tab's ideas (`app/page.tsx:40-43`).
   - So when more than 20 ideas on the board match, a tab can show fewer matches than it has. With today's boards (a dozen or so ideas on Lumen, fewer on feedbox) it cannot happen.
   - It is now described in ARCHITECTURE.md section 3.2. See decision A1-D2.
3. **Owners do not find hidden ideas by search.** The lists show hidden ideas to owners, but `similar_ideas` always leaves hidden ideas out (migration line 713). This is probably fine for F5, but F6's owner tools should decide it. It is described in section 3.10.
4. **The "browser never calls Supabase" guard covers only `e2e/screens.spec.ts`.** `e2e/auth.spec.ts` (sign-in, /auth/confirm, /welcome, sign-out) runs without it. Those pages use only server actions today, but nothing would catch a change there. Recommended: move the guard into a shared fixture that both spec files use, in the next task that touches the e2e tests. No decision is needed unless you want it sooner.
5. **Outdated words, harmless today:**
   - `README.md:7` still says "every page is still bare (unstyled) until the screens are built".
   - `lib/supabase/env.ts:6-7` says that `NEXT_PUBLIC_*` values "are inlined into the browser bundle". That is true of Next.js in general, but no browser code reads them any more.
   - The test name at `lib/supabase/env.test.ts:31` mentions "the browser client", which was deleted in F5b.

   These can be corrected in the next task that touches those files.
6. **Small costs, not faults:**
   - Every board view reads every idea of the board (`getIdeas`, no paging). This is fine at today's size.
   - `getOwnerIds` asks Supabase Auth for the user a second time on each idea page (`lib/supabase/data.ts:146`).

## Results

- **Pull request #8:** https://github.com/adriatic/triad-feedbox/pull/8
- **Head:** `e9cbd4976fe8adecd27e203c6bc135611d4505ac`
- **Local runs:** lint and unit (131 tests) pass. One e2e test was run to make the build checked above.
- **CI on e9cbd49:**

  | Check | push run 44368363637 | pull request run 44368377387 |
  |---|---|---|
  | lint | pass | pass |
  | typecheck | pass | pass |
  | unit | pass | pass |
  | db | pass | pass |
  | e2e | pass | pass |

- **Vercel:** success on e9cbd49, "Deployment has completed".
- **The file at the head commit:** https://github.com/adriatic/triad-feedbox/blob/e9cbd4976fe8adecd27e203c6bc135611d4505ac/docs/ARCHITECTURE.md

## Steps for Nik

Everything happens on the Mac, in Chrome, signed in to github.com as adriatic (the repository is public, so it works without signing in too).

**A1-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://github.com/adriatic/triad-feedbox/blob/e9cbd4976fe8adecd27e203c6bc135611d4505ac/docs/ARCHITECTURE.md

Expected: GitHub shows the file "Feedbox architecture" (docs/ARCHITECTURE.md) with its headings drawn as headings, starting with "How the parts of Feedbox connect, written from the code at commit 1a13023".

Result

**A1-2** In the same tab, click **2. Who talks to whom** in the Contents list near the top.

Expected: the page jumps to section 2, and below its heading GitHub draws a diagram of boxes and arrows (Browser, Email inbox, proxy.ts, Pages and server actions, Supabase Auth, Postgres, Resend SMTP, the repository and CI), not a block of text starting with "flowchart LR". Under the diagram is "The same picture in words" with five numbered sentences.

Result

**A1-3** In the same tab, click **3. The paths** in the Contents list, then read 3.3 "Similar ideas while typing a title (Post an idea)" and 3.5 "Voting and unvoting". Write any question or remark on the line under this step.

Expected: both sections say that the browser calls a server action of the app's own server (`findSimilar` and `vote`), which calls Supabase on the server, and that the browser never calls Supabase itself.

Result

**A1-4** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.

Expected: the PDF is attached in the TRIAD chat.

Result

## Decisions for Nik

**A1-D1: delete the three unused GitHub Actions secrets?** This is your decision.
- `SUPABASE_PREVIEW_SECRET_KEY`, `SUPABASE_PREVIEW_PUBLISHABLE_KEY` and `SUPABASE_PREVIEW_URL` sit in the repository's Actions secrets, and nothing uses them (finding 1).
- **My recommendation:** delete all three, starting with the secret key. A secret key that no job needs only adds risk. If a future task needs one (for example decision F5-D2, a runner against the hosted Preview), it can be added back then, for that use.
- If you agree, a later task gives you the steps in GitHub (Settings, Secrets and variables, Actions). In the same pull request, it corrects CLAUDE.md line 33 and ARCHITECTURE.md section 4.

**A1-D2: make the board's search find every match on a tab?** This is your decision (finding 2).
- A fix needs a new migration: either `similar_ideas` takes a status, or the board stops relying on its limit of 20.
- **My recommendation:** not now. It cannot happen until a board has more than 20 matching ideas. Take it up with F6 or when the feedbox board grows; until then, ARCHITECTURE.md section 3.2 states the limit.

F5-D1 and F5-D2 stay open as written in the F5 report.
