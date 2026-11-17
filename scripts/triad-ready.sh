#!/bin/bash
# =============================================================================
# scripts/triad-ready.sh: is TRIAD ready on this Mac? (task T1)
#
# Run it in a NEW Terminal tab (not inside Claude Code), before a session:
#
#   /Users/nikolajivancic/Work/triad-feedbox/scripts/triad-ready.sh
#
# It prints one line per check, PASS or FAIL, the check's name and what it
# found. Every FAIL line also says what to do. The last line is
# "READY: all N checks passed." or "NOT READY: K of N checks failed."
# Exit code 0 when ready, 1 otherwise.
#
# It ONLY reads and looks. It changes nothing, installs nothing, starts or
# stops nothing and signs in to nothing. It never prints a key, token or
# password and needs no secret key. Every network check has a time limit
# (TRIAD_TIMEOUT seconds, default 10), so it cannot hang.
#
# The pieces it checks come from "The whole architecture" in the Obsidian note
# TRIAD/TRIAD setup.md and from CLAUDE.md.
#
# Overrides, FOR TESTING ONLY (they point a check at a wrong place, so that
# each FAIL message can be shown). Nik never sets them.
#   TRIAD_TIMEOUT          seconds per network check (default 10)
#   TRIAD_CLAUDE_APP       Claude desktop app program
#                          (default /Applications/Claude.app/Contents/MacOS/Claude)
#   TRIAD_CHROME_APP       Chrome program
#                          (default /Applications/Google Chrome.app/Contents/MacOS/Google Chrome)
#   TRIAD_CLAUDE_CMD       Claude Code command (default: claude, else ~/.local/bin/claude)
#   TRIAD_NODE_CMD         Node.js command (default: node)
#   TRIAD_PROJECT_DIR      project folder (default /Users/nikolajivancic/Work/triad-feedbox)
#   TRIAD_REPO             GitHub repository (default adriatic/triad-feedbox)
#   TRIAD_REPORTS_DIR      reports folder (default /Users/nikolajivancic/CC reports and tasks)
#   TRIAD_VAULT_DIR        Obsidian vault (default /Users/nikolajivancic/Obsidian/pact-web)
#   TRIAD_DOCKER_CMD       Docker command (default: docker)
#   TRIAD_GH               GitHub CLI program (default ~/gh-cli)
#   TRIAD_MAIN_BRANCH      main branch (default main)
#   TRIAD_REPORTS_BRANCH   reports branch (default cc-reports)
#   TRIAD_REQUIRED_CHECKS  required checks on main (default "lint typecheck unit db e2e Vercel")
#   TRIAD_PROD_URL         Production address (default https://triad-feedbox-delta.vercel.app)
#   TRIAD_PREVIEW_REF      feedbox-preview project ID (default qrbeiveyomidfafivuta)
#   TRIAD_PREVIEW_URL      address asked for feedbox-preview
#                          (default https://<TRIAD_PREVIEW_REF>.supabase.co/auth/v1/health)
#   TRIAD_PROD_REF         feedbox-prod project ID (default imlitxtkpvrcmijgdsrw)
#   TRIAD_PROD_SUPABASE_URL address asked for feedbox-prod
#                          (default https://<TRIAD_PROD_REF>.supabase.co/auth/v1/health)
# =============================================================================

HOME_DIR="/Users/nikolajivancic"
TIMEOUT="${TRIAD_TIMEOUT:-10}"
case "$TIMEOUT" in ''|*[!0-9]*) TIMEOUT=10 ;; esac
CLAUDE_APP="${TRIAD_CLAUDE_APP:-/Applications/Claude.app/Contents/MacOS/Claude}"
CHROME_APP="${TRIAD_CHROME_APP:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
CLAUDE_CMD="${TRIAD_CLAUDE_CMD:-}"
NODE_CMD="${TRIAD_NODE_CMD:-node}"
PROJECT_DIR="${TRIAD_PROJECT_DIR:-$HOME_DIR/Work/triad-feedbox}"
REPO="${TRIAD_REPO:-adriatic/triad-feedbox}"
REPORTS_DIR="${TRIAD_REPORTS_DIR:-$HOME_DIR/CC reports and tasks}"
VAULT_DIR="${TRIAD_VAULT_DIR:-$HOME_DIR/Obsidian/pact-web}"
DOCKER_CMD="${TRIAD_DOCKER_CMD:-docker}"
GH="${TRIAD_GH:-$HOME_DIR/gh-cli}"
MAIN_BRANCH="${TRIAD_MAIN_BRANCH:-main}"
REPORTS_BRANCH="${TRIAD_REPORTS_BRANCH:-cc-reports}"
REQUIRED_CHECKS="${TRIAD_REQUIRED_CHECKS:-lint typecheck unit db e2e Vercel}"
PROD_URL="${TRIAD_PROD_URL:-https://triad-feedbox-delta.vercel.app}"
PREVIEW_REF="${TRIAD_PREVIEW_REF:-qrbeiveyomidfafivuta}"
PROD_REF="${TRIAD_PROD_REF:-imlitxtkpvrcmijgdsrw}"

