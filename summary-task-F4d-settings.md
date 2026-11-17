# Task F4d: record the dashboard settings of F4 in the repository (docs only)

Date: 2026-11-16. Branch `f4-auth`, pull request #4 (not merged). New head `a8b9004f8474f0cde1e3e804291e6e718dcf0f7b`.

## In short

- **The change:** CLAUDE.md now has one section, **"Dashboard settings"**. It starts with your rule of 2026-11-15 9:04 PM: "Dashboard settings are code too, and are checked". Under it is one table per service:
  - Vercel;
  - Supabase, with both projects side by side;
  - Resend.
- **Each row** gives the setting, its value or where the value comes from, and who checked it when.
- **Secrets:** every secret is marked **SECRET** and named, never written.
- **README.md:** points to the section.
- **Docs only:** no code, test or setting changed. CI is green.

## Steps for Nik

None. This is a docs-only change: nothing needs to be done or checked in any dashboard for it. The "to be checked" items it lists are in decision F4d-D2.

## What changed

### CLAUDE.md, the new section "Dashboard settings"
- **Its rule:**
  - every setting that lives only in a dashboard is written here, as the source of truth;
  - a task that needs a dashboard change edits this section in the same pull request and gives you the step;
  - after your check, the "Checked" column is updated.
- **Secrets never appear.** A row marked **SECRET** names the value and where it lives. Never write it, ask for it or copy it.
- **Vercel:**
  - **The four app settings:** these are the table from F4a, moved here unchanged. I checked it against your list and it is still right. It now has a "Checked" column ("Nik, added 2026-11-15 6:39 PM", and for `NEXT_PUBLIC_SITE_URL` "Nik, 2026-11-15/16"). Its heading "App settings on Vercel" is kept, because the app's missing-setting message points to it by that name.
  - **Deployment Protection:** Standard Protection, set in Setup C6. It was seen working on 2026-11-15, when a Preview answered with a redirect to Vercel's sign-in.
- **Supabase, sign-in by email** (both projects):
  - **Templates:** Magic Link and Confirm signup, each with its subject and its template file named as the body. I checked them against F4b: the subjects and files are the ones in `supabase/templates/` and `supabase/config.toml`.
  - **Custom SMTP:** on; sender email `feedbox@pactresearch.net`; sender name `Feedbox`; host `smtp.resend.com`; port `465`; username `resend`.
  - **The SMTP password:** marked **SECRET**. It is the Resend key named `feedbox-preview` or `feedbox-prod`.
  - All checked by Nik, 2026-11-15/16.
- **Supabase, URL Configuration:**
  - **feedbox-prod:** Site URL `https://triad-feedbox-delta.vercel.app` and exactly one Redirect URL, `https://triad-feedbox-delta.vercel.app/**`. Checked by Nik, 2026-11-16 4:58 PM.
  - **feedbox-preview:** Site URL `http://localhost:3000`; Redirect URLs `http://localhost:3000/**` and `https://triad-feedbox-*-nikolaj-ivancics-projects.vercel.app/**`. Both are marked **to be checked**, including whether a leftover entry with a team-slug placeholder is still listed.
- **Supabase, settings written in Setup (F1, Part D) and marked "to be checked":**
  - Email provider enabled, new sign-ups allowed, Confirm email on. That last one was seen working on 2026-11-15, when a first sign-in got the Confirm signup email.
  - Email OTP Expiration `900` seconds.
  - Email rate limit `30` per hour.
  - The two project-creation choices ("Automatically expose new tables" on, "Enable automatic RLS" off).
- **Resend:**
  - **Sending domain:** `pactresearch.net`.
  - **API keys:** `feedbox-preview` and `feedbox-prod`, each with Sending access for that domain, marked **SECRET**, each pasted only into its own project's SMTP password. One key per project, so either can be revoked alone.

### README.md
After the Vercel settings table there is one paragraph. It says every other dashboard setting is recorded, with who checked it and when, in the CLAUDE.md section "Dashboard settings", and that secret values are never written down.

### Not changed
- No code, test, SQL, template or `supabase/config.toml`.
- No secret was written or asked for. I searched the diff for secret-key and Resend-key patterns before committing and found none.

## Local Supabase (supabase/config.toml) against these settings

SMTP is not configured locally: Mailpit still catches every email.
- **Already the same:**
  - both templates and their subjects;
  - confirmation required;
  - OTP expiry 900 seconds;
  - Site URL `http://localhost:3000`.
- **Different on purpose:**
  - **Email rate limit:** 60 per hour locally, 30 on the hosted projects. Repeated test runs would otherwise hit the limit.
  - **Redirect URLs:** locally also `http://127.0.0.1:3000/**`, the address Playwright uses. Locally there is no Vercel Preview pattern.
- **Worth mirroring: the sender.** The `[local_smtp]` block (Mailpit) has commented-out `admin_email` and `sender_name` lines. Filling them in would make local emails come from "Feedbox <feedbox@pactresearch.net>", as on the hosted projects. That is not an SMTP setup, and an e2e test could then check the sender too. See F4d-D1.

## Results

- **Locally:** `npm test`: 114 passed (no test changed).
- **Pull request:** https://github.com/adriatic/triad-feedbox/pull/4, new head `a8b9004f8474f0cde1e3e804291e6e718dcf0f7b` (previous head `731b8a0`). **Not merged.**
- **CI at `a8b9004`:** runs 43993059307 (push) and 43993066901 (pull request) both succeeded.

  | Check | Push run | Pull-request run |
  |---|---|---|
  | lint | pass (54 s) | pass (59 s) |
  | typecheck | pass (1 m 5 s) | pass (54 s) |
  | unit | pass (53 s) | pass (1 m 10 s) |
  | db | pass (1 m 48 s) | pass (1 m 54 s) |
  | e2e | pass (1 m 54 s) | pass (2 m 24 s) |
  | Vercel | pass | pass |

- **Vercel status of `a8b9004`:** `success`. Deployment: https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/4d1Y8MYyxALWDgt3qEtH5Ev7tgpa
- **Preview:** https://triad-feedbox-git-f4-auth-nikolaj-ivancics-projects.vercel.app

## Decisions for Nik

**F4d-D1: make local emails come from "Feedbox <feedbox@pactresearch.net>". Your decision.**
- **The change:** in `supabase/config.toml`, block `[local_smtp]`, set `admin_email = "feedbox@pactresearch.net"` and `sender_name = "Feedbox"`. Mailpit still catches everything; no real email is sent.
- **The test:** one e2e check that the sender is right.
- **My recommendation:** yes, in the next build task that touches sign-in (or a small task F4e). It keeps the local stack in line with the table, and costs two lines and one check.

**F4d-D2: check the settings marked "to be checked". Your decision.**
- **What they are:**
  - feedbox-preview's Site URL and Redirect URLs, including whether a leftover team-slug pattern is still listed;
  - the Setup settings: Confirm email, OTP expiry 900, email rate limit 30, new sign-ups allowed.
- **How:** by screenshots, with Claude.ai.
- **Afterwards:** a short docs task fills in the "Checked" column, or corrects a value.
- **My recommendation:** yes, before the merge of pull request #4. Then every row in the section has been checked by you.

**Still open from F4:** F4-D1 (make `e2e` a required check). F4-D2 (the feedbox-prod URLs) is now settled by your check of 2026-11-16 4:58 PM. F4-D3 (custom email) is settled by Resend.
