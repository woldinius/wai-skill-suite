#!/usr/bin/env sh
# install-hook.sh — install the personal pre-commit hook where git will ACTUALLY run it.
#
# The hook blocks committing an open learning gap (a gap marker in the tree). It is local and
# personal — `.git/hooks/` is neither cloned nor shared — which is exactly right: it exists only for
# the participant, colleagues never get it. But "write `.git/hooks/pre-commit`" is wrong twice over,
# and both traps are common:
#
#   1. core.hooksPath. husky and lefthook (near-ubiquitous in JS/TS repos) point git at ANOTHER
#      directory with `git config core.hooksPath`. A hook written to `.git/hooks/` is then a silent
#      no-op — git never runs it. So install into the CONFIGURED directory, whatever it is.
#   2. Existence is not execution. A file that exists but is not executable, or sits in the wrong
#      dir, proves nothing. Verify it is executable and is the file git will run.
#
# And one hard refusal: if the configured hooks dir is COMMITTED to the repo (husky's `.husky/` is),
# writing our hook there would make a personal thing repo state — pushed to every colleague. That is
# never allowed. We refuse and let the skill fall back to blocking-by-check at plant time.
#
# The hook we write CHAINS any pre-existing pre-commit (so we never silently disable someone's
# checks) and DISABLES ITSELF when the ledger is gone (deleting the ledger is a clean opt-out — the
# hook must not keep blocking commits with no ledger left to explain why).
#
#   exit 0  installed or verified (idempotent — re-running is safe)
#   exit 1  refused: the hooks dir is repo-committed; a personal hook must not become repo state
#   exit 2  git config/dir could not be read (not a git repo, etc.)
#
# What this does NOT decide: whether the human wants learning mode (the ledger is that consent). The
# one judgment it enforces — a personal hook never becomes repo state — is the exit-1 refusal.
#
# Usage:  sh install-hook.sh [ledger-path]
#   ledger-path is embedded into the hook so it can self-disable. Defaults to the home-slug path.

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

command -v git >/dev/null 2>&1 || { echo "install-hook: git is not installed." >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "install-hook: not a git repository — cannot install a hook." >&2; exit 2; }

# --- The ledger path the hook self-disables on --------------------------------------------------
LEDGER="${1:-}"
if [ -z "$LEDGER" ]; then
  # Reconstruct the same home-slug path the skill uses, so the hook points at the right ledger.
  REMOTE="$(git config --get remote.origin.url 2>/dev/null || true)"
  SLUG=""
  if [ -n "$REMOTE" ]; then
    _u="${REMOTE%.git}"; _u="${_u%/}"
    _repo="${_u##*/}"; _rest="${_u%/*}"; _owner="${_rest##*[:/]}"
    [ -n "$_owner" ] && [ -n "$_repo" ] && SLUG="$_owner-$_repo"
  fi
  if [ -z "$SLUG" ]; then
    _gcd="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$_gcd" ] && SLUG="$(basename "$(dirname "$_gcd")")" || SLUG="$(basename "$(pwd)")"
  fi
  LEDGER="${HOME:-}/.claude/learning/$SLUG/ledger.md"
fi