# Common tool folders, in case the new Terminal tab has a short PATH.
PATH="$PATH:$HOME_DIR/.local/bin:/opt/homebrew/bin:/usr/local/bin"
export PATH

TOTAL=0
FAILED=0
TMP_OUT="$(mktemp -t triad-ready)" || exit 1
trap 'rm -f "$TMP_OUT"' EXIT

NEED_PROJECT="not checked, because the project folder check failed. Fix that first."
NEED_GH="not checked, because the GitHub sign-in check failed. Fix that first."

pass() { TOTAL=$((TOTAL + 1)); printf 'PASS %s: %s\n' "$1" "$2"; }
fail() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf 'FAIL %s: %s\n' "$1" "$2"; }

# limited <seconds> <command...>: run a command, stop it after <seconds>.
# Its output goes to $TMP_OUT. Returns 124 if it was stopped.
limited() {
  local secs="$1"; shift
  "$@" >"$TMP_OUT" 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  if kill -0 "$watcher" 2>/dev/null; then
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
  else
    wait "$watcher" 2>/dev/null
    rc=124
  fi
  return $rc
}

# The stored GitHub sign-in (CLAUDE.md): never the shell's GH_TOKEN.
gh_read() { limited "$TIMEOUT" env -u GH_TOKEN "$GH" "$@"; }

running() { pgrep -f -x "$1" >/dev/null 2>&1 || pgrep -f "^$1( |$)" >/dev/null 2>&1; }

# --- 1. macOS version (information) -------------------------------------------
if command -v sw_vers >/dev/null 2>&1; then
  pass "macOS version" "macOS $(sw_vers -productVersion) (build $(sw_vers -buildVersion)). Information only."
else
  pass "macOS version" "not macOS ($(uname -s)). Information only."
fi

# --- 2. Claude desktop app -------------------------------------------------------
if running "$CLAUDE_APP"; then
  pass "Claude desktop app" "running (this check cannot see whether its link to Claude.ai works)."
else
  fail "Claude desktop app" "not running, so Claude.ai cannot reach the files on this Mac. Open the Claude app from the Dock (or Finder, Applications, Claude) and leave it open."
fi

# --- 3. Chrome -------------------------------------------------------------------
if running "$CHROME_APP"; then
  pass "Chrome" "running."
else
  fail "Chrome" "not running. Open Google Chrome from the Dock, then open the TRIAD chat and the tracker page."
fi

# --- 4. Claude Code ----------------------------------------------------------------
if [ -z "$CLAUDE_CMD" ]; then
  if command -v claude >/dev/null 2>&1; then CLAUDE_CMD="claude"; else CLAUDE_CMD="$HOME_DIR/.local/bin/claude"; fi
fi
if limited "$TIMEOUT" "$CLAUDE_CMD" --version && grep -q "Claude Code" "$TMP_OUT"; then
  pass "Claude Code" "installed, version $(head -n 1 "$TMP_OUT" | sed 's/ (Claude Code)//')."
else
  fail "Claude Code" "not found (looked for \"$CLAUDE_CMD\"). Install Claude Code (https://claude.com/claude-code), then open a new Terminal tab and run this check again."
fi

# --- 5. Node.js (extra: npm run ... in the project needs the version in .nvmrc) ----
WANT_NODE="$( { tr -d ' v\n' < "$PROJECT_DIR/.nvmrc"; } 2>/dev/null)"
[ -n "$WANT_NODE" ] || WANT_NODE="24"
if limited "$TIMEOUT" "$NODE_CMD" --version; then
  HAVE_NODE="$(head -n 1 "$TMP_OUT")"
  case "$HAVE_NODE" in
    "v$WANT_NODE".*) NODE_MATCH=1 ;;
    *) NODE_MATCH=0 ;;
  esac
  if [ "$NODE_MATCH" = 1 ]; then
    pass "Node.js" "$HAVE_NODE, the major version $WANT_NODE that the project's .nvmrc asks for."
  else
    fail "Node.js" "$HAVE_NODE, but the project's .nvmrc asks for version $WANT_NODE. Tell Claude Code; it does not stop a session, but npm commands may behave differently."
  fi
