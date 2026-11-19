# Task CT1: contact the owner (messages to the board's owners)

People can now write to a board's owner. Every page's footer has **Contact the owner**. A signed-in person sends a message, which is stored in the database; the board's owners read it on **Messages**, a page only they see, with the sender's name and sign-in email so they can answer from their own email. No email is sent, and there is no new key, secret or account (Nik's decision of 2026-11-19, 11:42 AM).

- Pull request: https://github.com/adriatic/triad-feedbox/pull/11, branch `ct1-contact`, head **`c9f7e88dd8c32f6bb9fe3617080d026217067a6e`**. Not merged.
- Preview: https://triad-feedbox-git-ct1-contact-nikolaj-ivancics-projects.vercel.app (feedbox-preview's database; /contact cannot send, and /messages fails for an owner, until the apply script below has run there).
- New fingerprint (Feedbox v1 + O2 + F6a + CT1): **`f48a2386ba60d5b8353cc684891bdc25`**. The apply scripts expect the one before it, v1 + O2 + F6a: `081ca51dd5b60c7b98cf8a6309584fb0`, which both hosted projects have now.
- I ran nothing against feedbox-preview or feedbox-prod.

## What was built, file by file

### Database

**`supabase/migrations/20261119120000_messages.sql`** (new, 223 lines, sha256 `72290960b3767ff522a7c32d3c3e23315424dde3cab361de39957bff3ed7f3cb`; no migration that has run was edited)

| Lines | What |
|---|---|
| 40-58 | Table `public.messages`: `id`, `board_id` (cascade from the board), `author_id` (default `auth.uid()`, cascade from the profile), `body`, `created_at`, `read_at` (null until an owner marks it read). Check `messages_body_check`: 1 to 2000 characters, and no space, tab or line break at either end (the app trims first, so "1 to 2000 characters after trimming"). Two indexes. |
| 61-88 | `private.recent_count` replaced: the same three kinds as before, plus `message`. |
| 90-126 | `private.enforce_rate_limit` replaced: the same as before, with the limit for `message` written out (5). |
| 128-130 | Trigger `messages_rate_limit`: at most 5 messages per person per hour, refused with "You are posting quickly. Try again in a few minutes." (detail `rate_limit:message`). |
| 136-167 | `public.board_messages(board)`: security definer, `search_path ''`. It refuses anyone who is not an owner of that board ("Only an owner of this board can read its messages.", 42501). For an owner it returns the board's messages, newest first, each with the sender's display name and the email address from `auth.users`. It is the only way an email reaches anyone. |
| 169-193 | `public.set_message_read(message, read default true)`: security definer, `search_path ''`. "Message not found." (P0002); "Only an owner of this board can do this." (42501). Marking read keeps the first time it was read. |
| 195-205 | Privileges: revoke everything, then grant `select` and `insert (board_id, body)` to `authenticated`, and execute on the two functions to `authenticated` only. `anon` gets nothing. |
| 211-223 | RLS on. `messages_insert_own`: the sender's own message, a display name, and a board that exists. `messages_read_owner`: the board's owners read. No update or delete rule. |

One addition beyond the task text: the insert rule also requires a display name (`has_display_name()`), like posting, voting and commenting. In the app a signed-in person always has one, since `proxy.ts` sends them to /welcome first. It also means the Messages page always has a name to show.

**Other database files:**

- `supabase/seed.sql`: three messages on the Lumen board (Mira K. and Omar S. unread, Tom R. read). They are added only where the table exists, because the tests also seed older states. They are for the local database; the hosted feedbox-preview was seeded in F3 and does not get them (decision CT1-D2).
- `supabase/people/remove-person.sql` and `supabase/checks/person-removal.sql`: moved to the new fingerprint. The comment now says the person's messages go too, through the cascade. The check counts messages in rows 3 and 4.
- `supabase/tests/13_messages.sql` (new, 49 tests):
  - Who may send: not a visitor, not without a display name, not as someone else, not to a board that does not exist, and nobody may set `read_at`.
  - The length rules: empty, only spaces, a space at the start, a line break at the end, and 2001 characters are refused; 2000 characters (counted as characters, not bytes) are accepted, and line breaks inside are kept.
  - Who reads: a visitor nothing, a member nothing (not even their own message), an owner only their own board's messages.
  - `board_messages`: gives the name and email, newest first; refused for a member and for the owner of another board.
  - Read and unread: a second "read" keeps the first time; nobody updates or deletes a message directly.
  - The rate limit: 5 an hour, per person; messages older than an hour and ideas do not count.
  - Removing a person removes their messages.
- `supabase/tests/01_structure.sql`: eleven tables; the new grants; `board_messages` and `set_message_read` callable by signed-in people only; still no email column in any table.
- `lib/supabase/database.types.ts`: regenerated.

### The four pasted SQL scripts (see "SQL scripts" below)

- `supabase/apply/preview-messages.sql` and `supabase/apply/prod-messages.sql` were made like F6a's. Each is one do-block, so it changes all or nothing. It refuses, with nothing changed, if:
  - the project marker is wrong or missing;
  - `public.messages` already exists (a run before, or the script pasted twice into one query, told apart by `xmin`);
  - the database is not v1 + O2 + F6a unchanged (fingerprint `081ca51…`).

  Section 4 holds the migration's statements word for word, and a unit test keeps them identical.
- `supabase/checks/preview-messages.sql` and `supabase/checks/prod-messages.sql` are each one read-only SELECT with the shared blocks and 8 checks:
  1. the project;
  2. the migrations (fingerprint `f48a2386…`; it says "run the apply script first" if it finds `081ca51…`);
  3. the table, with RLS;
  4. who reads and writes;
  5. `board_messages`;
  6. `set_message_read`;
  7. the rate limit;
  8. no message on a board without an owner, where nobody could read it.
- `scripts/test-sql-checks.sh` gets two new sections, G3 (feedbox-prod) and N (feedbox-preview), and these are tested in them:
  - the apply scripts in the wrong project, with the database changed, without F6a, with no marker, pasted twice, and run again: all refused with nothing changed;
  - the checks after the apply PASS, and after 17 kinds of tampering FAIL;
  - a member sends a message; Nik reads it with the name and email; the member is refused; Nik marks it read.

  The removal section now runs on the CT1 state and confirms the person's message is gone. A new section M2 confirms that the migration file gives the same database as the pasted script. Result: all 252 expectations met (it was 202).

### The messages part (self-contained, general names)

- `lib/messages/core.ts` (new): the rules and all the words, in pure TypeScript with no Supabase or Next.js import:
  - `MESSAGE_MAX` 2000 and `MESSAGES_PER_HOUR` 5;
  - `cleanMessage` and `checkMessage`;
  - `messageCounter`, `inboxLabel` and `inboxSummary`;
  - `replyHref`, a `mailto:` link with the subject "Your message to <board>";
  - `MESSAGE_WORDS`.
- `lib/messages/core.test.ts` (new): 13 unit tests.
- `lib/messages/data.ts` (new), on the server only, with the person's own session:
  - `sendMessage`;
  - `countUnread` (logs and returns 0 if the table cannot be read, for example before the migration has run);
  - `getInbox` (`board_messages`);
  - `setMessageRead` (`set_message_read`).
- `lib/feedbox/limits.ts` and `limits.test.ts`: `RATE_LIMITS.message = 5`.

### Screens

- `app/contact/page.tsx`, `ContactForm.tsx` and `actions.ts` (new): the page **Contact the owner**.
  - **A visitor** sees "Only signed-in people can send a message to the owner of Lumen." and the button **Sign in to contact the owner**, which leads to `/sign-in?next=%2Fcontact`.
  - **A signed-in person** sees one line of help, then the box **Your message** (up to 2000 characters, with a counter "0 / 2000"), the sentence "The owner will see your name and the email address you sign in with, so they can answer you." above the button, and **Send message**.
  - **After sending:** "Your message was sent to the owner." and an empty box.
  - **Errors in words, and the text stays in the box:** "Write your message first.", "A message can have at most 2000 characters (now N).", "You are posting quickly. Try again in a few minutes.", or "Sending your message did not work. Reload the page and try again."
- `app/messages/page.tsx`, `MarkButton.tsx` and `actions.ts` (new): the page **Messages**, for owners only. Anyone else, visitors included, is sent to the board. It shows:
  - a summary line ("3 messages, 2 not read yet." and how to answer);
  - then each message, newest first: the sender's name, their email as a `mailto:` link, **New** while unread, the date (`LocalDate`, in the viewer's time zone), the text, and **Mark as read** or **Mark as unread**;
  - "No messages yet." when there are none.

  Marking a message refreshes the header's count on every page.
