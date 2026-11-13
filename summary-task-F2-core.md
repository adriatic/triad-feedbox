# Task F2: core library and app skeleton

- Repository: https://github.com/adriatic/triad-feedbox, branch `f2-core` (from `main` at `be88836`)
- Local folder: `/Users/nikolajivancic/Work/triad-feedbox`
- Date: 2026-11-13
- Nothing was merged. No Supabase code was written, no hosted database was touched, and no secret is held on the Mac.

**One thing did not go to plan:** the GitHub token I work with is refused when it tries to open a pull request (`403 Resource not accessible by personal access token`), just as it was refused when creating the repository in F1. The branch is pushed, CI is green on it, and the Vercel Preview is built, but **the pull request must be opened by Nik** (step 1 below, one click). I did not look for other credentials.

---

## Decisions Nik must make

| # | Decision | Recommendation |
|---|---|---|
| F2-D1 | Let the GitHub token open and merge pull requests | **Yes.** Give the token "Pull requests: Read and write" for `adriatic/triad-feedbox` (step 4). Without it, Nik opens every pull request and clicks Squash and merge himself in every merge task; M2 then becomes "Nik clicks, I verify". |
| F2-D2 | Three small rules I added in `lib/feedbox` that F1 did not spell out | **Accept.** (1) An idea that is in a changelog entry must stay Shipped; remove it from the entry first. (2) A display name may not contain "@", so nobody publishes an email address as their name. (3) A changelog entry title has at most 80 characters, and each line at most 280. |

## Steps for Nik

1. **Open the pull request.** In Chrome, signed in to GitHub as `adriatic`, open https://github.com/adriatic/triad-feedbox/compare/main...f2-core?expand=1. Title: `F2: core library and app skeleton`. Description: copy the block in "Pull-request text" at the end of this report. Click **Create pull request**.
2. **Check CI.** On the pull request page, wait about two minutes, then scroll to the checks box near the bottom. `CI / lint`, `CI / typecheck`, `CI / unit` and `Vercel` should all show a green tick. Each CI check appears twice, once for the push and once for the pull request; both should be green.
3. **Open the Preview.** In Chrome, open https://triad-feedbox-git-f2-core-nikolaj-ivancics-projects.vercel.app. Vercel Authentication asks you to sign in; choose **Continue with GitHub**, as `adriatic`. The page shows "Feedbox", one line saying the board is being built, and the list Open, Planned, Building, Shipped. That placeholder is everything F2 shows.
4. **(If you accept F2-D1)** In Chrome, go to https://github.com/settings/personal-access-tokens, open the token that Claude Code uses (the one in `GH_TOKEN` on the Mac), and click **Edit**. Under "Repository access", make sure `adriatic/triad-feedbox` is included. Under "Repository permissions", set **Pull requests** to **Read and write** and **Contents** to **Read and write**. Click **Update**. (If it is a classic token instead, it needs the `repo` scope.)
5. **Approve or not.** Tell Claude.ai "merge" when you are satisfied, together with your answers to F2-D1 and F2-D2. M2 then merges, adds the required status checks below to the `main` ruleset, and confirms Production.

---

## What was built

| Commit | Content |
|---|---|
| `8fc7c0f` | `CLAUDE.md` (first commit on the branch): where the repository and folder are; account `adriatic`; push over SSH; check `git rev-parse --show-toplevel` before git commands; branch, pull-request and merge steps; the three rules (never hold a Supabase secret key, never change a hosted database, no secrets on the Mac); Supabase grants and RLS must be explicit in every migration; where reports go; commands; layout. |
| `dace0c1` | Next.js App Router skeleton: `package.json` (exact versions), `package-lock.json`, `tsconfig.json`, `next.config.ts`, `eslint.config.mjs`, `vitest.config.mts`, `.nvmrc` (Node 24), `.gitignore` (excludes **every** `.env*` file), placeholder `app/layout.tsx` and `app/page.tsx` (light and dark colours from the designs), README run instructions. |
| `ac9f7a2` | `lib/feedbox/`: the core library and 77 unit tests (below). |
| `81246f1` | `.github/workflows/ci.yml`: jobs `lint`, `typecheck`, `unit`, on every push and every pull request. Node from `.nvmrc`, `npm ci`, read-only permissions. |
| `1b31887` | `design/`: `FEEDBOX-DESIGN-BRIEF.md`, `canvas.json` and the six `.dc.html` screens, copied unchanged from `feedbox-inputs`. |
| `691f001` | `CLAUDE.md`: records what the token can and cannot do, and the fallback (compare link, Nik clicks). Also the Preview address pattern. |