else
  fail "Node.js" "not found (looked for \"$NODE_CMD\"). Tell Claude Code: Node.js $WANT_NODE is needed for the project's npm commands."
fi

# --- 6. Project folder ----------------------------------------------------------------
PROJECT_OK=0
if [ ! -d "$PROJECT_DIR" ]; then
  fail "Project folder" "$PROJECT_DIR does not exist. Tell Claude Code; do not create it by hand."
elif [ "$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)" != "$PROJECT_DIR" ]; then
  fail "Project folder" "$PROJECT_DIR exists but is not a git clone. Tell Claude Code; do not change the folder by hand."
else
  ORIGIN="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)"
  case "$ORIGIN" in
    "git@github.com:$REPO.git" | "https://github.com/$REPO.git" | "https://github.com/$REPO")
      BRANCH="$(git -C "$PROJECT_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "no branch, commit $(git -C "$PROJECT_DIR" rev-parse --short HEAD)")"
      pass "Project folder" "$PROJECT_DIR is a clone of $REPO, on branch $BRANCH."
      PROJECT_OK=1 ;;
    *)
      fail "Project folder" "$PROJECT_DIR is a git clone of \"${ORIGIN:-nothing}\", not of $REPO. Tell Claude Code; do not change the folder by hand." ;;
  esac
fi

# --- 7. Git working tree (information) ----------------------------------------------------
if [ "$PROJECT_OK" = 1 ]; then
  CHANGED="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  LAST="$(git -C "$PROJECT_DIR" log -1 --format='%h %s' 2>/dev/null)"
  if [ "$CHANGED" = 0 ]; then
    pass "Git working tree" "clean; last commit $LAST. Information only."
  else
    pass "Git working tree" "changed or new files: $CHANGED (Claude Code may be in the middle of a task); last commit $LAST. Information only."
  fi
else
  pass "Git working tree" "not looked at, because the project folder check failed. Information only."
fi

# --- 8. Reports folder ----------------------------------------------------------------------
# Today it is a plain folder (not a git clone): Claude Code writes each report
# there and commits a copy to the cc-reports branch from a temporary worktree.
# The design inputs live in its subfolder feedbox-inputs.
if [ ! -d "$REPORTS_DIR" ]; then
  fail "Reports folder" "$REPORTS_DIR does not exist. Tell Claude Code and Claude.ai; do not create it by hand."
elif [ ! -w "$REPORTS_DIR" ]; then
  fail "Reports folder" "$REPORTS_DIR exists but cannot be written to, so Claude Code cannot save reports. Tell Claude Code."
elif [ ! -d "$REPORTS_DIR/feedbox-inputs" ]; then
  fail "Reports folder" "$REPORTS_DIR has no subfolder feedbox-inputs (the design inputs). Tell Claude Code."
else
  REPORTS_N="$(ls "$REPORTS_DIR" 2>/dev/null | grep -c '^summary-task-.*\.md$')"
  pass "Reports folder" "$REPORTS_DIR exists and has write permission (nothing was written); it holds feedbox-inputs and $REPORTS_N summary-task reports."
fi

# --- 9. Obsidian vault and TRIAD folder -------------------------------------------------------
if [ ! -d "$VAULT_DIR" ]; then
  fail "Obsidian vault" "$VAULT_DIR does not exist. Open Obsidian and check that the vault pact-web is synced; tell Claude.ai."
elif [ ! -f "$VAULT_DIR/TRIAD/TRIAD setup.md" ]; then
  fail "Obsidian vault" "$VAULT_DIR exists but has no TRIAD/TRIAD setup.md. Open Obsidian and check that the vault pact-web is synced; tell Claude.ai."
else
  pass "Obsidian vault" "$VAULT_DIR and its TRIAD folder (with TRIAD setup.md) exist."
fi

# --- 10. Docker -----------------------------------------------------------------------------------
if limited "$TIMEOUT" "$DOCKER_CMD" info --format '{{.ServerVersion}}' && [ -n "$(head -n 1 "$TMP_OUT")" ]; then
  pass "Docker" "running (Docker $(head -n 1 "$TMP_OUT")). The local database itself is not looked at."
else
  fail "Docker" "not running, so the local database tests cannot run. In Terminal, type colima start and press Return (it takes about a minute), then run this check again."
fi

# --- 11. GitHub sign-in -----------------------------------------------------------------------------
GH_OK=0
if [ ! -x "$GH" ]; then
  fail "GitHub sign-in" "the GitHub CLI program $GH is missing. Tell Claude Code."
