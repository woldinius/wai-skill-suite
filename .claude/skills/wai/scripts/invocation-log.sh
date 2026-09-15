#!/usr/bin/env sh
# invocation-log.sh — the mechanical START LOG of skill runs.
#
# Self-logging that depends on the model is not a measurement, so there are two artifacts, NEVER
# merged:
#
#   invocations (THIS file's output)  — every wai-* skill invocation, written MECHANICALLY by a
#                                        harness hook. No outcome column, ever: it counts starts,
#                                        it judges nothing.
#   run-log.md (run-log.sh)           — the model-written subject record, at hand-back, with outcome.
#
# The two count different units — a START here, a SUBJECT handled there — so retro-compliance.sh
# prints them side by side per skill and never as a rate. A merged artifact would be worse than
# either: a row without an outcome is not a subset of the run log, it is a forgery of one.
# Why: docs/rationale/invocation-log.md § The prompt-written tier was measured and had gaps (#29)
#
# OPT-IN, PER DEVELOPER (the learning-gap precedent): this script only runs if YOU wire it as a
# Claude Code PostToolUse hook in your **.claude/settings.local.json** — never settings.json,
# which would switch it on for every colleague (git protocol: personal state never becomes repo
# state; the hook is personal, the LOG it appends is repo evidence like the gate ledger).
# Print the exact snippet:   sh invocation-log.sh --snippet
#
# FAIL-OPEN, ABSOLUTELY: a hook that breaks the harness is worse than a lost row. Bad JSON, no
# repo, unwritable file — everything exits 0 silently. The ONE defined negative is misuse
# (an unknown argument): exit 2, so a typo in the hook config is visible, not swallowed.
#
#   exit 0  row appended, or input ignored (non-Skill tool, non-wai skill, unreadable anything)
#   exit 2  misuse: an unknown argument
#
# Usage: sh invocation-log.sh            (hook mode: reads the PostToolUse JSON from stdin)
#        sh invocation-log.sh --snippet  (print the settings.local.json opt-in snippet)
#        $INVOCATION_LOG overrides the output path (the $RUN_LOG pattern).

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

if [ "$#" -gt 0 ]; then
  case "$1" in
    --snippet)
      cat <<'SNIP'
Add to .claude/settings.local.json (per-developer opt-in — NOT settings.json):
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Skill",
        "hooks": [ { "type": "command",
                     "command": "sh .claude/skills/wai/scripts/invocation-log.sh" } ] }
    ]
  }
}
Why the repo-local file: the command path is repo-relative and the log it writes is THIS repo's
denominator, so the hook belongs where the repo is — settings.local.json is per developer and
never committed. The gap that comes with it: an untracked file exists only in the checkout where
you wrote it, so a linked worktree (git worktree add) has no hook and its sessions log nothing —
a field repo counted about a fifth of its invocations that way until it moved the hook. So:
ONE checkout → this repo-local file. LINKED WORKTREES, or several suite repos → one hook in
~/.claude/settings.json with an ABSOLUTE command path; it fires in every repo, and the row still
lands in the repo of the current worktree (the script resolves the repo root, not the cwd).
In a linked worktree the row lands in that worktree's docs/architecture/invocation-log.md — its
branch is the PR that carries it; INVOCATION_LOG overrides the path.
SNIP
      exit 0 ;;
    *) echo "invocation-log: unknown argument '$1' (hook mode reads stdin; --snippet prints the opt-in)" >&2; exit 2 ;;
  esac
fi

# Hook mode. Read stdin (bounded), extract tool_name + skill. No jq — POSIX text tools only, and
# every failure path is a silent exit 0 (fail-open: never break the harness over a log row).
IN="$(head -c 65536 2>/dev/null || true)"
printf '%s' "$IN" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"Skill"' || exit 0
SKILL="$(printf '%s' "$IN" | grep -o '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"skill"[[:space:]]*:[[:space:]]*"//; s/"$//')"
# Table-safe, like run-log.sh's cell(): the name is the ONE field this row takes from the payload.
# Pipes become '/', whitespace collapses, 80 chars on a word boundary with a visible cut.
# Why: docs/rationale/invocation-log.md § A crafted skill name forged denominator rows
SKILL="$(printf '%s' "$SKILL" | tr '\n' ' ' | sed 's/|/\//g; s/[[:space:]]\{1,\}/ /g; s/^ *//; s/ *$//' \
  | awk '{ if (length($0) <= 80) print; else { s = substr($0, 1, 80); sub(/ [^ ]*$/, "", s); print s "…" } }')"
case "$SKILL" in
  wai|wai-*) : ;;                       # only the suite's own skills — a foreign skill is not our denominator
  *) exit 0 ;;
esac

# Default path is REPO-relative, not cwd-relative (merge-gate.sh carries the incident; same rule).
# --show-toplevel on purpose: in a LINKED worktree the row lands in THAT worktree's
# docs/architecture/invocation-log.md — its branch is the PR that carries the row to the default
# branch (#68); INVOCATION_LOG overrides the path.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
LOG="${INVOCATION_LOG:-${REPO_ROOT:-.}/docs/architecture/invocation-log.md}"

if [ ! -f "$LOG" ]; then
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  cat > "$LOG" 2>/dev/null <<'HDR' || true
# Invocation log

Every row is a wai-* skill INVOCATION, appended mechanically by a harness hook the developer
opted into (`invocation-log.sh --snippet`). This is the **start log**: it counts starts and
judges nothing — there is deliberately **no outcome column**, and there never will be. The
model-written record with outcomes is `run-log.md`, one row per subject handled. The two count
different units — a start here, a subject there — so `retro-compliance.sh` prints them side by
side per skill, never as a rate. **Never merge the two:**
a row without an outcome is not a subset of the run log, it is a forgery of one.

**APPEND-ONLY**, like the ledger and the run log. A gap here means the hook was not installed
(opt-in, per developer) — it never means "nothing ran".

| when (UTC) | skill |
|---|---|
HDR
fi

printf '| %s | %s |\n' "$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?')" "$SKILL" >> "$LOG" 2>/dev/null || true
exit 0
