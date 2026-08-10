#!/usr/bin/env sh
# handoff-lint.sh — the hygiene the file-based agent-to-agent handoff depends on, as an exit code.
#
# Cross-repo work in this suite is deliberately file-based: an agent writes the recipient's
# `temp/input`, reads-and-drains the sender's `temp/output`, and NEVER touches another repo's
# tracked files. That invariant only holds if two things are true, and both are the kind of thing a
# human forgets and a script never does:
#
#   1. `temp/` is gitignored AND nothing under it is tracked. The whole design rests on the mailbox
#      being scratch. The day someone `git add -f temp/output/spec.md`, the "auditable, secret-free,
#      never-committed" story is a fiction and no reviewer would notice — a tracked file looks like
#      any other. (repo-hygiene mode.)
#
#   2. A handoff MESSAGE is a POINTER, not a payload. The envelope carries who/to-whom/correlation
#      and a POINTER into a mailbox — never an inlined spec, and never a secret. Inline the spec and
#      you have copied a contract-domain artifact across a repo boundary unreviewed; inline a token
#      and you have leaked a credential into a file the other agent will read. (--message mode.)
#
# EXIT CODES — fail closed:
#   0  clean
#   1  a violation (printed) — a tracked temp file, an off-schema/incomplete envelope, an inlined
#      payload, or a KNOWN-shape secret
#   2  could not check — not a git repo, or the message file is unreadable. Held, never waved
#      through: "I could not look" is not "it is fine".
#
# WHAT IS A HARD FAIL vs A WARNING (the V1-5 lesson):
#   A known token SHAPE — a private-key header, an `AKIA…` key, an `sk-…`/`ghp_…`/`xox…` token, a
#   long bearer — is a hard fail: high precision, and if it is here it should not be. GENERIC
#   high-entropy (a long base64/hex run) is a WARNING only. An entropy gate that fails hard cries
#   wolf on the base64 hash a correlation POINTER legitimately contains, and a lint that cries wolf
#   gets switched off. Fix leaks with precision, not with strictness.
#
# WHAT THIS SCRIPT DOES NOT DECIDE: whether a message SHOULD be sent, what it MEANS, or whether the
# change it points at is an excluded domain (that is excluded-domains.sh, on the change itself). It
# checks hygiene, structure, and secret-absence — nothing semantic.
#
# Usage:
#   sh handoff-lint.sh [repo-root]        repo-hygiene mode (default repo-root: .)
#   sh handoff-lint.sh --message <file>   envelope + pointer-not-payload + secret check

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

FAIL=0
bad()  { FAIL=1; printf '  x %s\n' "$1"; }
warn() {         printf '  ! %s\n' "$1"; }   # advisory — never changes the exit code
okln() {         printf '  . %s\n' "$1"; }

# --- Known credential SHAPES — high precision, hard fail. Generic entropy is handled separately. --
# One ERE, alternated. Each branch is a shape a real secret has and ordinary prose does not.
KNOWN_SECRET_RE='-----BEGIN [A-Z ]+PRIVATE KEY-----|AKIA[0-9A-Z]{16}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{20,}|[Bb]earer [A-Za-z0-9._-]{20,}'

