#!/usr/bin/env sh
# open-items.sh — the hand-back state footer, derived from artifacts instead of recalled.
#
# Issue #7, measured twice in the field: self-recall under-reports ~3× (a long session retrospected
# from memory reported 2 of 6 verified failures — and described one of the missed ones as handled),
# and "MERGED" is not "arrived" (a four-commit batch landed on a branch whose PR was already merged;
# GitHub said MERGED, the default branch never saw it, found a day later by accident). A footer the
# model writes from memory inherits exactly that bias, in the comfortable direction: an empty list
# reads as coverage. So: THE SCRIPT EMITS, THE MODEL PASTES — every ▶ Recommended next hand-back
# ends with this output, verbatim.
#
# THE ADR-0002 BOUNDARY, UP FRONT: this script reports FACTS — what is open, what is assigned, what
# never arrived. "What to do next" is judgment and stays the model's ▶ Recommended next line; a
# script that decided that would be exactly the class this repo has deleted twice.
#
# THREE RULES make the output trustworthy (each one a measured failure without it):
#   1. An empty line NAMES its derivation ("none — 0 open PRs") or prints "not checked" — an empty
#      list without a derivation is a claim, not a statement.
#   2. A class whose artifact is absent in this repo is SKIPPED, and the final summary names what
#      was derived and what was skipped — absence of a check must never read as absence of findings.
#   3. Per-line degradation: a dead `gh` kills the gh-derived lines, never the local git lines.
#
# Every list caps visibly (`+N more`); no silent truncation. Cost: ~4 batched gh calls + local git.
#
#   exit 0  the footer was emitted — including with skipped or not-checked lines (they are named)
#   exit 2  NOTHING could be derived at all (no git repository here and no usable gh), or misuse.
#           There is deliberately no exit 1: this script renders no negative verdict. It reports;
#           the model recommends; the human decides.
#
# Usage: sh open-items.sh [repo-root]        (default: .)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

ROOT="${1:-.}"
case "$ROOT" in -*) echo "open-items: unknown option '$ROOT' (usage: sh open-items.sh [repo-root])" >&2; exit 2 ;; esac
[ $# -le 1 ] || { echo "open-items: at most one argument (repo-root)" >&2; exit 2; }
cd "$ROOT" 2>/dev/null || { echo "open-items: cannot cd to '$ROOT'" >&2; exit 2; }

CAP="${OPEN_ITEMS_CAP:-10}"
case "$CAP" in ''|*[!0-9]*) CAP=10 ;; esac
FS="$(printf '\034')"          # a field separator no title can contain

GIT_OK=no
command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1 && GIT_OK=yes
GH_OK=no
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && GH_OK=yes

if [ "$GIT_OK" = no ] && [ "$GH_OK" = no ]; then
  echo "open-items: nothing could be derived — no git repository here and no usable gh." >&2
  exit 2
fi

