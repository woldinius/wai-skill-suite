#!/usr/bin/env sh
# catalog-lint.sh — the missing third operation.
#
# A knowledge base has three: ingest (init and the audits WRITE the catalog), query (nine skills
# READ it) — and lint. This suite had the first two and never the third, which is how 55 of 89
# dimensions came to have no Red Flag while every skill was being told to "look up the Red Flag
# for ID X". Nobody noticed, because nothing checked.
#
#   exit 0  the catalog is internally consistent
#   exit 1  a check failed — the reasons are printed
#   exit 2  the catalog could not be read at all
#
# Usage: sh catalog-lint.sh [path-to-catalog]     (default: docs/architecture/quality-attributes.md)
#        Every default path is read from the repo root; outside a git repo, from the cwd.

set -eu
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX pattern semantics required

# DEFAULT PATHS ARE REPO-RELATIVE, NOT CWD-RELATIVE — merge-gate.sh's rule: the documented calls run
# from a skill's directory. Inside a git worktree the lint works from its root; outside one the cwd
# stays the base. An explicit argument still wins, read against the cwd it was given in.
# Why: docs/rationale/catalog-lint.md § Default paths resolve against the repo root
CAT="${1:-docs/architecture/quality-attributes.md}"
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"   # before any cd: $0 may be relative
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$REPO_ROOT" ]; then
  if [ -n "${1:-}" ]; then case "$CAT" in /*) ;; *) CAT="$PWD/$CAT" ;; esac; fi
  cd "$REPO_ROOT" 2>/dev/null || { echo "catalog-lint: cannot enter the repo root $REPO_ROOT" >&2; exit 2; }
fi
[ -f "$CAT" ] || { echo "catalog-lint: no catalog at $CAT" >&2; exit 2; }

# The BASELINE — the suite's own full catalog, shipped inside wai-init. Two checks need it,
# for two different reasons: it is what the vendored skills were written against (check 4), and it
# is where a missing Red Flag can be recovered from (check 1).
BASE=".claude/skills/wai-init/references/quality-attributes.baseline.md"
# A PLUGIN INSTALL VENDORS NOTHING INTO THE REPO (#95): the baseline ships beside this script, in the
# plugin cache. Without this fallback checks 1, 4a and 7 lost their baseline there, and check 7 — the
# local-ID number space — was skipped without a word: a false clean. A copy vendored in the repo
# still wins: it is the one the vendored skills (check 4b) were written against.
[ -f "$BASE" ] || [ -z "$SELF_DIR" ] || BASE="$SELF_DIR/../references/quality-attributes.baseline.md"

FAIL=0
note() { echo "  ✗ $1"; FAIL=1; }
pass() { echo "  ✓ $1"; }
skip() { echo "  ⚠ $1"; }              # not checked — and saying so, rather than reporting green
hint() { echo "      $1"; }

ids_in() { grep -oE '^- \*\*[A-Z]+-[0-9]+' "$1" | sed 's/^- \*\*//' | sort -u; }

# The retired section reads: `MAINT-4` → `SEC-8` + `MAINT-1` · … — the retired ID is the one BEFORE
# the arrow; the ones after it are live targets and must not be collected.
# shellcheck disable=SC2016  # the backtick is a literal in the markdown, not an expansion
retired_in() { sed -n '/^## Retired IDs/,$p' "$1" | tr '\n' ' ' \
               | grep -oE '`[A-Z]+-[0-9]+` *→' | grep -oE '[A-Z]+-[0-9]+' | sort -u; }

# IDs whose entry carries NO Red Flag. The block is accumulated whole before it is tested, so a
# `*Red\n  Flag:*` wrapped across lines still counts — the same flattening the count relies on.
no_flag_in() {
  awk '
    function flush() { if (id != "" && buf !~ /\*Red[ ]*Flag:\*/) print id }
    /^- \*\*[A-Z]+-[0-9]+/ { flush(); id = $0
                             sub(/^- \*\*/, "", id); sub(/[^A-Z0-9-].*/, "", id)
                             buf = $0; next }
    /^#/                   { flush(); id = ""; buf = ""; next }
                           { buf = buf " " $0 }
    END                    { flush() }
  ' "$1"
}

