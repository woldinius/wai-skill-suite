#!/usr/bin/env sh
# invocation-log.sh — the mechanical DENOMINATOR of skill runs (#29, decided 2026-08-18).
#
# The run log's two tiers were measured in the field: the script-written tier logged 9 of 9; every
# prompt-written tier had gaps (architecture-audit 0 rows with a committed report, learning-gap 0
# with a ledger entry, implementation 4 of 5). Self-logging that depends on the model is not a
# measurement. The fix is two artifacts, NEVER merged:
#
#   invocations (THIS file's output)  — every wai-* skill invocation, written MECHANICALLY by a
#                                        harness hook. No outcome column, ever: it counts starts,
#                                        it judges nothing.
#   run-log.md (run-log.sh)           — the model-written numerator, at hand-back, with outcome.
#
# The difference between the two is per-skill prompt-contract compliance, and retro-compliance.sh
# reports it. A merged artifact would be worse than either: a row without an outcome is not a
# subset of the run log, it is a forgery of one.
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
case "$SKILL" in
  wai|wai-*) : ;;                       # only the suite's own skills — a foreign skill is not our denominator
  *) exit 0 ;;
esac

# Default path is REPO-relative, not cwd-relative (merge-gate.sh carries the incident; same rule).
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
LOG="${INVOCATION_LOG:-${REPO_ROOT:-.}/docs/architecture/invocation-log.md}"

if [ ! -f "$LOG" ]; then
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  cat > "$LOG" 2>/dev/null <<'HDR' || true
# Invocation log

Every row is a wai-* skill INVOCATION, appended mechanically by a harness hook the developer
opted into (`invocation-log.sh --snippet`). This is the **denominator**: it counts starts and
judges nothing — there is deliberately **no outcome column**, and there never will be. The
model-written numerator with outcomes is `run-log.md`; the difference between the two files is
per-skill prompt-contract compliance (`retro-compliance.sh` reports it). **Never merge the two:**
a row without an outcome is not a subset of the run log, it is a forgery of one.

**APPEND-ONLY**, like the ledger and the run log. A gap here means the hook was not installed
(opt-in, per developer) — it never means "nothing ran".

| when (UTC) | skill |
|---|---|
HDR
fi

printf '| %s | %s |\n' "$(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?')" "$SKILL" >> "$LOG" 2>/dev/null || true
exit 0