# ── 0. WHICH remote is the base? ─────────────────────────────────────────────────────────────────
# THE GH SIDE AND THE GIT SIDE MUST ANSWER ABOUT THE SAME REPOSITORY. `gh` follows
# `gh repo set-default`; this script used to take the git side from a fixed candidate list
# (origin/HEAD, origin/main, …). With ONE remote those agree, which is why it shipped. With TWO
# they do not: a checkout whose work lives on a second remote while `origin` points elsewhere had
# EVERY merged PR reported "MERGED BUT UNREACHABLE" — 18 false alarms in one field run, in capitals.
# The PRs were not unreachable; they were in a different repo than the git side was asked about.
#
# That is not cosmetic. The sweep is a good check and it catches a real class (a stacked PR merged
# into a dead base, never arriving on the default branch). An alarm that is wrong 18 times in a
# LEGITIMATE setup is skipped by the third run — and then it is absent the day it is right. The
# false-positive rate is what keeps a finding alive; the same argument the gate's own record makes.
#
# So: ask gh which repository is in play, find the remote whose URL points there, and prefer that
# remote's refs. When it cannot be resolved, fall back to the old list and SAY SO — a base that
# might be the wrong repository must never read like a verified one.
BASE_REMOTE=""; GH_NWO=""; BASE_NOTE=""
if [ "$GH_OK" = yes ] && [ "$GIT_OK" = yes ]; then
  GH_NWO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  if [ -n "$GH_NWO" ]; then
    # Normalise every URL shape git accepts down to owner/name before comparing: scp-style
    # (git@host:owner/name.git), ssh://, https://, with or without the .git suffix.
    BASE_REMOTE="$(git remote -v 2>/dev/null | awk -v want="$GH_NWO" '
        $3 == "(fetch)" {
          u = $2
          sub(/\.git$/, "", u)
          sub(/^[a-z]+:\/\/[^\/]*\//, "", u)
          sub(/^[^@]*@[^:]*:/, "", u)
          if (u == want) { print $1; exit }
        }' || true)"
  fi
  if [ -n "$BASE_REMOTE" ]; then
    [ "$BASE_REMOTE" = origin ] || BASE_NOTE=" [base remote: $BASE_REMOTE — resolved from gh, which answers about $GH_NWO; NOT origin]"
  elif [ "$(git remote 2>/dev/null | grep -c . || echo 0)" -gt 1 ]; then
    # Only warn where the bug can actually bite. With zero or one remote the origin/* fallback
    # CANNOT pick the wrong repository, and a warning there would be the noise this fix removes.
    BASE_NOTE=" [base remote NOT resolved from gh and this checkout has several remotes — the refs below may belong to a different repository than gh reports on]"
  fi
fi

# The ordered candidate list: the gh-resolved remote first, then the historical fallback.
# $1 = "local-ok" to allow bare local main/master (branch comparison), anything else = remote refs
# only (reachability must be tested against the REMOTE state, never a stale local branch).
first_base_ref() {
  _lo="${1:-}"; _cands=""
  [ -n "$BASE_REMOTE" ] && _cands="$BASE_REMOTE/HEAD $BASE_REMOTE/main $BASE_REMOTE/master"
  _cands="$_cands origin/HEAD origin/main origin/master"
  [ "$_lo" = local-ok ] && _cands="$_cands main master"
  for _c in $_cands; do
    if git rev-parse --verify --quiet "$_c" >/dev/null 2>&1; then printf '%s\n' "$_c"; return 0; fi
  done
  return 1
}

DERIVED=0; SKIPPED=""; NOTCHECKED=""
line()  { DERIVED=$((DERIVED+1)); printf '  · %s\n' "$1"; }
nline() { NOTCHECKED="$NOTCHECKED $2"; printf '  · %s: not checked — %s\n' "$1" "$3"; }   # tool/ref unavailable
sline() { SKIPPED="$SKIPPED $2";       printf '  · %s: skipped — %s\n' "$1" "$3"; }       # artifact class absent here

# stdin: one item per line → "a · b · c (+N more)" — the cap is visible, never silent.
cap_join() {
  awk -v cap="$CAP" 'NF { n++; if (n <= cap) s = s (s ? " · " : "") $0 }
       END { if (n > cap) s = s " (+" (n - cap) " more)"; print s }'
}

echo "open-items: hand-back state, derived from artifacts ($(date -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '?'))"

# ── 1. Open PRs ──────────────────────────────────────────────────────────────────────────────────
OPEN_PRS=""; oprc=1
if [ "$GH_OK" = yes ]; then
  OPEN_PRS="$(gh pr list --state open --limit 100 --json number,title,headRefName \
    --jq '.[] | [(.number|tostring), (.headRefName // ""), ((.title // "") | gsub("\n";" "))] | join("\u001c")' 2>/dev/null)" && oprc=0 || oprc=$?
  if [ "$oprc" -ne 0 ]; then
    nline "open PRs" open-prs "gh pr list failed"
  elif [ -z "$OPEN_PRS" ]; then
    line "open PRs: none — 0 open PRs (gh pr list --state open)"
  else
    n="$(printf '%s\n' "$OPEN_PRS" | grep -c .)"
    items="$(printf '%s\n' "$OPEN_PRS" | awk -F"$FS" '{ printf "#%s %s\n", $1, $3 }' | cap_join)"
    line "open PRs ($n): $items"
  fi
else
  nline "open PRs" open-prs "gh unavailable"
fi
# The open-PR head branches, for the no-PR filter in class 3.
PR_HEADS=" "
[ "$oprc" -eq 0 ] && PR_HEADS=" $(printf '%s\n' "$OPEN_PRS" | awk -F"$FS" '{ print $2 }' | tr '\n' ' ') "

# ── 2. Issues assigned to the authenticated handle ───────────────────────────────────────────────
# Labelled with the HANDLE, never "me": the agent runs under the human's auth and cannot tell the
# two apart — printing "me" would claim an identity this process does not have.
if [ "$GH_OK" = yes ]; then
  LOGIN="$(gh api user --jq .login 2>/dev/null)" || LOGIN=""
  if [ -z "$LOGIN" ]; then
    nline "assigned issues" assigned-issues "could not resolve the gh login"
  else
    ASSIGNED="$(gh issue list --assignee "$LOGIN" --state open --limit 100 --json number,title \
      --jq '.[] | [(.number|tostring), ((.title // "") | gsub("\n";" "))] | join("\u001c")' 2>/dev/null)" && arc=0 || arc=$?
    if [ "$arc" -ne 0 ]; then
      nline "assigned issues" assigned-issues "gh issue list failed"
    elif [ -z "$ASSIGNED" ]; then
      line "issues assigned to $LOGIN: none — 0 open issues (gh issue list --assignee $LOGIN)"
    else
      n="$(printf '%s\n' "$ASSIGNED" | grep -c .)"
      items="$(printf '%s\n' "$ASSIGNED" | awk -F"$FS" '{ printf "#%s %s\n", $1, $2 }' | cap_join)"
      line "issues assigned to $LOGIN ($n): $items"
    fi
  fi
else
  nline "assigned issues" assigned-issues "gh unavailable"
fi

# ── 3. Local branches with unique commits and no PR ──────────────────────────────────────────────
BASEREF=""
if [ "$GIT_OK" = yes ]; then
  BASEREF="$(first_base_ref local-ok || true)"
fi
if [ "$GIT_OK" != yes ]; then
  nline "branches with unique commits and no PR" branches "not a git repository"
elif [ -z "$BASEREF" ]; then
  nline "branches with unique commits and no PR" branches "no base ref (origin/HEAD, main) to compare against"
else
  BASESHORT="${BASEREF#origin/}"
  BRLIST=""
  for b in $(git for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null); do
    [ "$b" = "$BASESHORT" ] && continue
    ncu="$(git cherry "$BASEREF" "$b" 2>/dev/null | grep -c '^+' || true)"
    [ "${ncu:-0}" -gt 0 ] || continue
    if [ "$oprc" -eq 0 ]; then
      case "$PR_HEADS" in *" $b "*) continue ;; esac      # this branch has an open PR — not an orphan
    fi
    BRLIST="$BRLIST$b ($ncu unique)