BT='`'                                 # a literal backtick, so nothing below has to escape one
# Where the baseline MOVED a retired ID. The mapping is right there in `## Retired IDs`
# (`API-3` → `MAINT-5`), and reading it by hand is the slowest part of acting on this lint — so
# the script reads it. A finding that names the repair is a finding people act on.
retire_target() {                      # $1 = a retired ID
  sed -n '/^## Retired IDs/,$p' "$BASE" | tr '\n' ' ' \
    | grep -oE "$BT$1$BT *→[^·]*" | head -1 \
    | sed -e "s/^$BT$1$BT *→ *//" -e "s/$BT//g" -e 's/[ .]*$//'
}

# shellcheck disable=SC2016  # the backtick is a literal in the markdown, not an expansion
cited_in() {                           # $1 = newline-separated file list
  [ -n "$1" ] || return 0
  # A CITATION IS A BACKTICKED ID — everywhere in this suite. `SEC-3` claims the ID exists and is
  # checked here; "SEC-99" in plain quotes discusses one and is not. The backtick is load-bearing.
  # Why: docs/rationale/catalog-lint.md § A citation is a backticked ID
  grep -hoE '`(AI|RES|OBS|SEC|GDPR|API|MAINT|PERF|PAY|CLIENT|IOS|AND|WEB)-[0-9]+`' $1 2>/dev/null \
    | tr -d '`' | sort -u
}

echo "catalog-lint: $CAT"

LIVE="$(ids_in "$CAT")"
RETIRED="$(retired_in "$CAT")"
BASE_IDS=""; BASE_RET=""; BASE_NOFLAG=""
if [ -f "$BASE" ]; then
  BASE_IDS="$(ids_in "$BASE")"
  BASE_RET="$(retired_in "$BASE")"
  BASE_NOFLAG="$(no_flag_in "$BASE")"
fi

# --- 1. Every dimension carries a Red Flag ------------------------------------------------------
# The Red Flag is the operative content: it is what makes a finding decidable, and what the tier
# dial promises to keep at every size. A dimension without one is decoration — the reviewer either
# invents a bar for the session or silently declines to raise the finding, and the output looks
# identical either way.
IDS="$(grep -cE '^- \*\*[A-Z]+-[0-9]+' "$CAT" || true)"
# Flatten continuation lines so a wrapped `*Red\n  Flag:*` still counts.
FLAGS="$(tr '\n' ' ' < "$CAT" | grep -o '\*Red *Flag:\*' | grep -c . || true)"
if [ "$IDS" -eq "$FLAGS" ]; then
  pass "$IDS dimensions, $FLAGS Red Flags — every dimension is decidable"
else
  note "$IDS dimensions but only $FLAGS Red Flags — $((IDS - FLAGS)) are not decidable"
  # A COUNT IS NOT A REPAIR. Name them, and say which of two very different jobs each one is.
  #
  # A catalog tailored from an OLDER baseline inherits that baseline's holes and is never told so:
  # install.sh updates the skills, not the artifacts they generated. The first field install of a
  # second repo landed 34 dimensions short — every one of them already fixed upstream, and nothing
  # anywhere failed. A finding with no repair path is a finding people learn to scroll past.
  STALE=""; ORPHAN=""; COLLIDE=""
  if [ -n "$BASE_IDS" ]; then
    for m in $(no_flag_in "$CAT"); do
      if printf '%s\n' "$BASE_RET" | grep -qx "$m"; then
        # Do NOT tell anyone to author a Red Flag for this one. The baseline RETIRED this number,
        # and a catalog still carrying it is most likely one cut BEFORE that renumbering — writing
        # it a Red Flag would cement a dimension the baseline has already moved somewhere else.
        # (It may also be a genuinely local dimension that happens to collide. The script says
        # which two readings are open; it does not pretend to know which one is true.)
        COLLIDE="$COLLIDE $m"
      elif printf '%s\n' "$BASE_IDS" | grep -qx "$m" &&
           ! printf '%s\n' "$BASE_NOFLAG" | grep -qx "$m"; then
        STALE="$STALE $m"
      else
        ORPHAN="$ORPHAN $m"
      fi
    done
  else
    ORPHAN=" $(no_flag_in "$CAT" | tr '\n' ' ')"
  fi
  if [ -n "$STALE" ]; then
    hint "the shipped baseline HAS a Red Flag for these — your catalog predates it:$STALE"
    hint "→ re-run wai-init (reconcile) to pull them in. No authoring required."
  fi
  [ -z "$ORPHAN" ]  || hint "your own dimensions — nobody upstream will ever supply these. Author one:$ORPHAN"
  if [ -n "$COLLIDE" ]; then
    hint "and these are numbers the baseline RETIRED — do NOT author a Red Flag for them:"
    for m in $COLLIDE; do hint "  $m — the baseline moved this number to: $(retire_target "$m")"; done
    hint "→ if yours means the same thing, it is a pre-renumbering leftover: reconcile."
    hint "  If it is genuinely your own dimension, renumber it — otherwise a skill citing it"
    hint "  means the baseline's dimension, and no reader can tell which."
  fi