# =================================================================================================
# --message mode
# =================================================================================================
if [ "${1:-}" = "--message" ]; then
  MSG="${2:-}"
  [ -n "$MSG" ] || { echo "handoff-lint: --message needs a file" >&2; exit 2; }
  [ -f "$MSG" ] && [ -r "$MSG" ] || { echo "handoff-lint: cannot read message '$MSG'" >&2; exit 2; }

  echo "handoff-lint (message): $MSG"

  # 1. Filename schema: <UTC-timestamp>__<correlation-key>__<req|res>.md
  #    The timestamp is filesystem-safe (dashes for the time's colons); the correlation key is what
  #    threads a request to its response; the kind says which. A name off this schema means a message
  #    that no drain step and no human can correlate — which is the same as a lost message.
  BN="$(basename "$MSG")"
  if printf '%s' "$BN" \
     | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z__[A-Za-z0-9._-]+__(req|res)\.md$'; then
    okln "filename matches the envelope schema"
  else
    bad "filename '$BN' is off the envelope schema: <ts>T<hh-mm-ss>Z__<correlation-key>__(req|res).md"
  fi

  # 2. Required headers — who, to whom, which thread, what kind, and the POINTER.
  for h in From To Correlation-Id Kind Pointer; do
    if grep -qE "^$h:[[:space:]]*[^[:space:]]" "$MSG"; then
      okln "header present: $h"
    else
      bad "required header missing or empty: $h"
    fi
  done

  # 3. Pointer, not payload. The Pointer must reference a mailbox path; the message must not INLINE
  #    a spec. A fenced code block or an over-long body is an inlined payload — the exact thing that
  #    copies a contract-domain artifact across the boundary unreviewed.
  if grep -qE '^Pointer:[[:space:]]*[^[:space:]]+' "$MSG"; then
    if grep -qE '^Pointer:[[:space:]]*(temp/|\./temp/)' "$MSG"; then
      okln "pointer references a temp/ mailbox"
    else
      warn "pointer does not reference a temp/ mailbox — confirm it is a path, not an inlined value"
    fi
  fi
  if grep -q '```' "$MSG"; then
    bad "the envelope contains a fenced code block — that is an inlined payload, not a pointer"
  fi
  NLINES="$(grep -c . "$MSG" 2>/dev/null || echo 0)"
  if [ "${NLINES:-0}" -gt 60 ]; then
    bad "the envelope is $NLINES non-empty lines — a pointer envelope is a handful; this looks like an inlined payload"
  fi

  # 4. Secrets. Known shapes hard-fail; generic entropy only warns.
  # `-e` (not a bare pattern): the ERE begins with `-----BEGIN…`, and a leading dash is read as an
  # option flag otherwise — the pattern would never run and the secret check would silently pass.
  HITS="$(grep -nE -e "$KNOWN_SECRET_RE" "$MSG" 2>/dev/null | cut -d: -f1 | tr '\n' ' ' || true)"
  if [ -n "$HITS" ]; then
    bad "a known-shape secret is inlined (line(s): $HITS) — a handoff message points at secrets, it never carries them"
  else
    okln "no known-shape secret inlined"
  fi
  # Generic high-entropy: a long base64/hex run. WARN only — a correlation hash looks like this.
  if grep -qE '[A-Za-z0-9+/]{48,}={0,2}' "$MSG"; then
    warn "a long high-entropy token is present — if it is a secret, replace it with a pointer (advisory; not failing)"
  fi

  echo
  [ "$FAIL" -eq 0 ] && { echo "VERDICT: OK — envelope is a well-formed, secret-free pointer."; exit 0; }
  echo "VERDICT: VIOLATION — fix the above before this message is sent."; exit 1
fi

# =================================================================================================
# repo-hygiene mode (default)
# =================================================================================================
ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "handoff-lint: cannot cd to '$ROOT'" >&2; exit 2; }

command -v git >/dev/null 2>&1 || { echo "handoff-lint: git is not installed — cannot verify hygiene." >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "handoff-lint: '$ROOT' is not a git repository." >&2; exit 2; }

echo "handoff-lint (repo-hygiene): $ROOT"

# 1. temp/ must be gitignored. `git check-ignore` evaluates the ignore rules against the pathname
#    whether or not the directory exists yet — so this is a statement about the RULE, not about
#    today's contents.
if git check-ignore -q temp 2>/dev/null || git check-ignore -q temp/ 2>/dev/null; then
  okln "temp/ is gitignored"
else
  bad "temp/ is NOT gitignored — the file-based mailbox must be scratch; add 'temp/' to .gitignore"
fi

# 2. Nothing under temp/ may be TRACKED. A force-added file is the failure this whole design guards
#    against, and it is invisible to a reviewer: a tracked file looks like any other.
TRACKED="$(git ls-files -- temp temp/ 2>/dev/null | grep -v '^$' | tr '\n' ' ' || true)"
if [ -z "$TRACKED" ]; then
  okln "no tracked files under temp/"
else
  bad "tracked file(s) under temp/: $TRACKED — the mailbox is committed; untrack (git rm --cached) them"
fi

echo
[ "$FAIL" -eq 0 ] && { echo "VERDICT: OK — handoff hygiene holds."; exit 0; }
echo "VERDICT: VIOLATION — the file-based handoff invariant is broken; fix the above."; exit 1