- `components/Footer.tsx`: **Contact the owner** next to **See what shipped**, separated by "·", on every page except /contact. The changelog page still has no "See what shipped".
- `components/Header.tsx` and `app/layout.tsx`: owners see **Messages**, or **Messages (2)** while two are unread, left of the state pill; not on /messages. On a phone the Changelog link is hidden as before, but Messages stays, on a row of its own under the board name, the state and Sign out.
- `app/globals.css`: a section "Contact the owner and Messages". There is no design for these pages; they use the Post an idea style.

### Tests and screenshots

- `e2e/messages.spec.ts` (new, 4 tests, using the fixture that blocks the browser from Supabase):
  - **A visitor:** clicks the footer link, sees the sentence and the button, the button leads to sign-in, and /messages sends them to the board.
  - **A member:** sees the counter and the sentence; spaces only are refused in words; the message is sent and the box is emptied; the stored text is trimmed; /messages sends them to the board; the 6th message in an hour is refused in words and the text stays; no link on /contact leads to /contact.
  - **An owner:** sees "Messages (n)", reads the message with the name, the `mailto:` email, the date and New, newest first; no link on /messages leads to /messages. Mark as read lowers the header count by one, and Mark as unread restores it.
  - **A phone (390 px):** the owner's Messages link is visible.
