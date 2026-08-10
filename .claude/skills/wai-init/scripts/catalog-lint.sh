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

set -eu
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX pattern semantics required

CAT="${1:-docs/architecture/quality-attributes.md}"
[ -f "$CAT" ] || { echo "catalog-lint: no catalog at $CAT" >&2; exit 2; }

# The BASELINE — the suite's own full catalog, shipped inside wai-init. Two checks need it,
# for two different reasons: it is what the vendored skills were written against (check 4), and it
# is where a missing Red Flag can be recovered from (check 1).
BASE=".claude/skills/wai-init/references/quality-attributes.baseline.md"

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
  # A CITATION IS A BACKTICKED ID. That is the suite's convention everywhere — the catalog, the
  # skills, the plan and audit templates all write `SEC-3`. Requiring the backticks is not
  # pedantry; it is what keeps this check honest.
  #
  # An earlier version used `.` as a wildcard where the backtick belongs, and matched substrings.
  # On its first field run it produced a 50% false-positive rate and BLOCKED a PR: it read `API-5`
  # out of an alert named `API-5xx-Rate`, and `AI-503` out of the prose "there is no AI-503 to
  # retry". Neither is a citation. The closing backtick is the boundary that makes them not match.
  # shellcheck disable=SC2086  # the file list must word-split
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

# --- 3. No retired ID is reused ----------------------------------------------------------------
# `## Retired IDs` exists because an ID string is the only linking primitive the suite has: every
# review, plan, issue and audit cites them. Reusing one silently rewrites the meaning of every
# finding that ever cited it.
#
# THIS CHECK IS DELIBERATELY REPO-LOCAL, AND THAT IS NOT AN OVERSIGHT.
# The obvious "improvement" is to also fail a live dimension whose ID the BASELINE retired. I wrote
# it, ran it, and it failed a repo that was right: that repo has `MAINT-6 · Type-Check & Lint Gate
# in CI` — live, closed, cited by its own issues — while the baseline retired its own MAINT-6 (a
# modularity dimension) into `MAINT-1`. Same number, two ID SPACES, two unrelated concepts. Telling
# that repo to renumber would have broken every citation in its issues and ADRs for nothing.
#
# Deciding whether two dimensions on the same number MEAN the same thing is a semantic judgment, and
# a shell script cannot make it. Same line as the merge gate: the script owns mechanics, the model
# owns judgment — and a check that renders a verdict it cannot justify is how a lint gets switched
# off. What IS mechanically decidable lives in check 4b: a *skill* must cite a LIVE baseline ID.
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

# --- 4. Every ID a CONSUMER cites actually exists -----------------------------------------------
# TWO CLASSES OF CONSUMER, AND THEY DO NOT RESOLVE AGAINST THE SAME CATALOG.
#
# The repo's own DOCS — plans, audits, ADRs, the testing strategy — cite the repo's catalog. A
# citation that does not resolve there is doc drift, and doc drift is what this check is for.
#
# The SUITE SKILLS are vendored: installed by install.sh, owned by a manifest, authored elsewhere.
# They were written against the BASELINE that ships beside them, and they cite ~80 of its IDs.
# A repo tailors its catalog to its surfaces — to a SUBSET. So resolving skill citations against
# the tailored catalog fails BY CONSTRUCTION in every consuming repo, on files that repo does not
# own and cannot fix. The first field install of a second repo produced 26 such "findings"; not
# one of them was actionable. A check nobody can obey is a check everybody turns off — and then it
# is worse than no check, because it is still right about the things it does catch and nobody is
# reading it any more.
#
# So skills resolve against the baseline they shipped with. That keeps the bug this check was
# written to catch — a skill citing `SEC-4` for IDOR when IDOR is `SEC-8` — while never failing a
# repo for the entirely correct act of tailoring.
# `field-reports/` is EXCLUDED, and that is ADR-0003, not an exemption.
# Those files are verbatim documents from OTHER repos, written in ANOTHER repo's ID space. Their
# `MAINT-10` is theirs; ours does not exist. The boundary rule says an ID never crosses that line —
# so linting a foreign document against our catalog is the same category error the skill scan used to
# make, and the answer is the same: resolve each document against the catalog it was written for.
# They are evidence. Never edit one to satisfy a checker. If a field report is wrong, THAT IS THE
# EVIDENCE (one of them was — a sixteen-minute-stale tool reported four non-problems). Annotate it in
# `empirics.md`; do not touch the report.
DOCS="$(find docs -name '*.md' ! -name 'quality-attributes.md' ! -path '*/field-reports/*' 2>/dev/null || true)"
# EVERY file a skill ships, not just its markdown. The load-bearing citations are not in the prose:
# they are in the CI template and the merge gate, which anchor a guard to the dimension that
# justifies it. Scanning `*.md` only, this check read the essays and skipped the enforcement — and
# reported ✓ while two of the suite's own artifacts cited a retired ID.
SKILLS="$(find .claude/skills -type f ! -path '*/wai-init/*' 2>/dev/null || true)"