"
  done
  if [ -z "$BRLIST" ]; then
    line "branches with unique commits and no PR: none — 0 branches with commits not on $BASEREF (git cherry)$BASE_NOTE"
  else
    note=""
    [ "$oprc" -eq 0 ] || note=" — PR state NOT checked (gh unavailable): some of these may have PRs"
    line "branches with unique commits and no PR (git cherry vs $BASEREF): $(printf '%s' "$BRLIST" | cap_join)$note$BASE_NOTE"
  fi
fi

# ── 4. Merged but unreachable — the merged-but-not-on-main sweep, on every hand-back ─────────────
MERGED=""; mrc=1
if [ "$GH_OK" = yes ]; then
  MERGED="$(gh pr list --state merged --limit 20 --json number,mergeCommit,mergedAt \
    --jq '.[] | [(.number|tostring), (.mergeCommit.oid // ""), (.mergedAt // "")] | join("\u001c")' 2>/dev/null)" && mrc=0 || mrc=$?
  if [ "$mrc" -ne 0 ]; then
    nline "merged-but-unreachable sweep" merged-sweep "gh pr list --state merged failed"
  elif [ -z "$MERGED" ]; then
    line "merged-but-unreachable sweep: none — 0 merged PRs to sweep (gh pr list --state merged)"
  elif [ "$GIT_OK" != yes ]; then
    nline "merged-but-unreachable sweep" merged-sweep "no git repository to test reachability in"
  else
    TARGET="$(first_base_ref || true)"
    if [ -z "$TARGET" ]; then
      nline "merged-but-unreachable sweep" merged-sweep "no origin ref (origin/HEAD) to test reachability against"
    else
      nm=0; UNREACH=""; UNVER=""
      for row in $MERGED; do                       # rows are num/oid/date — no spaces by construction
        nm=$((nm+1))
        num="${row%%"$FS"*}"; rest="${row#*"$FS"}"; oid="${rest%%"$FS"*}"
        if [ -z "$oid" ] || ! git cat-file -e "$oid" 2>/dev/null; then
          UNVER="$UNVER #$num"; continue
        fi
        git merge-base --is-ancestor "$oid" "$TARGET" 2>/dev/null || UNREACH="$UNREACH #$num"
      done
      unvnote=""
      [ -z "$UNVER" ] || unvnote=" —$UNVER not verifiable (merge commit not local; fetch first)"
      if [ -n "$UNREACH" ]; then
        line "merged-but-unreachable: MERGED BUT UNREACHABLE —$UNREACH: GitHub says MERGED, but the merge commit is NOT an ancestor of $TARGET (last $nm merged PRs swept)$unvnote$BASE_NOTE"
      else
        line "merged-but-unreachable sweep: none — all merge commits of the last $nm merged PRs are ancestors of $TARGET$unvnote$BASE_NOTE"
      fi
    fi
  fi
