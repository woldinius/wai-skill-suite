#!/usr/bin/env sh
# tests/run.sh — the wai-learning-gap scripts, tested on TWO shells.
#
# These scripts are the ADR-0002 mechanics of a skill that had none: the opt-in gate, the one-open-
# gap invariant, the "a gap must go red" probe, the ledger lint, the hook installer, the order-
# neutraliser, and the post-run PR shortlist. Each is a gate or an emitter, and the suite has
# already paid, twice, for the two ways a shell gate ships broken:
#
#   · A `case … esac` inside `$( )` is a syntax error in bash 3.2 — which is what /bin/sh IS on
#     macOS — and shellcheck passes it. So every case here runs under BOTH dash and bash 3.2.
#   · A gate you have only ever seen FAIL is not a validated gate. So every script is exercised on
#     its GO path (exit 0) as deliberately as on its NO path — an open-gap check that has never
#     said "safe to plant" is an untested branch that happens to be failing closed.
#
# Self-contained: no network, gh is stubbed, git repos are built in a temp dir, the classifier is
# stubbed via EXCLUDED_DOMAINS_SH. Run:  sh tests/run.sh
set -u
[ -n "${ZSH_VERSION:-}" ] && exec /bin/sh "$0" "$@"

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$HERE/.." && pwd)"                 # the scripts dir under test
FIX="$HERE/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# The shells under test: dash (a strict POSIX sh) and bash (3.2 on macOS). Fall back to /bin/sh only
# if neither is installed, so the harness still runs somewhere — but the point is the two.
SHELLS=""
for c in dash bash; do command -v "$c" >/dev/null 2>&1 && SHELLS="$SHELLS $c"; done
[ -n "$SHELLS" ] || SHELLS="sh"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n         %s\n' "$1" "$2"; }

# assert NAME WANT-EXIT GOT-EXIT OUTPUT [MUST-MATCH] [MUST-NOT-MATCH]
assert() {
  _n="$1"; _we="$2"; _ge="$3"; _out="$4"; _m="${5:-}"; _x="${6:-}"; _why=""
  if   [ "$_ge" != "$_we" ];                                     then _why="exit $_ge, wanted $_we"
  elif [ -n "$_m" ] && ! printf '%s\n' "$_out" | grep -qE "$_m"; then _why="no match for /$_m/"
  elif [ -n "$_x" ] &&   printf '%s\n' "$_out" | grep -qE "$_x"; then _why="matched /$_x/ and must not"
  fi
  if [ -z "$_why" ]; then ok "$_n"; else
    bad "$_n" "$_why"; printf '%s\n' "$_out" | sed 's/^/         | /'
  fi
}

# A fresh, committed git repo with a tracked file.
gitrepo() {
  _r="$1"; mkdir -p "$_r/src"
  git -C "$_r" init -q
  git -C "$_r" config user.email t@t.t
  git -C "$_r" config user.name  t
  printf 'ok\n' > "$_r/src/a.txt"
  git -C "$_r" add -A
  git -C "$_r" commit -q -m init
}

echo "wai-learning-gap scripts — shells:$SHELLS"