elif gh_read api user --jq .login && LOGIN="$(head -n 1 "$TMP_OUT")" && [ -n "$LOGIN" ] \
     && gh_read api "repos/$REPO" --jq .full_name && [ "$(head -n 1 "$TMP_OUT")" = "$REPO" ]; then
  pass "GitHub sign-in" "the stored GitHub sign-in is account $LOGIN, and it can read $REPO."
  GH_OK=1
else
  fail "GitHub sign-in" "the stored GitHub sign-in cannot read $REPO (signed out, no network, or GitHub down). Check the network and https://www.githubstatus.com, then tell Claude Code. Do not sign in yourself."
fi

# --- 12. git over SSH (extra: Claude Code pushes over SSH) ---------------------------------------------
if [ "$PROJECT_OK" != 1 ]; then
  fail "git over SSH" "$NEED_PROJECT"
elif GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=$TIMEOUT" \
     limited "$TIMEOUT" git -C "$PROJECT_DIR" ls-remote --heads origin "$MAIN_BRANCH" \
     && grep -q "refs/heads/$MAIN_BRANCH" "$TMP_OUT"; then
  pass "git over SSH" "the project folder can read branch $MAIN_BRANCH from GitHub over SSH (Claude Code pushes over SSH; a push was not tried)."
else
  fail "git over SSH" "the project folder cannot read branch $MAIN_BRANCH from GitHub over SSH (no network, or the SSH key is not loaded). Check the network, then tell Claude Code."
fi

# --- 13. cc-reports branch -------------------------------------------------------------------------
if [ "$GH_OK" != 1 ]; then
  fail "Reports branch" "$NEED_GH"
elif gh_read api "repos/$REPO/branches/$REPORTS_BRANCH" --jq .commit.sha && [ -n "$(head -n 1 "$TMP_OUT")" ]; then
  pass "Reports branch" "$REPORTS_BRANCH exists on GitHub (latest commit $(head -c 7 "$TMP_OUT"))."
else
  fail "Reports branch" "branch $REPORTS_BRANCH was not found on GitHub, so Claude.ai cannot read the reports there. Tell Claude Code."
fi

# --- 14. Required checks on main (extra: from CLAUDE.md, the ruleset since M5) -----------------------
if [ "$GH_OK" != 1 ]; then
  fail "Required checks" "$NEED_GH"
elif gh_read api "repos/$REPO/rules/branches/$MAIN_BRANCH" \
     --jq '[.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | join(" ")'; then
  HAVE_CHECKS=" $(head -n 1 "$TMP_OUT") "
  MISSING=""
  for c in $REQUIRED_CHECKS; do
    case "$HAVE_CHECKS" in *" $c "*) ;; *) MISSING="$MISSING $c" ;; esac
  done
  if [ -z "$MISSING" ] && [ "$HAVE_CHECKS" != "  " ]; then
    pass "Required checks" "branch $MAIN_BRANCH requires$(echo "$HAVE_CHECKS" | sed 's/ *$//') before a merge."
  else
    fail "Required checks" "branch $MAIN_BRANCH does not require:${MISSING:- any check}. Tell Claude.ai; the ruleset on $MAIN_BRANCH must be fixed in a task before the next merge."
  fi
else
  fail "Required checks" "the rules of branch $MAIN_BRANCH could not be read. Tell Claude Code."
fi

# --- 15. Latest CI run on main -----------------------------------------------------------------------
if [ "$GH_OK" != 1 ]; then
  fail "CI on $MAIN_BRANCH" "$NEED_GH"
elif gh_read run list --repo "$REPO" --branch "$MAIN_BRANCH" --workflow CI --limit 1 \
     --json status,conclusion,headSha,createdAt \
     --jq 'if length == 0 then "none" else .[0] | "\(.status) \(if (.conclusion // "") == "" then "none" else .conclusion end) \(.headSha[0:7]) \(.createdAt)" end' \
     && [ -n "$(head -n 1 "$TMP_OUT")" ]; then
  read -r RUN_STATUS RUN_CONCLUSION RUN_SHA RUN_AT < "$TMP_OUT"
  if [ "$RUN_STATUS" = none ]; then
    fail "CI on $MAIN_BRANCH" "there is no CI run on branch $MAIN_BRANCH. Tell Claude Code."
  elif [ "$RUN_STATUS" = completed ] && [ "$RUN_CONCLUSION" = success ]; then
    pass "CI on $MAIN_BRANCH" "the latest CI run passed (commit $RUN_SHA, $RUN_AT)."
  elif [ "$RUN_STATUS" != completed ]; then
    fail "CI on $MAIN_BRANCH" "the latest CI run (commit $RUN_SHA, started $RUN_AT) is still $RUN_STATUS. Wait a few minutes and run this check again."
  else
    fail "CI on $MAIN_BRANCH" "the latest CI run failed ($RUN_CONCLUSION, commit $RUN_SHA, $RUN_AT). Tell Claude.ai before starting a task."
  fi
