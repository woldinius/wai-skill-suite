#!/usr/bin/env sh
# release-lint.sh — the tree must not silently disagree with its newest tag.
#
# THE INCIDENT (2026-08-18, found by an evaluation of this repo, not by a check). Commit 171ae9c
# fixed a verdict-corrupting bug: `merge-gate.sh` resolved its default paths against the cwd, so
# the invocation the skills themselves document ("from this skill's directory") produced a FALSE
# verdict — "no quality catalog", in the repo that has one — and planted a stray gate-ledger inside
# `.claude/skills/`, the tree `install.sh` copies into every target repo. The fix merged to `main`
# and sat there. `git tag --contains 171ae9c` was EMPTY, while README.md and install.sh both told
# a reader to install `v0.2.0` — the release without the fix. Nothing in the repo could say so:
# `numbers-lint` check 1 verifies that a referenced tag EXISTS, and v0.2.0 did exist.
#
# The failure was not a stale pin. Pinning the newest tag is correct between releases, and the pin
# was correct. The failure was that WORK SHIPPED TO `main` HAD NO ARTEFACT SAYING IT WAS UNRELEASED
# — the same class this repo names everywhere else: "the model checked" and "we released it"
# produce identical output whether they happened or not. So this file measures the one relation
# that was unmeasured: the tree, against the newest tag a reader can actually fetch.
#
# WHAT IT CHECKS — two relations, both mechanical, both fail-visible:
#   1. Work shipped since the newest tag is DECLARED in CHANGELOG.md — an `## [Unreleased]`
#      heading, or a `## [X.Y.Z]` heading newer than that tag (the release PR writes the version
#      directly, minutes before the tag; both forms are honest, so both satisfy the check).
#      TRIGGER SET: `.claude/skills/**` and nothing else. That is the tree a user EXECUTES — the
#      set whose staleness produced the false verdict — and scoping it there is also what keeps
#      the post-tag re-pin PR (README + install.sh) from demanding a declaration it has nothing
#      to make. THE COST, NAMED: an installer-only change ships undeclared. Widen the set the day
#      that costs something, not before.
#   2. The plugin's version string is never BEHIND the newest tag. The plugin channel installs
#      from the DEFAULT BRANCH, so a `plugin.json` still reading `0.2.0` after `v0.3.0` is cut
#      gives two people the same version string over two different gates. Deliberately ASYMMETRIC:
#      AHEAD is the normal state of a release PR (version bumped, tag not yet pushed) and passes.
#
# Judgment stays out (ADR-0002): this file compares versions and asks whether a heading exists.
# Whether the release NOTES are any good is a human's call and no script's.
#
# Usage: sh tests/release-lint.sh [repo-root]      (default: the repo this file lives in)
# Exit:  0 the tree agrees with its tag · 1 a disagreement · 2 could not measure (not a pass).
set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -d "$ROOT" ] || { echo "release-lint: no such directory: $ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "release-lint: git is required" >&2; exit 2; }

FAIL=0
stale() { printf '  STALE %s\n' "$1"; FAIL=$((FAIL+1)); }

# ver_key vX.Y.Z → a zero-padded integer key. Deliberately NOT `sort -V`: this repo has already
# paid once for assuming a coreutils flag behaves the same on the macOS /bin/sh it also runs on
# (the `case … esac` inside `$( )` that shellcheck passes and bash 3.2 rejects — five times now).
# awk is the same awk on both.
ver_key() { printf '%s' "${1#v}" | awk -F. '{ printf "%05d%05d%05d", $1, $2, $3 }'; }

# ── the newest tag a reader can fetch ───────────────────────────────────────────────────────────
# Only `vX.Y.Z` counts — the shape numbers-lint check 1 already holds README and install.sh to.
# No remote fallback here, unlike numbers-lint: check 1 needs a tag LIST, this needs a tag as a
# REVISION to diff against, and a name from `ls-remote` is not one. No local tags → SKIP, visibly.
TAGS="$(git -C "$ROOT" tag 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)"
if [ -z "$TAGS" ]; then
  echo "  SKIP  no vX.Y.Z tag in this checkout — nothing to compare the tree against (a skipped check is not a pass)"
  echo "release-lint: not measured (no tags). Fetch tags (\`git fetch --tags\`) to arm this."
  exit 0
fi

NEWEST=""; NEWEST_KEY=0
for t in $TAGS; do
  k="$(ver_key "$t")"
  if [ "$k" -gt "$NEWEST_KEY" ]; then NEWEST_KEY="$k"; NEWEST="$t"; fi
done

# ── 1 · work shipped since that tag must be declared ────────────────────────────────────────────
CHANGELOG="$ROOT/CHANGELOG.md"
if [ ! -f "$CHANGELOG" ]; then
  echo "release-lint: no CHANGELOG.md at $CHANGELOG — cannot measure what is declared." >&2
  exit 2
fi

# The tag must be a resolvable revision here, not just a name: a shallow or partial checkout can
# know the name and not the commit, and "cannot diff" must never read as "nothing changed".
if ! git -C "$ROOT" rev-parse -q --verify "$NEWEST^{commit}" >/dev/null 2>&1; then
  echo "  SKIP  $NEWEST is not a resolvable commit in this checkout — cannot diff the tree against it"
else
  SHIPPED="$(git -C "$ROOT" diff --name-only "$NEWEST..HEAD" -- .claude/skills 2>/dev/null || true)"
  if [ -n "$SHIPPED" ]; then
    NFILES="$(printf '%s\n' "$SHIPPED" | grep -c .)"
    DECLARED=no
    grep -qE '^## \[Unreleased\]' "$CHANGELOG" && DECLARED=yes
    if [ "$DECLARED" = no ]; then
      for v in $(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'); do
        if [ "$(ver_key "$v")" -gt "$NEWEST_KEY" ]; then DECLARED=yes; break; fi
      done
    fi
    [ "$DECLARED" = yes ] || stale "$NFILES file(s) under .claude/skills/ changed since $NEWEST, and CHANGELOG.md declares nothing newer — an unreleased change to the tree a user EXECUTES needs an '## [Unreleased]' section (or the next version's)"
  fi
fi

# ── 2 · the plugin's version string must not be behind the newest tag ───────────────────────────
# Both files, because the marketplace entry is a SECOND copy of the same number and a second copy
# is a thing that drifts (the coordination-lint/excluded-domains rule, one layer out).
for pf in "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json"; do
  [ -f "$pf" ] || continue
  rel="${pf#"$ROOT"/}"
  for v in $(grep -oE '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$pf" \
             | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
    if [ "$(ver_key "$v")" -lt "$NEWEST_KEY" ]; then
      stale "$rel declares $v while the newest tag is $NEWEST — the plugin channel installs from the DEFAULT BRANCH, so this hands two people the same version string over two different gates"
    fi
  done
done

if [ "$FAIL" -gt 0 ]; then
  echo "release-lint: $FAIL disagreement(s) between this tree and $NEWEST. A release nothing records is a claim, not a release."
  exit 1
fi
echo "release-lint: the tree agrees with its newest tag ($NEWEST)."
exit 0