for SH in $SHELLS; do
  echo
  echo "── $SH ─────────────────────────────────────────────────────────────────────────────────"

  # ── verify-gap-breaks.sh ──────────────────────────────────────────────────────────────────────
  # A cloze/structural gap MUST make the tree red; a socratic gap stays green BY DESIGN and is N/A.
  V="$S/verify-gap-breaks.sh"

  out="$("$SH" "$V" --form socratic 2>&1)"; rc=$?
  assert "$SH verify: socratic is N/A → 0 (skipped, not run)" 0 "$rc" "$out" 'N/A|skipped'

  out="$("$SH" "$V" --form cloze false 2>&1)"; rc=$?
  assert "$SH verify: cloze went RED → 0 (gap breaks, valid)" 0 "$rc" "$out" 'breaks visibly|Valid'

  out="$("$SH" "$V" --form structural false 2>&1)"; rc=$?
  assert "$SH verify: structural went RED → 0" 0 "$rc" "$out" 'Valid|breaks'

  # THE SILENT-GREEN GAP — the bug this script exists to catch: the line was removed and NOTHING
  # broke, so the human never notices and the box gets promoted for an exercise nobody did.
  out="$("$SH" "$V" --form cloze true 2>&1)"; rc=$?
  assert "$SH verify: still GREEN → 1 (silent success, replant)" 1 "$rc" "$out" 'still green|Replant|PASSED'

  out="$("$SH" "$V" --form cloze no_such_cmd_xyz 2>&1)"; rc=$?
  assert "$SH verify: test cmd not found → 2 (UNKNOWN, never a pass)" 2 "$rc" "$out" 'not found|UNKNOWN'

  out="$("$SH" "$V" --form cloze 2>&1)"; rc=$?
  assert "$SH verify: no command for a code gap → 2 (cannot verify)" 2 "$rc" "$out" 'cannot verify|no test command'

  out="$("$SH" "$V" 2>&1)"; rc=$?
  assert "$SH verify: no --form → 2 (misuse, fail closed)" 2 "$rc" "$out" 'form'

  out="$("$SH" "$V" --form nonsense true 2>&1)"; rc=$?
  assert "$SH verify: bad --form value → 2" 2 "$rc" "$out" 'unknown --form'

  # ── shuffle-ingredients.sh ────────────────────────────────────────────────────────────────────
  # Deterministic order-neutraliser: within each bucket the items come out SORTED, bucket labels
  # keep their given order, and the transform is stable (same input → same output, every run).
  SHUF="$S/shuffle-ingredients.sh"

  out="$("$SH" "$SHUF" < "$FIX/bucket-good.txt" 2>&1)"; rc=$?
  assert "$SH shuffle: valid buckets → 0" 0 "$rc" "$out" 'calls/keywords'
  # order-signal-free: 'await' sorts before 'map' regardless of the order they were listed in.
  first_item="$(printf '%s\n' "$out" | awk 'NR==2{print; exit}')"
  assert "$SH shuffle: first bucket item is sorted (await before map)" 0 \
    "$([ "$first_item" = "await" ] && echo 0 || echo 1)" "got:[$first_item]"
  # determinism: a second run is byte-identical to the first.
  out2="$("$SH" "$SHUF" < "$FIX/bucket-good.txt" 2>&1)"
  assert "$SH shuffle: deterministic (run twice, identical)" 0 \
    "$([ "$out" = "$out2" ] && echo 0 || echo 1)" "runs differ"
  # bucket labels stay in the GIVEN order (calls/keywords before variables before operators).
  order="$(printf '%s\n' "$out" | grep '^# ' | tr '\n' '|')"
  assert "$SH shuffle: bucket labels keep given order" 0 \
    "$([ "$order" = "# calls/keywords|# variables|# operators/math|" ] && echo 0 || echo 1)" "order:[$order]"

  out="$("$SH" "$SHUF" < "$FIX/bucket-malformed.txt" 2>&1)"; rc=$?
  assert "$SH shuffle: ingredient before any header → 1 (malformed)" 1 "$rc" "$out" 'malformed'

  out="$(printf '' | "$SH" "$SHUF" 2>&1)"; rc=$?
  assert "$SH shuffle: empty input → 1 (nothing to neutralise)" 1 "$rc" "$out" 'malformed'

  # ── ledger-lint.sh ────────────────────────────────────────────────────────────────────────────
  # Enum axes, enabled axes have a level, at most one open gap, socratic gap records an answer —
  # and NEVER touches a divergent human-authored ledger (reports only).
  LL="$S/ledger-lint.sh"

  out="$("$SH" "$LL" "$FIX/ledger-good.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: a consistent ledger → 0" 0 "$rc" "$out" 'VERDICT: OK'

  out="$("$SH" "$LL" "$FIX/ledger-bad-axis.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: an unknown axis label → 1" 1 "$rc" "$out" 'unknown axis'

  out="$("$SH" "$LL" "$FIX/ledger-missing-level.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: an enabled axis with no level → 1" 1 "$rc" "$out" 'no level'

  out="$("$SH" "$LL" "$FIX/ledger-two-open.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: two open gaps → 1" 1 "$rc" "$out" 'open gaps|at most ONE'

  # THE FATAL ONE: a socratic gap stays green, so a missing expected answer means it can NEVER be
  # marked solved — it rides along invisibly. This must fail.
  out="$("$SH" "$LL" "$FIX/ledger-socratic-noanswer.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: socratic gap with no expected answer → 1" 1 "$rc" "$out" 'no recorded expected answer'

  # A divergent, human-authored ledger (other section names, another language, no Form column) is
  # NOT the template — it must be reported and skipped, never failed and never rewritten.
  out="$("$SH" "$LL" "$FIX/ledger-legacy.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: a divergent ledger is skipped, not failed → 0" 0 "$rc" "$out" 'skipped' 'VERDICT: FAILED'

  out="$("$SH" "$LL" "$TMP/no-such-ledger.md" 2>&1)"; rc=$?
  assert "$SH ledger-lint: no ledger → 2 (unreadable)" 2 "$rc" "$out" 'no readable ledger'

  # ── ledger-locate.sh ──────────────────────────────────────────────────────────────────────────
  # The opt-in gate as a LOOKUP: direct-slug path, a moved-repo content match, none, and cd-fail.
  LOC="$S/ledger-locate.sh"

  # A repo with a stable remote; a fake HOME whose learning dir carries the ledger.
  Rloc="$TMP/loc-$SH"; gitrepo "$Rloc"
  git -C "$Rloc" remote add origin https://example.test/acme/repo.git
  Hloc="$TMP/home-$SH"; mkdir -p "$Hloc/.claude/learning/acme-repo"
  printf '# ledger\n| Remote URL | https://example.test/acme/repo.git |\n' \
    > "$Hloc/.claude/learning/acme-repo/ledger.md"

  out="$(HOME="$Hloc" "$SH" "$LOC" "$Rloc" 2>/dev/null)"; rc=$?
  assert "$SH ledger-locate: direct-slug match → 0, prints the path" 0 "$rc" "$out" 'acme-repo/ledger.md'

  # Moved/renamed: drop the direct slug dir, add a DIFFERENTLY-named dir that records the remote.
  # The lookup must match on recorded identity, not on the (now-stale) slug.
  rm -rf "$Hloc/.claude/learning/acme-repo"
  mkdir -p "$Hloc/.claude/learning/renamed-old"
  printf '# ledger\n| Remote URL | https://example.test/acme/repo.git |\n' \
    > "$Hloc/.claude/learning/renamed-old/ledger.md"
  out="$(HOME="$Hloc" "$SH" "$LOC" "$Rloc" 2>/dev/null)"; rc=$?
  assert "$SH ledger-locate: moved-repo, matched by recorded identity → 0" 0 "$rc" "$out" 'renamed-old/ledger.md'

  # None: an empty home, no temp fallback → not opted in.
  Hnone="$TMP/homenone-$SH"; mkdir -p "$Hnone/.claude/learning"
  HOME="$Hnone" "$SH" "$LOC" "$Rloc" >/dev/null 2>&1; rc=$?
  assert "$SH ledger-locate: no ledger claims the repo → 1" 1 "$rc" ""

  # The in-repo temp fallback still counts as consent.
  RtmpL="$TMP/loctmp-$SH"; gitrepo "$RtmpL"
  mkdir -p "$RtmpL/temp/learning"; printf 'x\n' > "$RtmpL/temp/learning/ledger.md"
  out="$(HOME="$Hnone" "$SH" "$LOC" "$RtmpL" 2>/dev/null)"; rc=$?
  assert "$SH ledger-locate: temp/ fallback ledger → 0" 0 "$rc" "$out" 'temp/learning/ledger.md'

  HOME="$Hloc" "$SH" "$LOC" "$TMP/does-not-exist-$SH" >/dev/null 2>&1; rc=$?
  assert "$SH ledger-locate: cannot cd to repo → 2 (fail closed)" 2 "$rc" ""

  # ── open-gap-check.sh ─────────────────────────────────────────────────────────────────────────
  # At most one open gap, BOTH sides, in one call — 0/1/2, side in stdout (bitmask REJECTED).
  OGC="$S/open-gap-check.sh"

  Rog="$TMP/og-$SH"; gitrepo "$Rog"
  ledclear="$TMP/og-clear-$SH.md"; printf '## Gap log\n| a | Status |\n|---|---|\n| 1 | solved |\n' > "$ledclear"
  ledopen="$TMP/og-open-$SH.md";   printf '## Gap log\n| a | Status |\n|---|---|\n| 1 | open |\n'   > "$ledopen"

  out="$( cd "$Rog" && "$SH" "$OGC" "$ledclear" 2>&1 )"; rc=$?
  assert "$SH open-gap: both sides clear → 0 (safe to plant)" 0 "$rc" "$out" 'safe to plant'

  out="$( cd "$Rog" && "$SH" "$OGC" "$ledopen" 2>&1 )"; rc=$?
  assert "$SH open-gap: ledger row open → 1, names the ledger side" 1 "$rc" "$out" 'open gap: ledger'

  # A marker in a TRACKED, modified file (a real planted gap) — tree side must catch it.
  # Assembled at run time, never a contiguous literal: this fixture used to put the marker into a
  # TRACKED file of the suite, so every scanner that greps the tree — the installed hook, and
  # open-gap-check itself — matched the test file as if it were a real open exercise. It blocked a
  # human's commit in the field and made open-gap-check permanently unable to say "safe to plant".
  printf '// %s #7 [x]\n' 'LEARN' >> "$Rog/src/a.txt"
  out="$( cd "$Rog" && "$SH" "$OGC" "$ledclear" 2>&1 )"; rc=$?
  assert "$SH open-gap: marker in the tree → 1, names the tree side" 1 "$rc" "$out" 'open gap: tree'
  # clean the tree back up for the next assertions
  git -C "$Rog" checkout -q -- src/a.txt

  out="$( cd "$Rog" && "$SH" "$OGC" "$TMP/no-ledger-$SH.md" 2>&1 )"; rc=$?
  assert "$SH open-gap: a named ledger it cannot read → 2 (UNKNOWN)" 2 "$rc" "$out" 'could not read'

  Rnog="$TMP/og-notgit-$SH"; mkdir -p "$Rnog"
  out="$( cd "$Rnog" && "$SH" "$OGC" "$ledclear" 2>&1 )"; rc=$?
  assert "$SH open-gap: not a git repo → 2 (tree unreadable)" 2 "$rc" "$out" 'could not read'

  # ── install-hook.sh ───────────────────────────────────────────────────────────────────────────
  # Install where git ACTUALLY looks; idempotent; chain a foreign hook; REFUSE a committed dir.
  IH="$S/install-hook.sh"

  Rih="$TMP/ih-$SH"; gitrepo "$Rih"
  out="$( cd "$Rih" && "$SH" "$IH" "$TMP/x/ledger.md" 2>&1 )"; rc=$?
  assert "$SH install-hook: normal install → 0 (installed/verified)" 0 "$rc" "$out" 'installed and verified'
  assert "$SH install-hook: the hook is executable" 0 \
    "$([ -x "$Rih/.git/hooks/pre-commit" ] && echo 0 || echo 1)" "not executable"

  out="$( cd "$Rih" && "$SH" "$IH" "$TMP/x/ledger.md" 2>&1 )"; rc=$?
  assert "$SH install-hook: re-run is idempotent → 0" 0 "$rc" "$out"
  cnt="$(grep -c 'wai-learning-gap pre-commit' "$Rih/.git/hooks/pre-commit")"
  assert "$SH install-hook: no double-install (one marker)" 0 \
    "$([ "$cnt" = 1 ] && echo 0 || echo 1)" "marker count: $cnt"

  # A foreign pre-commit must be preserved and chained, never clobbered.
  Rch="$TMP/ihch-$SH"; gitrepo "$Rch"
  printf '#!/bin/sh\necho FOREIGN\n' > "$Rch/.git/hooks/pre-commit"; chmod +x "$Rch/.git/hooks/pre-commit"
  out="$( cd "$Rch" && "$SH" "$IH" "$TMP/x/ledger.md" 2>&1 )"; rc=$?
  assert "$SH install-hook: chains a foreign hook → 0" 0 "$rc" "$out" 'chained'
  assert "$SH install-hook: the foreign hook is backed up" 0 \
    "$([ -f "$Rch/.git/hooks/pre-commit.pre-wai-learning-gap" ] && echo 0 || echo 1)" "no backup"

  # THE HARD REFUSAL: core.hooksPath → a committed dir. A personal hook must not become repo state.
  Rhusky="$TMP/ihhusky-$SH"; gitrepo "$Rhusky"
  mkdir -p "$Rhusky/.husky"; printf '#!/bin/sh\necho hi\n' > "$Rhusky/.husky/pre-commit"
  git -C "$Rhusky" add -A; git -C "$Rhusky" commit -q -m husky
  git -C "$Rhusky" config core.hooksPath .husky
  out="$( cd "$Rhusky" && "$SH" "$IH" "$TMP/x/ledger.md" 2>&1 )"; rc=$?
  assert "$SH install-hook: committed hooks dir → 1 (refused)" 1 "$rc" "$out" 'COMMITTED|Refusing'

  Rihng="$TMP/ihng-$SH"; mkdir -p "$Rihng"
  out="$( cd "$Rihng" && "$SH" "$IH" 2>&1 )"; rc=$?
  assert "$SH install-hook: not a git repo → 2" 2 "$rc" "$out" 'not a git'

  # ── rank-pr-candidates.sh ─────────────────────────────────────────────────────────────────────
  # Shortlist a run's PRs; the exclusion half CALLS the stubbed classifier; ranks by diff size.
  RANK="$S/rank-pr-candidates.sh"

  GHF="$TMP/gh-$SH"; EXF="$TMP/exd-$SH"; BIN="$TMP/bin-$SH"
  mkdir -p "$GHF" "$EXF" "$BIN"
  cp "$FIX/stub-gh" "$BIN/gh"; chmod +x "$BIN/gh"
  # PR5 clean/2 files, PR8 clean/5 files, PR2 excluded, PR9 unknown.
  printf '0\n' > "$EXF/pr5.rc"; printf '0\n' > "$EXF/pr8.rc"
  printf '1\n' > "$EXF/pr2.rc"; printf '2\n' > "$EXF/pr9.rc"
  printf 'a.ts\nb.ts\n'       > "$GHF/pr5.files"
  printf 'a\nb\nc\nd\ne\n'    > "$GHF/pr8.files"
  LIST="$TMP/prs-$SH.txt"; printf '# run PRs\n5\n8\n2\n9\n' > "$LIST"

  out="$( PATH="$BIN:$PATH" GH_FIXTURE="$GHF" EXD_FIXTURE="$EXF" \
          EXCLUDED_DOMAINS_SH="$FIX/stub-excluded-domains.sh" "$SH" "$RANK" "$LIST" 2>/dev/null )"; rc=$?
  assert "$SH rank: shortlist printed → 0" 0 "$rc" "$out" 'PR #5'
  # PR5 (2 files) ranks above PR8 (5 files); the excluded/unknown PRs never appear.
  order="$(printf '%s\n' "$out" | grep -oE 'PR #[0-9]+' | tr '\n' ' ')"
  assert "$SH rank: tightest diff first, excluded/unknown dropped" 0 \
    "$([ "$order" = "PR #5 PR #8 " ] && echo 0 || echo 1)" "order:[$order]"

  # Every PR excluded → no eligible target.
  printf '1\n' > "$EXF/pr5.rc"; printf '1\n' > "$EXF/pr8.rc"
  out="$( PATH="$BIN:$PATH" GH_FIXTURE="$GHF" EXD_FIXTURE="$EXF" \
          EXCLUDED_DOMAINS_SH="$FIX/stub-excluded-domains.sh" "$SH" "$RANK" "$LIST" 2>&1 )"; rc=$?
  assert "$SH rank: all PRs excluded → 1 (no eligible PR)" 1 "$rc" "$out" 'no eligible PR'

  # The classifier itself is missing → we cannot verify safety for any PR → UNKNOWN, never a plant.
  out="$( PATH="$BIN:$PATH" GH_FIXTURE="$GHF" EXD_FIXTURE="$EXF" \
          EXCLUDED_DOMAINS_SH="$TMP/no-such-classifier.sh" "$SH" "$RANK" "$LIST" 2>&1 )"; rc=$?
  assert "$SH rank: classifier unavailable → 2 (fail closed)" 2 "$rc" "$out" 'could not be classified'

  out="$( EXCLUDED_DOMAINS_SH="$FIX/stub-excluded-domains.sh" "$SH" "$RANK" "$TMP/no-list-$SH.txt" 2>&1 )"; rc=$?
  assert "$SH rank: unreadable PR list → 2" 2 "$rc" "$out" 'cannot read'
done

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