else
  nline "merged-but-unreachable sweep" merged-sweep "gh unavailable"
fi

# ── 5. Gate-ledger rows with an empty outcome cell ───────────────────────────────────────────────
LEDGER="docs/architecture/gate-ledger.md"
if [ ! -f "$LEDGER" ]; then
  sline "gate-ledger rows without outcome" gate-ledger "no $LEDGER in this repo"
else
  nout="$(awk -F'|' '/^\| *[0-9][0-9][0-9][0-9]-/ {
            v = $4; o = $6; gsub(/^ +| +$/, "", v); gsub(/^ +| +$/, "", o)
            if (v != "MOOT" && o == "") n++ } END { print n + 0 }' "$LEDGER" 2>/dev/null)"
  case "$nout" in ''|*[!0-9]*) nout=0 ;; esac
  if [ "$nout" = 0 ]; then
    line "gate-ledger rows without outcome: none — every non-MOOT row carries an outcome tag ($LEDGER)"
  else
    line "gate-ledger rows without outcome: $nout row(s) still untagged in $LEDGER (MOOT rows excluded — blank is their documented state)"
  fi
fi

# ── 6. Merged PRs newer than the last audit ──────────────────────────────────────────────────────
AUDITS="docs/architecture/audits"
if [ ! -d "$AUDITS" ]; then
  sline "merged PRs since the last audit" audits "no $AUDITS/ in this repo"
else
  # Dates come from the FILENAMES (audits are dated files), not from mtimes — a fresh clone resets
  # every mtime to checkout time, which would read as "audited this morning".
  last="$(find "$AUDITS" -maxdepth 1 -type f 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -1)"
  if [ -z "$last" ]; then
    nline "merged PRs since the last audit" audits "$AUDITS/ holds no dated file"
  elif [ "$mrc" -ne 0 ]; then
    nline "merged PRs since the last audit" audits "the merged-PR list could not be read (gh)"
  else
    nsince="$(printf '%s\n' "$MERGED" | awk -F"$FS" -v last="$last" '
      NF { d = substr($3, 1, 10); if (d != "" && d > last) n++ } END { print n + 0 }')"
    if [ "$nsince" = 0 ]; then
      line "merged PRs since the last audit: none — 0 merged PRs newer than $last (newest date in $AUDITS/)"
    else
      line "merged PRs since the last audit: $nsince merged PR(s) newer than the last audit ($last) — of the last ${nm:-20} merged"
    fi
  fi
fi

# ── 7. Other worktrees and their dirty state ─────────────────────────────────────────────────────
if [ "$GIT_OK" != yes ]; then
  nline "other worktrees" worktrees "not a git repository"
else
  SELF="$(git rev-parse --show-toplevel 2>/dev/null)"
  OTHERS="$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | grep -vxF "$SELF" || true)"
  if [ -z "$OTHERS" ]; then
    line "other worktrees: none — this is the only worktree (git worktree list)"
  else
    items="$(printf '%s\n' "$OTHERS" | while IFS= read -r w; do
        if [ -n "$(git -C "$w" status --porcelain 2>/dev/null | head -1)" ]; then
          printf '%s (DIRTY)\n' "$w"
        else
          printf '%s (clean)\n' "$w"
        fi
      done | cap_join)"
    line "other worktrees (git worktree list): $items — work may be in flight there"
  fi
fi

# ── 8. Asked, unanswered — NOT derived, and printed as exactly that ──────────────────────────────
# No artifact exists for a question that went unanswered in chat. Printing "none" here would be the
# empty-list-reads-as-coverage bias this script exists to remove, so the gap is stated instead.
echo "  · asked, unanswered: not derived — no artifact exists"

# ── Summary — what was derived, what was skipped, what could not be checked ──────────────────────
echo
sk="${SKIPPED# }";    [ -n "$sk" ] || sk="none"
nc="${NOTCHECKED# }"; [ -n "$nc" ] || nc="none"
echo "SUMMARY: derived $DERIVED of 7 checkable classes · skipped (artifact absent): $sk · not checked (tool/ref unavailable): $nc"
echo "         'asked, unanswered' has no artifact and is never derived — carry open questions yourself."
echo "FACTS ONLY (ADR-0002): what to do next is judgment and stays the model's ▶ Recommended next line."

if [ "$DERIVED" -eq 0 ]; then
  echo "open-items: nothing could be derived at all this run." >&2
  exit 2
fi
exit 0