# 4a — the repo's docs, against the repo's catalog. A retired ID is fine to cite: old findings must
#      stay resolvable.
DRIFT=""; ADOPTABLE=""
for c in $(cited_in "$DOCS"); do
  printf '%s\n' "$LIVE"    | grep -qx "$c" && continue
  printf '%s\n' "$RETIRED" | grep -qx "$c" && continue
  if printf '%s\n' "$BASE_IDS" | grep -qx "$c"; then
    ADOPTABLE="$ADOPTABLE $c"   # the baseline defines it; this repo tailored it away or never took it
  else
    DRIFT="$DRIFT $c"           # it exists nowhere: either the citation is wrong, or the ID is new
  fi
done
if [ -z "$DRIFT$ADOPTABLE" ]; then
  pass "every catalog ID cited by the repo's docs resolves"
else
  # These are two different repairs, so they are two different findings.
  [ -z "$ADOPTABLE" ] || note "cited in docs/, defined in the baseline, absent from YOUR catalog:$ADOPTABLE — adopt them via wai-init, or fix the citation"
  [ -z "$DRIFT" ]     || note "cited in docs/ but neither live nor retired nor in the baseline:$DRIFT — the finding that cites them is unverifiable"
fi

# 4b — the vendored skills, against the baseline they shipped with.
if [ -z "$SKILLS" ]; then
  :                                    # nothing vendored here, nothing to resolve
elif [ -z "$BASE_IDS" ]; then
  skip "skill citations unchecked — no baseline at $BASE (is wai-init installed?)"
else
  # A DOC may cite a retired ID — an audit from March must stay readable, and that is what the
  # retired list is FOR. A SKILL may not. A skill is a live instruction executed today: the ID it
  # cites is the dimension a finding will be anchored to, so it has to point at one that still
  # exists. Citing a retired number anchors every future finding to a meaning that has moved.
  #
  # Not hypothetical: this caught two of the suite's own artifacts citing `MAINT-6` for the
  # stub-gate incident — a number the suite's OWN baseline retired into `MAINT-1` (modularity).
  # The ID had been carried in from the repo where the incident happened, where MAINT-6 really is
  # the lint gate. In the suite's ID space it means nothing at all.
  UNKNOWN=""; DEAD=""
  for c in $(cited_in "$SKILLS"); do
    printf '%s\n' "$BASE_IDS" | grep -qx "$c" && continue
    if printf '%s\n' "$BASE_RET" | grep -qx "$c"; then DEAD="$DEAD $c"; else UNKNOWN="$UNKNOWN $c"; fi
  done
  if [ -z "$UNKNOWN$DEAD" ]; then
    pass "every ID a skill cites is a LIVE baseline dimension"
  else
    [ -z "$UNKNOWN" ] || note "a SKILL cites an ID the baseline does not define:$UNKNOWN"
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

# --- 6. A COPIED file must never cite a catalog ID ----------------------------------------------
# The vendored skills are safe: check 5 resolves their citations against the baseline, and install.sh
# owns them, so they are never edited in place. TEMPLATES ARE NOT VENDORED — they are COPIED into the
# repo, and the instant they are, every ID in them rebinds to the REPO's ID space.
#
# The trap fired here. A ci.yml comment was re-pointed from `MAINT-6` to `MAINT-3`. Correct upstream.
# Ported downstream it would have been WRONG — in that repo `MAINT-6` IS the lint gate and `MAINT-3`
# is something else. And nothing would have caught it: `MAINT-3` is a valid, live, resolvable local
# ID. It is a semantic MISbinding, not a dangling one, so no reference checker sees it, and it looks
# exactly like applying an upstream fix — which is what one is supposed to do.
#
# So a copied file NAMES the dimension and never numbers it. Names do not collide.
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

# --- 7. A locally-minted dimension must sit outside the baseline's number space -----------------
# An ID carries no provenance. `MAINT-3` looks identical whether it is the baseline's or this repo's
# own — and that is the root of every collision the suite has hit. The split: the baseline owns the
# low numbers, a repo that mints its OWN dimension starts at 100. Two digits shared, three digits
# local, readable at a glance and checkable here.
#
# Pre-existing sub-100 locals are PERMANENT (an ID is never reassigned), so they are DECLARED under
# `## Local IDs` rather than renumbered. That declaration is the translation table — the thing that
# has to exist forever anyway. Failing on them forever instead would just get this check switched off.
if [ -n "$BASE_IDS" ]; then
  DECLARED="$(sed -n '/^## Local IDs/,/^## /p' "$CAT" | grep -oE '[A-Z]+-[0-9]+' | sort -u || true)"
  UNDECLARED=""
  for i in $LIVE; do
    # WHAT THESE TWO LINES CANNOT SEE — and the comment must not pretend otherwise.
    # An ID present in the baseline is ASSUMED adopted. It is never verified to MEAN the same thing.
    # A number that means one thing here and another upstream is a MISBINDING: the reference resolves,
    # nothing dangles, and no lint can see it. One field repo holds FIVE of them right now — its
    # `SEC-8` is CSRF hardening where the baseline's is IDOR — and every one of them passes here.
    # This check catches the FUTURE hazard (a new local mint a later baseline dimension could take).
    # It is blind to the LIVE one, which is the dangerous half. Saying so is the whole point: a green
    # check that implies coverage it structurally cannot have is worse than a red one.
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
fi

echo
[ "$FAIL" -eq 0 ] && echo "VERDICT: OK" || echo "VERDICT: FAILED — the catalog is not internally consistent."
exit "$FAIL"