else
  fail "CI on $MAIN_BRANCH" "no CI run on branch $MAIN_BRANCH could be read. Tell Claude Code."
fi

# --- 16. Vercel Production -----------------------------------------------------------------------------
if limited "$TIMEOUT" curl -sS -L -m "$TIMEOUT" -o - -w '\nHTTP_CODE=%{http_code}' "$PROD_URL"; then
  CODE="$(sed -n 's/^HTTP_CODE=//p' "$TMP_OUT")"
  if [ "$CODE" = 200 ] && grep -q "Feedbox" "$TMP_OUT"; then
    pass "Vercel Production" "$PROD_URL answers HTTP 200 and the page contains the word Feedbox."
  else
    fail "Vercel Production" "$PROD_URL answers HTTP ${CODE:-nothing} without the Feedbox page. Open it in Chrome; if it is broken, tell Claude.ai."
  fi
else
  fail "Vercel Production" "$PROD_URL does not answer (no network, or Vercel down). Check the network and https://www.vercel-status.com, then tell Claude.ai."
fi

# --- 17. Vercel build of main (extra: the Vercel status on main's latest commit) ----------------------
if [ "$GH_OK" != 1 ]; then
  fail "Vercel build of $MAIN_BRANCH" "$NEED_GH"
elif gh_read api "repos/$REPO/commits/$MAIN_BRANCH/status" \
     --jq '[.statuses[] | select(.context == "Vercel") | .state][0] // "none"'; then
  VSTATE="$(head -n 1 "$TMP_OUT")"
  if [ "$VSTATE" = success ]; then
    pass "Vercel build of $MAIN_BRANCH" "Vercel's status on the latest commit of $MAIN_BRANCH is success."
  else
    fail "Vercel build of $MAIN_BRANCH" "Vercel's state for the latest commit on $MAIN_BRANCH is $VSTATE, not success. If it is pending, wait a few minutes; otherwise tell Claude.ai."
  fi
else
  fail "Vercel build of $MAIN_BRANCH" "Vercel's state for branch $MAIN_BRANCH could not be read. Tell Claude Code."
fi

# --- 18 and 19. Supabase feedbox-preview and feedbox-prod -----------------------------------------------
# Only the public address is used, with no key: a project's address that is up
# answers 401 "No API key found in request". The database itself is not looked
# at. Project IDs: Obsidian note TRIAD/Important URLs.md, section Supabase.
supabase_check() { # <check name> <project name> <project ID> <address>
  if limited "$TIMEOUT" curl -sS -m "$TIMEOUT" -o - -w '\nHTTP_CODE=%{http_code}' "$4"; then
    CODE="$(sed -n 's/^HTTP_CODE=//p' "$TMP_OUT")"
    if [ "$CODE" = 401 ] && grep -q "No API key found" "$TMP_OUT"; then
      pass "$1" "the address of project $3 answers HTTP 401 and asks for a key, as expected (no key is sent; the database itself is not looked at)."
    else
      fail "$1" "the address of project $3 answered HTTP ${CODE:-nothing}, not the expected 401. Open the Supabase dashboard in Chrome and check that $2 is not paused; tell Claude.ai."
    fi
  else
    fail "$1" "the address of project $3 does not answer (no network, wrong project ID, or Supabase down). Check https://status.supabase.com and the Supabase dashboard, then tell Claude.ai."
  fi
}
supabase_check "Supabase feedbox-preview" feedbox-preview "$PREVIEW_REF" \
  "${TRIAD_PREVIEW_URL:-https://$PREVIEW_REF.supabase.co/auth/v1/health}"
supabase_check "Supabase feedbox-prod" feedbox-prod "$PROD_REF" \
  "${TRIAD_PROD_SUPABASE_URL:-https://$PROD_REF.supabase.co/auth/v1/health}"

# --- Overall ---------------------------------------------------------------------------------------------------
if [ "$FAILED" = 0 ]; then
  echo "READY: all $TOTAL checks passed."
  exit 0
fi
echo "NOT READY: $FAILED of $TOTAL checks failed."
exit 1