### Versions
Next 16.4.6, React 19.3.1, TypeScript 6.0.3, ESLint 9.39.5 with `eslint-config-next` 16.4.6, Vitest 5.1.0 with Vite 8.3.8, Node 24.
- TypeScript 7 exists, but `typescript-eslint` (used by Next's lint rules) supports only up to 6.0, so I used 6.0.3.
- ESLint 10 exists, but `eslint-plugin-react` supports only up to 9.
- `typecheck` runs `next typegen && tsc --noEmit`, so the route types exist in CI without a build.

### `lib/feedbox/` (pure TypeScript)
A lint rule makes it an **error** to import `@supabase/*`, `next`, `react` or `react-dom` in this folder. I tested it with a probe file, which was refused.

| File | Rules it holds (F1 section) | Tests |
|---|---|---|
| `types.ts` | `IdeaStatus`, `Role` (visitor, member, owner), `Viewer`, `Idea`, `ChangelogEntry`, `ChangelogItem`, `Result` | n/a |
| `status.ts` | Open, Planned, Building and Shipped, in order and with those exact words; new ideas start Open; tab and status read from the URL; the owner may move an idea to any other status; the same status again is refused; an idea in a changelog entry stays Shipped; `shipped_at` set and cleared (§2, §8) | 9 |
| `permissions.ts` | Anyone reads; voting, posting and commenting need sign-in **and** a display name; status, merge, hide and changelog are owner only; hidden ideas are seen by owners only; nobody votes on a hidden or merged idea; header labels "Viewing as visitor", "Signed in as …", "Signed in as owner" (§3, §4) | 9 |
| `validation.ts` | Title 4 to 120 characters on one line; details up to 4,000; comment 1 to 2,000; display name 2 to 40 without "@"; slug `^[a-z0-9-]{2,40}$`; changelog title up to 80, line up to 280; release date a real date (§2, §4, §7, §8) | 14 |
| `list.ts` | Tabs show one status each; merged ideas never listed; hidden ideas listed only for owners; tab counts; Top (votes, then newest) and New (newest); sorting never changes its input (§2, design screen 1) | 9 |
| `votes.ts` | Vote adds one, voting again removes it, never below zero; shown at once; a double click is ignored while pending; the server's answer wins; a failure rolls back; label "Vote, 214 votes" (§3) | 7 |
| `next-path.ts` | After sign-in, return only to a path on this site: refuses other sites, `//`, backslashes, control characters, overlong input, and `/sign-in` or `/auth/…` loops (§4) | 5 |
| `merge.ts` | Same board only; not into itself; neither already merged; not into a hidden idea; votes moved so each person counts once, and the target grows only by new voters (§5) | 7 |
| `limits.ts` | 5 ideas, 30 comments and 100 votes per person per hour; the 6th idea is refused with "You are posting quickly. Try again in a few minutes." (§6) | 3 |
| `changelog.ts` | Published entries only, newest release first, the owner's line order, each line with its idea's title and votes; hidden ideas dropped; empty releases dropped; the entry form offers Shipped, visible, unused ideas; picks are checked (§8, design screen 5) | 9 |
| `format.ts` | "Nov 3, 2026" (UTC, so server and browser agree); "1 vote", "214 votes", "1 comment"; "1,204" (design screens) | 5 |

The tests use the invented Lumen board from the brief (the same titles and vote counts as the screens), in `fixtures.test-helper.ts`. Run locally: `npm test`. All 77 pass, and lint, typecheck and `npm run build` are clean.

---

## Pull request

- **Not opened yet:** the token is refused (see the top of this report). Compare link for Nik: https://github.com/adriatic/triad-feedbox/compare/main...f2-core?expand=1
- Branch `f2-core` is at `691f0015ae39bde9bc48060ad900c07e17532056` on GitHub.

## CI check names (for the `main` ruleset in M2)

Workflow `CI`, file `.github/workflows/ci.yml`. The job names to add as required status checks:
1. `lint`
2. `typecheck`
3. `unit`

Optional fourth: `Vercel` (the Preview build status), so a change that does not build on Vercel cannot be merged.

Results on the branch head `691f001`: `lint` success, `typecheck` success, `unit` success, `Vercel` success ("Deployment has completed"), `Vercel Preview Comments` success. The first push, `1b31887`, was also all green: https://github.com/adriatic/triad-feedbox/actions/runs/43478310609

## Vercel Preview

- Address: **https://triad-feedbox-git-f2-core-nikolaj-ivancics-projects.vercel.app**
- Build status: success. The address answers with a redirect to Vercel sign-in, which confirms that it exists and that Deployment Protection is on. A made-up branch address returns 404. I do not hold the bypass secret, so I could not open the page myself; step 3 is Nik's look.
- Production (https://triad-feedbox-delta.vercel.app) still returns 404, as expected, because `main` has no app until M2 merges this.

## Commit hashes

| Where | Commit |
|---|---|
| `main` (unchanged) | `be88836697659277004cb367f8c394c19d9a87be` |
| `f2-core` head | `691f0015ae39bde9bc48060ad900c07e17532056` |
| `f2-core` commits | `8fc7c0f`, `dace0c1`, `ac9f7a2`, `81246f1`, `1b31887`, `691f001` |
| This report on `cc-reports` | given in the closing message (a commit cannot contain its own hash) |

## Notes

- **`npm audit`: 7 moderate findings, all in one chain:** `minimatch` inside `typescript-eslint`, which only runs during linting, never in the app or on Vercel. No fixed version of `typescript-eslint` has been released yet (8.72.2 is the newest and is inside the affected range). I will recheck in F3.
- npm's install-script guard listed `fsevents` (a macOS file-watching helper). I did not approve its install script. It ships ready-built, and everything runs without it.
- Out of scope, and not done: Supabase code, real screens, `TRIAD.md`, `templates/`.
- The F1 setup parts E, F1 to F4, and H were not needed and were not used.

## Check before sending

I searched this report for `TODO`, `TBD`, `XXX`, `{{` and angle-bracket placeholders. The only `<branch>`-style text is in the CLAUDE.md quotation, and it is a pattern. Every item requested by the task is present: the decisions, Steps for Nik (5 steps, Mac and Chrome, including how to open the Preview), what was built, the pull-request link (the compare link, since the token cannot open the pull request), the CI check names, and the commit hashes.

---

## Pull-request text

Copy everything inside the box into the pull request's description.

```
Task F2 (TRIAD). Builds row F2 of the F1 design report, with Nik's F1 decisions applied.

## What is in it
- `CLAUDE.md`: repository, GitHub account, pull-request and merge steps, the three safety rules, where reports go.
- Next.js 16 App Router skeleton in TypeScript, ESLint 9 (flat config), Vitest, `.gitignore` excluding every `.env*` file.
- `lib/feedbox/`: pure TypeScript core library (types, statuses and transitions, permissions, validation, tabs and sorting, vote button state, next-path guard, merge rules, rate limits, changelog grouping, date and count formatting). 77 unit tests, written to read as the rules in F1 sections 3 to 8. A lint rule forbids Supabase, Next and React imports in this folder.
- `.github/workflows/ci.yml`: checks `lint`, `typecheck`, `unit` on every push and pull request.
- `design/`: the design brief, `canvas.json` and the six screen sources.
- A placeholder home page so the Vercel Preview builds.

## Not in it
Any Supabase code, any real screen, `TRIAD.md`, `templates/`.

## Merge
Not to be merged in this task. Merge task M2 follows Nik's "merge" in his chat with Claude.ai.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