fi

# --- 2. No duplicate IDs -----------------------------------------------------------------------
DUP="$(grep -oE '^- \*\*[A-Z]+-[0-9]+' "$CAT" | sort | uniq -d | sed 's/^- \*\*//' | tr '\n' ' ')"
if [ -z "$DUP" ]; then pass "no duplicate IDs"; else note "duplicate IDs: $DUP"; fi

# --- 3. No retired ID is reused ------------------------------------------------------------------
# A reused number silently rewrites the meaning of every past finding that cited it. `## Retired IDs`
# is a record, not prose to be trimmed at a smaller tier.
# Why: docs/rationale/catalog-lint.md § No retired ID is reused
N_RET="$(printf '%s\n' "$RETIRED" | grep -c '[A-Z]' || true)"
REUSED=""
for r in $RETIRED; do
  if grep -qE "^- \*\*$r ·" "$CAT"; then REUSED="$REUSED $r"; fi
done
if [ -z "$REUSED" ]; then
  pass "no retired ID reused ($N_RET retired)"
else
  note "RETIRED IDs reused as live dimensions:$REUSED — every past finding citing them now means something else"
fi

# --- 4. Every ID a CONSUMER cites actually exists ------------------------------------------------
# TWO CLASSES OF CONSUMER, AND THEY DO NOT RESOLVE AGAINST THE SAME CATALOG:
#   · the repo's own DOCS (plans, audits, ADRs, testing strategy) resolve against the REPO catalog;
#   · the vendored SUITE SKILLS resolve against the BASELINE that shipped beside them — a repo
#     tailors its catalog to a SUBSET, so resolving skills against it fails BY CONSTRUCTION.
#   · `field-reports/` is EXCLUDED (ADR-0003): foreign documents live in another repo's ID space.
#     They are evidence — never edit one to satisfy a checker.
# Why: docs/rationale/catalog-lint.md § Two classes of consumer, two catalogs
DOCS="$(find docs -name '*.md' ! -name 'quality-attributes.md' ! -path '*/field-reports/*' 2>/dev/null || true)"
# EVERY file a skill ships, not just its markdown. The load-bearing citations are not in the prose:
# they are in the CI template and the merge gate, which anchor a guard to the dimension that
# justifies it. Scanning `*.md` only, this check read the essays and skipped the enforcement — and
# reported ✓ while two of the suite's own artifacts cited a retired ID.
SKILLS="$(find .claude/skills -type f ! -path '*/wai-init/*' 2>/dev/null || true)"