- `e2e/screens.spec.ts`: the footer's words and links on the board, the changelog and /contact, and /contact added to the pages checked for links to themselves.
- `e2e/screenshots.spec.ts`: four new states, each light and dark at 1280 and 390 px: `contact-visitor`, `contact-signed-in`, `contact-sent` (the message is removed right after the capture) and `messages-owner`.
- `screenshots/F5/`: regenerated. 16 new images; 80 changed only because the footer now has "Contact the owner" and the owner's header has "Messages (2)".
- `tests/sql-files.test.ts`:
  - the four new scripts in the list;
  - the migration's sha256 pinned;
  - the table has no email column, and `board_messages` is the only function in it that reads `auth.users`;
  - both apply scripts run the migration word for word and expect `081ca51…`;
  - both checks expect `f48a2386…`;
  - the preview and prod files differ only in the project;
  - the removal template and its check expect `f48a2386…`.

### Docs

- `docs/ARCHITECTURE.md` (the CLAUDE.md rule, since this adds a path and a rule):
  - updated: 1.1, 1.2, 1.3 (the table, the two functions, the rate limit, emails), rules 1, 7, 13 and 14, and sections 6 and 7;
  - new: 3.11 "Contact the owner and Messages", rule 22 (a message is read only by the board's owners, and an email is shown only to them, only with that person's messages; nothing is sent by email), and section 8 "The messages part (to carry over to another app)", which lists its files and the six things it needs from the app around it, and how to carry it over to pact-web;
  - corrected in section 7: F5-D2 and F6-D4 are decided (as M11 recorded).
- `README.md`: a new section "Contact the owner"; Owners (reading messages, the two new functions); Privacy (the one place an email is shown, messages stored, removal removes them, a person asks to be removed with Contact the owner).
- `CLAUDE.md`: the layout (routes, `lib/messages/`, the header and footer, `messages.spec.ts`, `apply/`).
- I did not edit the user's manual in Obsidian.

## Checks

Head `c9f7e88`. All six required checks are green on the push run (run 44606585987) and on the pull-request run (run 44606602135):

