# Task F4h: Dashboard settings, all checked (docs only)

Date: 2026-11-16. Branch `f4-auth`, pull request #4 (not merged). New head `85780446079627bc3c5404bc33cf94d687910631`.

## In short

- **Filled in:** every "to be checked" row in the CLAUDE.md section "Dashboard settings", from your screenshots of 2026-11-16. No "to be checked" mark is left.
- **The correction:** the Email OTP expiration was `3600` seconds in both projects. You set it to `900` on 2026-11-16 at 9:28 PM (your decision F4f-D1).
- **New rows:** magic links and email OTP on, OTP length 8, and minimum interval per user 60 seconds.
- **Docs only:** `supabase/config.toml` is unchanged, because F4d-D1 is not decided. CI is green.

## Steps for Nik

None. This is a docs-only change; nothing needs to be done or checked in any dashboard for it.

## What changed (CLAUDE.md, "Dashboard settings", Supabase)

- **URL Configuration, feedbox-preview:** checked by Nik, 2026-11-16 5:31 PM.
  - **Site URL:** `http://localhost:3000`.
  - **Redirect URLs:** exactly two, `http://localhost:3000/**` and `https://triad-feedbox-*-nikolaj-ivancics-projects.vercel.app/**`. No leftover team-slug entry.
  - The feedbox-prod rows are unchanged (checked 4:58 PM).
- **New table "Sign In / Providers, Email, and Rate Limits",** replacing "Written in Setup (F1, Part D); not checked since":

  | Setting | feedbox-preview | feedbox-prod | Checked |
  |---|---|---|---|
  | Allow new users to sign up | on | on | prod 5:31 PM, preview 9:13 PM |
  | Confirm email | on | on | prod 5:31 PM, preview 9:13 PM |
  | Enable email provider | on | on | 9:13 PM |
  | Enable magic links and email OTP (new row) | on | on | 9:13 PM |
  | Email OTP length (new row) | 8 digits | 8 digits | 9:13 PM |
  | Email OTP expiration | `900` seconds | `900` seconds | 9:28 PM, after a reload |
  | Rate limit for sending emails | `30` per hour | `30` per hour | prod 5:31 PM, preview 9:13 PM |
  | Minimum interval per user (new row) | `60` seconds | not in the screenshot | preview 9:13 PM |

  - **OTP expiration in the "Checked" column:** "Corrected: it was 3600 in both projects (seen 9:13 PM), not the 900 of Setup step D-9; Nik's decision F4f-D1 set both to 900, to match 'expires in 15 minutes' in both email templates and on the sign-in page."
  - **Dates:** all are 2026-11-16, checked by Nik.
- **"Automatically expose new tables" (on) and "Enable automatic RLS" (off)** moved to their own small table, "Chosen at project creation (Setup, F1)". They were not part of the check of 2026-11-16, and the table says so. They can't be changed afterwards: every migration is written for them, as "Three rules" says.
- **Not changed:**
  - code, tests and `supabase/config.toml`;
  - the Vercel and Resend tables, the email templates and the SMTP rows.

## Results

- **Locally:** `npm test`: 114 passed.
- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4, new head `85780446079627bc3c5404bc33cf94d687910631` (previous head `a8b9004`). **Not merged.**
- **CI at `8578044`:** runs 44024616757 (push) and 44024621856 (pull request) both succeeded.

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass (1 m 8 s) | pass (43 s) |
  | typecheck | pass (50 s) | pass (55 s) |
  | unit | pass (56 s) | pass (1 m 2 s) |
  | db | pass (1 m 54 s) | pass (2 m 44 s) |
  | e2e | pass (2 m 3 s) | pass (2 m 7 s) |
  | Vercel | pass | pass |

- **Vercel status of `8578044`:** `success`. Deployment: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/25YtwfF6qrmFUXdgHcSSx16fSvkk
- **Preview:** https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

## Decisions for Nik

**F4h-D1: feedbox-prod's "Minimum interval per user". Your decision.**
- **The gap:** the screenshot of 2026-11-16 shows it only for feedbox-preview (60 seconds), so the feedbox-prod cell says "not in the screenshot".
- **Why it matters:** it is the shortest wait before the same person can ask for another sign-in email.
- **My recommendation:** yes, look at it with the next screenshots, and expect 60 seconds there too. Then the table has no gap.

**F4h-D2: local Supabase differs in two sign-in values. Your decision.**
- **The differences:** `supabase/config.toml` has `otp_length = 6` and `max_frequency = "1s"`; the hosted projects have 8 digits and 60 seconds.
- **Why they matter little:**
  - the app sends only links and never asks for the code, so the length changes nothing a person sees;
  - the 1 second lets the e2e tests send two emails to one address within a few seconds, which test 3 does.
- **My recommendation:**
  - mirror the OTP length (8) together with F4d-D1, the sender name, in one small task;
  - keep 1 second locally, and say so in the table as "different on purpose", like the email rate limit.

**Still open:**
- **F4d-D1:** local sender name and address. Not decided; `supabase/config.toml` is unchanged.
- **F4-D1:** decided yes. `e2e` becomes a required check in the merge task.