# 4a — the repo's own consumers, against the repo's catalog. A retired ID is fine to cite: old
#      findings must stay resolvable. THREE consumers, each named in its finding:
#        · docs/ (the list above);
#        · the live catalog's OWN cross-references ("Generalizes `PAY-1`") — EXCEPT its
#          `## Retired IDs` section, which cites retired IDs by design (`IOS-2` → `CLIENT-2`);
#        · the agent instruction files at the root, CLAUDE.md and AGENTS.md — a missing one is not
#          an error, it is simply not scanned.
# Why: docs/rationale/catalog-lint.md § The catalog and the agent files are consumers too
# The catalog minus `## Retired IDs` (up to the next `## ` heading, so a section after it is read).
# shellcheck disable=SC2016  # the backtick is a literal in the markdown, not an expansion
catalog_refs() {
  awk '/^## Retired IDs/ { skip = 1; next } /^## / { skip = 0 } !skip' "$CAT" 2>/dev/null \
    | grep -oE '`(AI|RES|OBS|SEC|GDPR|API|MAINT|PERF|PAY|CLIENT|IOS|AND|WEB)-[0-9]+`' \
    | tr -d '`' | sort -u
}
AGENT_FILES=""
for a in CLAUDE.md AGENTS.md; do [ -f "$a" ] && AGENT_FILES="$AGENT_FILES $a"; done
AGENT_FILES="${AGENT_FILES# }"
FOUND_4A=0
# $3 = master-ok: a baseline-only ID is a pointer at the master, not a finding. That holds for the
# CATALOG's own prose only — the variant banner says so ("prose may still reference an ID that only
# the platform master carries"), and wai-init lints right after copying a variant. Docs and agent
# files still get the adopt-or-fix finding. An ID that exists NOWHERE fails for every source.
# THE TRADE-OFF, stated: master-ok covers the repo's OWN dimensions too, so a re-point to an ID the
# catalog tailored away passes inside the catalog, while the same citation fails in docs/ (both
# pinned in tests/run.sh). Why: docs/rationale/catalog-lint.md § The catalog and the agent files are consumers too
check_4a() {   # $1 = where the citations sit (named in the finding) · $2 = cited IDs, one per line
  _adopt=""; _drift=""
  for c in $2; do
    printf '%s\n' "$LIVE"    | grep -qx "$c" && continue
    printf '%s\n' "$RETIRED" | grep -qx "$c" && continue
    if printf '%s\n' "$BASE_IDS" | grep -qx "$c"; then
      [ "${3:-}" = master-ok ] && continue
      _adopt="$_adopt $c"       # the baseline defines it; this repo tailored it away or never took it
    else
      _drift="$_drift $c"       # it exists nowhere: either the citation is wrong, or the ID is new
    fi
  done
  # These are two different repairs, so they are two different findings.
  [ -z "$_adopt" ] || { FOUND_4A=1; note "cited in $1, defined in the baseline, absent from YOUR catalog:$_adopt — adopt them via wai-init, or fix the citation"; }
  [ -z "$_drift" ] || { FOUND_4A=1; note "cited in $1 but neither live nor retired nor in the baseline:$_drift — the finding that cites them is unverifiable"; }
  return 0
}
check_4a "docs/" "$(cited_in "$DOCS")"
check_4a "the catalog's own cross-references" "$(catalog_refs)" master-ok
# shellcheck disable=SC2086  # the file list must word-split
[ -z "$AGENT_FILES" ] || check_4a "$AGENT_FILES" "$(cited_in "$(printf '%s\n' $AGENT_FILES)")"
if [ "$FOUND_4A" -eq 0 ]; then
  pass "every catalog ID cited by the repo's docs, the catalog's own cross-references${AGENT_FILES:+ and $AGENT_FILES} resolves"
fi

# 4b — the vendored skills, against the baseline they shipped with.
if [ -z "$SKILLS" ]; then
  :                                    # nothing vendored here, nothing to resolve
elif [ -z "$BASE_IDS" ]; then
  skip "skill citations unchecked — no baseline at $BASE (is wai-init installed?)"
else
  # A DOC may cite a retired ID — an audit from March must stay readable. What must never happen is
  # a LIVE consumer resolving one, so the check is scoped to consumers, not to history.
  # Why: docs/rationale/catalog-lint.md § A doc may cite a retired ID
  UNKNOWN=""; DEAD=""
  for c in $(cited_in "$SKILLS"); do
    printf '%s\n' "$BASE_IDS" | grep -qx "$c" && continue
    if printf '%s\n' "$BASE_RET" | grep -qx "$c"; then DEAD="$DEAD $c"; continue; fi
    # The repo's OWN skills sit under .claude/skills too — in a plugin install they are the only ones
    # there — and they may cite the repo's own dimensions: an ID live in THIS catalog (a local one at
    # >= 100, or a declared one) resolves (#95). Checked AFTER the retired list, so a number the
    # baseline retired stays DEAD even where a catalog re-mints it. A suite skill citing a local ID
    # still fails in the suite's own repo, whose catalog defines none.
    printf '%s\n' "$LIVE" | grep -qx "$c" && continue
    UNKNOWN="$UNKNOWN $c"
  done
  if [ -z "$UNKNOWN$DEAD" ]; then
    pass "every ID a skill cites is a LIVE baseline dimension, or a live dimension of this catalog"
  else
    [ -z "$UNKNOWN" ] || note "a SKILL cites an ID neither the baseline nor this catalog defines:$UNKNOWN"
    if [ -n "$DEAD" ]; then
      note "a SKILL cites a RETIRED baseline ID:$DEAD — every finding anchored to it points at a dimension that has moved"
      for d in $DEAD; do hint "$d — the baseline moved this number to: $(retire_target "$d")"; done
    fi
    # WHOSE BUG, AND WHOSE REPAIR? The manifest answers it: install.sh writes one, and it means
    # these skills are vendored. Telling a consuming repo to "re-point the citation" would be
    # telling it to edit files the installer owns and will overwrite — advice that is both wrong
    # and destructive. Upstream, the same finding is a one-line fix.
    if [ -f .claude/.wai-suite-manifest ]; then
      hint "→ these skills are VENDORED (install.sh owns them). Do not edit them here — update the"
      hint "  suite and re-install. Until then, every finding anchored to the above is misfiled."
    else
      hint "→ re-point the citation at the live dimension."
    fi
  fi
