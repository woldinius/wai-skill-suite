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
# WHAT IT CHECKS — three relations, all mechanical, all fail-visible:
#   1. Work shipped since the newest tag is DECLARED in CHANGELOG.md — an `## [Unreleased]`
#      heading, or a `## [X.Y.Z]` heading newer than that tag (the release PR writes the version
#      directly, minutes before the tag; both forms are honest, so both satisfy the check).
#      TRIGGER SET: `.claude/skills/**` and `.claude/agents/**` (#108), nothing else. That is
#      the tree a user EXECUTES — the set whose staleness produced the false verdict — and
#      scoping it there is also what keeps the post-tag re-pin PR (README + install.sh) from
#      demanding a declaration it has nothing to make. THE COST, NAMED: an installer-only
#      change ships undeclared. Widen the set the day that costs something, not before.
#   2. The plugin's version string is never BEHIND the newest tag. The plugin channel installs
#      from the DEFAULT BRANCH, so a `plugin.json` still reading `0.2.0` after `v0.3.0` is cut
#      gives two people the same version string over two different gates. Deliberately ASYMMETRIC:
#      AHEAD is the normal state of a release PR (version bumped, tag not yet pushed) and passes.
#   3. No install pin is BEHIND the newest tag: every `vX.Y.Z` in README.md and install.sh — the
#      set and pattern of numbers-lint check 1, which holds each pin to a tag that EXISTS (never
#      ahead); this holds it to the NEWEST; together, equal. Red from every cut until the pin-bump
#      PR lands, by design: the re-pin becomes a step no cut can forget (v0.3.3 stayed pinned
#      through the v0.4.0 cut with every check green — #83). All lagging lines are ONE finding,
#      each named file:line. THE COST, NAMED: a `vX.Y.Z` in either file is a pin, history included.
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
  SHIPPED="$(git -C "$ROOT" diff --name-only "$NEWEST..HEAD" -- .claude/skills .claude/agents 2>/dev/null || true)"
  if [ -n "$SHIPPED" ]; then
    NFILES="$(printf '%s\n' "$SHIPPED" | grep -c .)"
    DECLARED=no
    grep -qE '^## \[Unreleased\]' "$CHANGELOG" && DECLARED=yes
    if [ "$DECLARED" = no ]; then
      for v in $(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'); do
        if [ "$(ver_key "$v")" -gt "$NEWEST_KEY" ]; then DECLARED=yes; break; fi
      done
    fi
    [ "$DECLARED" = yes ] || stale "$NFILES file(s) under .claude/skills/ or .claude/agents/ changed since $NEWEST, and CHANGELOG.md declares nothing newer — an unreleased change to the tree a user EXECUTES needs an '## [Unreleased]' section (or the next version's)"
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

# ── 3 · no install pin may be behind the newest tag ─────────────────────────────────────────────
# BEHIND only, like relation 2: a pin AHEAD names a tag this checkout does not have — numbers-lint
# check 1's finding, and naming it here would ask for a re-pin backwards. awk yields one
# file:line=vX.Y.Z per line and version (the curl example carries its tag twice).
BEHIND=""
for pf in README.md install.sh; do
  [ -f "$ROOT/$pf" ] || continue
  for hit in $(awk -v f="$pf" '{ s = $0
        while (match(s, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
          k = f ":" NR "=" substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
          if (!(k in seen)) { seen[k] = 1; print k } } }' "$ROOT/$pf"); do
    [ "$(ver_key "${hit#*=}")" -lt "$NEWEST_KEY" ] && BEHIND="$BEHIND, ${hit%=*} (${hit#*=})"
  done
done
[ -z "$BEHIND" ] \
  || stale "release window — $NEWEST is cut, the install pins still name an older tag:${BEHIND#,}. Close it with the pin-bump PR: re-pin those line(s) to $NEWEST (red until it merges, by design). Any other PR: update its branch after the pin-bump merges — a re-run alone re-tests the old merge"

# ── 3b · a pin line has exactly its shape — only the tag varies ──────────────────────────────────
# The re-pin touches README.md alone, so an agent may merge it; a pin line that also swapped the
# host, the repository or the command (`curl … | sh`) must not ride along. The canonical repository
# is the plugin manifest's "repository" field (a guardrail file since #108). What is HELD: the three
# canonical install lines — the tagged clone, the tagged curl install, the plugin-marketplace line —
# must each be present exactly; and every README line that carries a tag, a `curl`, a `git clone`, a
# pipe into sh or a `/plugin marketplace add` (case-insensitive, whitespace-tolerant) must equal one
# of them, one tag in every slot. What is NOT held, named: other fetch commands (wget, `gh repo
# clone`, `git -C … clone`, `sh -c "$(…)"`), and text hidden in an HTML comment — the README is not
# a guarded file, so a re-pin diff that adds more than a tag still needs a reader.
MANIFEST_REPO="$(grep -oE '"repository"[[:space:]]*:[[:space:]]*"https://github\.com/[^"/]+/[^"/]+"' \
                 "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | grep -oE 'https://github\.com/[^"]+' | head -1)"
if [ -z "$MANIFEST_REPO" ]; then
  echo "  SKIP  pin shape: no \"repository\" in .claude-plugin/plugin.json — nothing to hold the pin lines to"
elif [ -f "$ROOT/README.md" ]; then
  SLUG="${MANIFEST_REPO#https://github.com/}"
  T_CLONE="git clone --depth 1 --branch <V> https://github.com/$SLUG.git /tmp/wai"
  T_CURL="curl -fsSL https://raw.githubusercontent.com/$SLUG/<V>/install.sh | SKILLS_REF=<V> sh"
  T_MKT="/plugin marketplace add $SLUG"
  BADSHAPE="$(awk -v tc="$T_CLONE" -v tu="$T_CURL" -v tm="$T_MKT" '
      { low = tolower($0) }
      /v[0-9]+\.[0-9]+\.[0-9]+/ || low ~ /curl[ \t]/ || low ~ /git[ \t]+(-[^ \t]+[ \t]+)*clone/ || low ~ /\|[ \t]*(ba|z|da)?sh([ \t]|$)/ || low ~ /\/plugin[ \t]+marketplace[ \t]+add/ {
        line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line)
        first = ""; n = line; bad = 0
        while (match(n, /v[0-9]+\.[0-9]+\.[0-9]+/)) {
          v = substr(n, RSTART, RLENGTH); if (first == "") first = v; else if (v != first) bad = 1
          n = substr(n, 1, RSTART - 1) "<V>" substr(n, RSTART + RLENGTH) }
        if (!bad && n == tc) seen_c = 1
        if (!bad && n == tu) seen_u = 1
        if (!bad && n == tm) seen_m = 1
        if (bad || (n != tc && n != tu && n != tm)) printf ", README.md:%d", NR }
      END { if (!seen_c) printf ", no canonical clone line"; if (!seen_u) printf ", no canonical install line"
            if (!seen_m) printf ", no canonical marketplace line" }' "$ROOT/README.md")"
  [ -z "$BADSHAPE" ] \
    || stale "pin shape — README must carry the canonical clone, install and marketplace lines for $MANIFEST_REPO, one tag in every slot, and no deviating curl, clone, pipe-into-sh or marketplace line:${BADSHAPE#,}. Only the tag may change in a re-pin"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "release-lint: $FAIL disagreement(s) between this tree and $NEWEST. A release nothing records is a claim, not a release."
  exit 1
fi
echo "release-lint: the tree agrees with its newest tag ($NEWEST)."
exit 0