# --- Where does git actually look for hooks? ----------------------------------------------------
HP="$(git config --get core.hooksPath 2>/dev/null || true)"
if [ -n "$HP" ]; then
  case "$HP" in
    /*) HOOKS_DIR="$HP" ;;
    *)  TOP="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"; HOOKS_DIR="$TOP/$HP" ;;
  esac
else
  # The real hooks dir for this worktree (handles a redirected gitdir and linked worktrees).
  HOOKS_DIR="$(git rev-parse --git-path hooks 2>/dev/null || true)"
  [ -n "$HOOKS_DIR" ] || { echo "install-hook: could not resolve the hooks directory." >&2; exit 2; }
fi

# --- The hard refusal: never write into a COMMITTED hooks dir -----------------------------------
# If git tracks any file under this directory, it is repo state — installing here would push a
# personal hook to every colleague. Refuse. (`.git/hooks` is inside the gitdir and never tracked,
# so the default path always passes; husky's committed `.husky/` is caught here.)
if [ -n "$(git ls-files -- "$HOOKS_DIR" 2>/dev/null | head -1)" ]; then
  echo "install-hook: the hooks directory '$HOOKS_DIR' is COMMITTED to the repo." >&2
  echo "  A personal learning hook must never become repo state. Refusing to write it." >&2
  echo "  The skill should fall back to blocking-by-check at plant time instead." >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR" 2>/dev/null || { echo "install-hook: cannot create '$HOOKS_DIR'." >&2; exit 2; }

HOOK="$HOOKS_DIR/pre-commit"
BACKUP="$HOOKS_DIR/pre-commit.pre-wai-learning-gap"
MARKER="wai-learning-gap pre-commit (personal, auto-installed)"

# The gap marker, assembled — NEVER written here as one contiguous string. This file generates a
# hook that greps for the marker, so writing the literal would put it in the tree, where every
# marker-scanner (this suite's own open-gap-check, and the hook itself once the suite is vendored
# into a repo) would match it as if it were a real open exercise.
# Why: docs/rationale/install-hook.md § The literal marker blocked a commit in the field
GAP_WORD='LEARN'

# --- Chain a pre-existing FOREIGN hook ----------------------------------------------------------
# If a pre-commit is already there and it is not ours, preserve it: move it aside and our hook will
# run it first. If it is already ours, leave it (idempotent) — we still rewrite it below so the
# embedded ledger path stays current, preserving the chain reference if a backup exists.
if [ -f "$HOOK" ] && ! grep -q "$MARKER" "$HOOK" 2>/dev/null; then
  mv "$HOOK" "$BACKUP" || { echo "install-hook: could not set aside the existing hook." >&2; exit 2; }
fi

CHAINED=""
[ -f "$BACKUP" ] && CHAINED="$BACKUP"

# --- Write the hook -----------------------------------------------------------------------------
# The body is emitted literally: the `$CHAINED`, `$LEDGER`, `$@` and `$?` inside it are the HOOK's
# runtime variables, and must reach the file UN-expanded — so they are single-quoted on purpose.
# shellcheck disable=SC2016  # single quotes are intentional: this is the hook's source, not ours
{
  printf '%s\n' "#!/bin/sh"
  printf '%s\n' "# $MARKER — see .claude/skills/wai-learning-gap/SKILL.md"
  printf '%s\n' "# Blocks committing an open learning gap ($GAP_WORD #). Self-disables when the ledger is gone."
  printf 'LEDGER=%s\n' "\"$LEDGER\""
  if [ -n "$CHAINED" ]; then
    printf 'CHAINED=%s\n' "\"$CHAINED\""
    printf '%s\n' 'if [ -x "$CHAINED" ]; then "$CHAINED" "$@" || exit $?; fi'
  fi
  printf '%s\n' '# No ledger → this person opted out. Disable OUR check (a chained hook still ran above).'
  printf '%s\n' '[ -f "$LEDGER" ] || exit 0'
  printf '%s\n' '# Grep staged CONTENT (not just added lines) so a marker already in HEAD is still caught.'
  printf '%s\n' "if git grep --cached -I -q -e '$GAP_WORD #[0-9]' -- . ':!*.md' ':!*.mdx' ':!*.markdown'; then"
  printf '%s\n' "  echo \"Commit blocked: an open learning gap ($GAP_WORD #) is staged.\" >&2"
  printf '%s\n' '  echo "   Solve it (see $LEDGER) — or ask Claude for a hint or the solution." >&2'
  printf '%s\n' '  exit 1'
  printf '%s\n' 'fi'
  printf '%s\n' 'exit 0'
} > "$HOOK" || { echo "install-hook: could not write '$HOOK'." >&2; exit 2; }

chmod +x "$HOOK" 2>/dev/null || { echo "install-hook: could not make '$HOOK' executable." >&2; exit 2; }

# --- Verify: existence is not execution ---------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  echo "install-hook: wrote '$HOOK' but it is not executable — git would not run it." >&2
  exit 2
fi

echo "install-hook: installed and verified — git runs $HOOK"
[ -n "$CHAINED" ] && echo "  chained the pre-existing hook: $CHAINED"
echo "  ledger: $LEDGER (the hook disables itself if this file is deleted — a clean opt-out)"
exit 0