| Check | push | pull request |
|---|---|---|
| lint | pass | pass |
| typecheck | pass | pass |
| unit | pass | pass |
| db (pgTAP, check scripts, race tests) | pass | pass |
| e2e | pass | pass |
| Vercel | pass, "Deployment has completed" (https://vercel.com/nikolaj-ivancics-projects/triad-feedbox/AysWHATfoeJJg5urxkMhwwzbQEUm) | |

The first head, `e9d5a19` (the same code; only `docs/ARCHITECTURE.md` section 7 changed after it), passed the same checks on push run 44605496347 and pull-request run 44605559266. Its CI log shows pgTAP 360 tests PASS, "SQL checks: all 252 expectations met.", "Race tests: all 56 expectations met." and e2e 21 passed.

Local runs at the head: unit 215, pgTAP 360, SQL harness 252 of 252, race tests 56 of 56, e2e 21 passed (1 skipped: the screenshots, which run only when asked for), lint and typecheck clean, all pasted SQL headers right.

## SQL scripts

All pinned to the head `c9f7e88dd8c32f6bb9fe3617080d026217067a6e`.

| Script | Lines | First line | Last line | sha256 |
|---|---|---|---|---|
| `supabase/apply/preview-messages.sql` | 329 | `-- supabase/apply/preview-messages.sql \| 329 lines \| last line: -- end of preview-messages.sql` | `-- end of preview-messages.sql` | `facbf359534711e6d6869a89f4d963ff2a289d2f1c5d53f4f75511df95aad2dc` |
| `supabase/checks/preview-messages.sql` | 263 | `-- supabase/checks/preview-messages.sql \| 263 lines \| last line: -- end of preview-messages.sql` | `-- end of preview-messages.sql` | `24b2fcc32039aca5f22ecef359ce585f577096e420c9907c92871cf6d4f693cb` |
| `supabase/apply/prod-messages.sql` | 330 | `-- supabase/apply/prod-messages.sql \| 330 lines \| last line: -- end of prod-messages.sql` | `-- end of prod-messages.sql` | `03846a2dafe73d6b45cd3a64fb1c473fe0828b214ff7715293b2418e720f868c` |
| `supabase/checks/prod-messages.sql` | 263 | `-- supabase/checks/prod-messages.sql \| 263 lines \| last line: -- end of prod-messages.sql` | `-- end of prod-messages.sql` | `d9187cb7dfbaa24851904a6c6dca34bd8456389ff5f23d43a94acdb72d1f3c89` |
| `supabase/people/remove-person.sql` (template, changed; not run now) | 178 | `-- supabase/people/remove-person.sql \| 178 lines \| last line: -- end of remove-person.sql` | `-- end of remove-person.sql` | `d345e089f157b5f3a87a88c5fcb91f0e4eddf0048019aa97dc8eae06f1d077cc` |
| `supabase/checks/person-removal.sql` (template, changed; not run now) | 204 | `-- supabase/checks/person-removal.sql \| 204 lines \| last line: -- end of person-removal.sql` | `-- end of person-removal.sql` | `eba5f517345507335e2b56e24c109ea093e753133a2d3df0a9a903b1b741dc63` |
| `supabase/seed.sql` (changed; local only, not run on a hosted project now) | 234 | `-- supabase/seed.sql \| 234 lines \| last line: -- end of seed.sql` | `-- end of seed.sql` | `b2da1b04ee8211c2d63689ec90af8199f95c5a409b01a12df6b23522cb29fc1e` |

The prod apply script has one line more than the preview one: its "Run once" note takes two lines.

Pinned links:

- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/apply/preview-messages.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/checks/preview-messages.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/apply/prod-messages.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/checks/prod-messages.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/people/remove-person.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/checks/person-removal.sql
- https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/migrations/20261119120000_messages.sql (the migration itself, for reading; Nik pastes the apply script)

**Order:**

- feedbox-preview: `preview-messages.sql` (apply), then right after it `supabase/checks/preview-messages.sql`, in the steps below, after Claude.ai has reviewed them.
- feedbox-prod: `prod-messages.sql` and `supabase/checks/prod-messages.sql`, in the merge task, before the merge (as for O2 and F6a), so that Production never runs code that reads a table its database does not have.

After CT1 is applied on a project, that project's older checks (`*-merge-undo.sql`) FAIL on row 2, because the fingerprint now includes the messages. That is expected, as after F6a.

## Draft of Nik's steps (CT1-1 to CT1-31)

What the steps need:

- **Your own email address**, the one you sign in with as the owner of Lumen on the Preview (as in F6b).
- **A second email address that you can read in Mac Mail, which has never signed in on the Feedbox Preview.** It plays the member who is not an owner. The simplest is your own address with `+ct1` added just before the @: for example, for name@example.com it is name+ct1@example.com. Gmail and iCloud Mail deliver such an address to your own inbox, and Feedbox treats it as a new person. If your mail service does not accept a "+" address, use any other address you can read.
- The Preview's address has never been opened before, so Chrome starts there as a visitor.

No Lumen idea is changed. The steps leave one message and one person, "CT1 Member", on feedbox-preview.

---

## Steps for Nik

Paste this section into Mac Notes. Each step is one action with one expected result. Under each step, write what you saw after "Result".

**CT1-1** On the Mac, in Chrome, open a new tab (⌘T) and go to https://supabase.com/dashboard/project/qrbeiveyomidfafivuta/sql/new
Expected: the Supabase SQL Editor opens. The project name at the top of the page reads **feedbox-preview**, and the address bar contains `qrbeiveyomidfafivuta` (feedbox-prod would be `imlitxtkpvrcmijgdsrw`). If it does not read feedbox-preview, stop here: nothing has been changed.

Result

**CT1-2** In the same tab (SQL Editor of **feedbox-preview**), clear every existing query: click an "Untitled query" tab at the top of the SQL Editor, so its orange dot turns into an ×, and click the ×, which deletes that query. Repeat until no query tab is left.
Expected: no query tab is left, and the top of the page still reads **feedbox-preview**.

Result

**CT1-3** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/apply/preview-messages.sql
Expected: a plain text page whose first line is `-- supabase/apply/preview-messages.sql | 329 lines | last line: -- end of preview-messages.sql`.

Result

**CT1-4** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: the editor's line 1 is `-- supabase/apply/preview-messages.sql | 329 lines | last line: -- end of preview-messages.sql`, and, scrolled to the end, line 329 is `-- end of preview-messages.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**CT1-5** (CHANGES the database of feedbox-preview: adds the messages.) In the same Supabase tab, click **Run**.
Expected: **"Success. No rows returned."** If it says "Refused: …", stop: nothing was changed, as the message says; copy the message here. If any other error appears, stop and do not run it again (nothing was changed, the script is all or nothing); copy the whole message here.

Result

**CT1-6** On the Mac, in Chrome, open a new tab (⌘T) and go to this pinned link:
https://raw.githubusercontent.com/adriatic/triad-feedbox/c9f7e88dd8c32f6bb9fe3617080d026217067a6e/supabase/checks/preview-messages.sql
Expected: a plain text page whose first line is `-- supabase/checks/preview-messages.sql | 263 lines | last line: -- end of preview-messages.sql`.

Result

**CT1-7** On that text page press ⌘A and ⌘C, switch to the Supabase tab (feedbox-preview), click **+ New query**, click into the empty editor and press ⌘V.
Expected: line 1 is `-- supabase/checks/preview-messages.sql | 263 lines | last line: -- end of preview-messages.sql`, and line 263 is `-- end of preview-messages.sql`. If either does not match, close that query tab with its × and do this step again.

Result

**CT1-8** (read-only.) In the same Supabase tab, click **Run**, then take a screenshot of the rows (⌘⇧4, drag over the rows) into this note.
Expected: 9 rows, n 0 to 8. Row 0 reads **"PASS: all 8 checks passed."** Row 2 names the fingerprint `f48a2386ba60d5b8353cc684891bdc25`. Row 8 reads "PASS: 0 messages, 0 of them not read yet; on a board with no owner, so that nobody can read them: 0 (expected 0)." If row 0 says FAIL, stop: send all rows to Claude.ai and change nothing on your own.

Result

**CT1-9** On the Mac, in Chrome, open a new tab (⌘T) and go to https://triad-feedbox-git-ct1-contact-nikolaj-ivancics-projects.vercel.app
Expected: the Lumen board "What should Lumen do next?". At the top right it reads **"Viewing as visitor"**. Scrolled to the bottom, the last line reads "Lumen runs on Feedbox, a free, open-source feedback board. See what shipped · Contact the owner".

Result

**CT1-10** At the bottom of that page, click **Contact the owner**.
Expected: the page **Contact the owner**, with the sentence "Only signed-in people can send a message to the owner of Lumen." and the button **Sign in to contact the owner**. There is no message box. The last line of the page now reads "Lumen runs on Feedbox, a free, open-source feedback board. See what shipped", with no Contact the owner link.

Result

**CT1-11** Click **Sign in to contact the owner**.
Expected: the sign-in page, with the box **Email address** and the button **Send me a link**.

Result

**CT1-12** In **Email address**, type your second email address (your own address with `+ct1` just before the @, see "What the steps need"), and click **Send me a link**.
Expected: the page reads **"Check your email"**.

Result

**CT1-13** In Mac Mail, open the new email from **Feedbox <feedbox@pactresearch.net>** to your `+ct1` address, with the subject **Your first Feedbox sign-in link**. Control-click its link **Sign in to Feedbox** and choose **Copy Link**.
Expected: the menu closes. The link is now copied; nothing opens.

Result

**CT1-14** Switch to the Chrome tab of the Preview, click the address bar, press ⌘V and press Return.
Expected: a page with the button **Finish signing in**.

Result

**CT1-15** On that page, click **Finish signing in**.
Expected: the page **Welcome to Lumen**, with the box **Name shown with your ideas**.

Result

**CT1-16** In **Name shown with your ideas**, type `CT1 Member` and click **Continue**.
Expected: the page **Contact the owner** again, now with the box **Your message**, the counter **0 / 2000** under it, the sentence "The owner will see your name and the email address you sign in with, so they can answer you." and the button **Send message**. At the top right it reads **"Signed in as CT1 Member"**, and there is no **Messages** link in the header.

Result

**CT1-17** Click into **Your message** and type `CT1 check: a message from a member.`
Expected: the counter under the box reads **35 / 2000**.

Result

**CT1-18** Click **Send message**.
Expected: a green line reads **"Your message was sent to the owner."**, the box is empty again, and the counter reads **0 / 2000**.

Result

**CT1-19** Click the address bar, type https://triad-feedbox-git-ct1-contact-nikolaj-ivancics-projects.vercel.app/messages and press Return.
Expected: you land on the Lumen board "What should Lumen do next?", not on a Messages page: a member cannot open it. At the top right it still reads **"Signed in as CT1 Member"**.

Result

**CT1-20** At the top right, click **Sign out**.
Expected: the board. At the top right it reads **"Viewing as visitor"**.

Result

**CT1-21** At the top right, click **Sign in**, type your own email address in **Email address** (the one you are the owner with), and click **Send me a link**.
Expected: the page reads **"Check your email"**.

Result

**CT1-22** In Mac Mail, open the new email from **Feedbox <feedbox@pactresearch.net>** to your own address, with the subject **Your Feedbox sign-in link**. Control-click its link **Sign in to Feedbox** and choose **Copy Link**.
Expected: the menu closes. The link is now copied; nothing opens.

Result

**CT1-23** Switch to the Chrome tab of the Preview, click the address bar, press ⌘V and press Return.
Expected: a page with the button **Finish signing in**.

Result

**CT1-24** On that page, click **Finish signing in**.
Expected: the board. At the top right it reads **"Signed in as owner"**, and to its left is the link **Messages (1)**.

Result

**CT1-25** Click **Messages (1)**.
Expected: the page **Messages**. Its first line begins "1 message, 1 not read yet." Below it is one message: **CT1 Member**, then your `+ct1` address as a link (to answer from your own email), then the mark **New** and the date of the day you sent it (written like Nov 19, 2026), the text "CT1 check: a message from a member." and the button **Mark as read**. The header has no Messages link on this page.

Result

**CT1-26** Switch to the Chrome tab of the Preview (still on Messages) and click **Mark as read**.
Expected: the mark **New** is gone, the button now reads **Mark as unread**, and the first line begins "1 message, all read."

Result

**CT1-27** At the top left, click **Lumen**.
Expected: the board. Left of "Signed in as owner" the link now reads **Messages**, without a number.

Result

**CT1-28** Click **Messages**.
Expected: the page **Messages**, with the message from **CT1 Member**, no **New** mark, and the button **Mark as unread**.

Result

**CT1-29** Click **Mark as unread**.
Expected: the mark **New** is back, the button reads **Mark as read**, and the first line begins "1 message, 1 not read yet."

Result

**CT1-30** At the top left, click **Lumen**.
Expected: the board. Left of "Signed in as owner" the link reads **Messages (1)** again.

Result

**CT1-31** In the Notes app, with this note open, choose **File**, then **Export as PDF…**, and save it. Then, in the Claude app, open the TRIAD chat and upload the PDF.
Expected: the PDF is in the TRIAD chat.

Result

---

## Decisions for Nik

On the two choices Claude.ai made, (a) only signed-in people can send a message and (b) the owner sees the sender's name and sign-in email, I see no reason against either; both are built as written. One consequence of (a): someone who cannot sign in at all, for example because the sign-in email never arrives, cannot use Contact the owner either. I think that is acceptable, since the same person could not post or vote either.

**CT1-D1: which address you answer from. Your decision.** When you answer a message with the email link on the Messages page, the person learns the address you answer from. My recommendation: answer from an address you are happy to give to anyone who uses a Feedbox board, not your private one if you keep them apart. Nothing in Feedbox needs to change for either choice.

**CT1-D2: the three example messages on the hosted Preview. Your decision.** The Lumen seed now adds three example messages (two unread), but only to a newly seeded database, such as the local one. feedbox-preview was seeded in F3, and the seed refuses to run twice, so the hosted Preview starts with no messages. My recommendation: leave it so. Steps CT1-17 and CT1-18 make a real message through the app, which tests more than seeded rows would, and no extra script is needed. The alternative is a small preview-only script that adds the same three messages.

**CT1-D3: a sender cannot see their own sent messages. Your decision.** After sending, the person sees "Your message was sent to the owner." and nothing more: there is no list of sent messages and no copy by email (the database lets only owners read messages). My recommendation: keep it so for now. If people ask whether their message arrived, a "Your messages" list can be added later without changing who may read what.