fi

# --- 6. A COPIED file must never cite a catalog ID ------------------------------------------------
# A template that ships a bare ID rebinds it on copy: the number lands in a repo whose catalog gives
# it a different meaning. Templates cite families, never numbers.
# Why: docs/rationale/catalog-lint.md § A copied file must never cite a catalog ID
TEMPLATES="$(find .claude/skills \( -path '*/templates/*' -o -name '*.template' \) -type f 2>/dev/null || true)"
if [ -n "$TEMPLATES" ]; then
  # Bare, not just backticked: a copied file rebinds whether or not someone wrote the backtick.
  # shellcheck disable=SC2086  # the file list must word-split
  TPL="$(grep -loE '(AI|RES|OBS|SEC|GDPR|API|MAINT|PERF|PAY|CLIENT|IOS|AND|WEB)-[0-9]+' $TEMPLATES 2>/dev/null \
         | sed 's|.*/||' | sort -u | tr '\n' ' ' || true)"
  if [ -z "$TPL" ]; then
    pass "no copied template cites a catalog ID — they would rebind on copy"
  else
    note "a COPIED template cites a catalog ID: $(printf '%s' "$TPL" | sed 's/ *$//') — on copy the number rebinds to this repo's ID space"
    if [ -f .claude/.wai-suite-manifest ]; then
      hint "→ VENDORED (install.sh owns them). Do not edit them here — update the suite and re-install."
    else
      hint "→ name the dimension instead of numbering it. Names do not collide; numbers do."
    fi
  fi
fi

# --- 7. A locally-minted dimension must sit outside the baseline's number space -------------------
# Mint at >= 100. A local `SEC-12` collides with the baseline's `SEC-12` the day the baseline grows,
# and the collision is silent — two documents, same citation, different meaning.
# Why: docs/rationale/catalog-lint.md § Locally-minted IDs sit outside the baseline number space
if [ -n "$BASE_IDS" ]; then
  DECLARED="$(sed -n '/^## Local IDs/,/^## /p' "$CAT" | grep -oE '[A-Z]+-[0-9]+' | sort -u || true)"
  UNDECLARED=""
  for i in $LIVE; do
    # WHAT THESE TWO LINES CANNOT SEE, stated because a checker that hides its blind spot is worse than
    # none: they compare ID STRINGS, never meanings — a dimension whose prose drifted from its ID reads
    # as perfectly consistent here.
    # Why: docs/rationale/catalog-lint.md § What these two lines cannot see
    printf '%s\n' "$BASE_IDS"  | grep -qx "$i" && continue      # in the baseline — assumed adopted
    printf '%s\n' "$BASE_RET"  | grep -qx "$i" && continue      # a number the baseline retired
    n="${i##*-}"
    [ "$n" -ge 100 ] && continue                                # minted local, out of harm's way
    printf '%s\n' "$DECLARED"  | grep -qx "$i" && continue      # declared debt, permanent by design
    UNDECLARED="$UNDECLARED $i"
  done
  if [ -z "$UNDECLARED" ]; then
    pass "every local dimension is either ≥ 100 or declared under '## Local IDs'"
    hint "not covered: a number SHARED with the baseline is only ASSUMED to mean the same thing. A"
    hint "misbinding resolves, so no lint sees it — wai-init judges that on reconcile, and the"
    hint "answer belongs in '## Reused Baseline IDs'. Two debts, two repairs; this check sees one." 
  else
    note "minted here, inside the baseline's number space, undeclared:$UNDECLARED — a future baseline dimension can take these numbers and mean something else"
    hint "→ mint NEW local dimensions at ≥ 100 (MAINT-100, never MAINT-10)."
    hint "  These cannot be renumbered without breaking every citation that already exists, so"
    hint "  declare them under a '## Local IDs' section instead. That declaration is the"
    hint "  translation table you will need for as long as the repo lives."
  fi
else
  skip "local-ID number space unchecked — no baseline at $BASE"
fi

echo
[ "$FAIL" -eq 0 ] && echo "VERDICT: OK" || echo "VERDICT: FAILED — the catalog is not internally consistent."
exit "$FAIL"
