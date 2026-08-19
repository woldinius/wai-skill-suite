#!/usr/bin/env sh
# excluded-domains.sh — the ONE "is this change an excluded domain?" classifier.
#
# ONE answer for both callers, homed next to doctor.sh so nothing keeps a private copy of the domain
# set. merge-gate.sh §5-6 delegate here; §4 (team-approval enforcement) stays there — not this
# script's remit.
# Why: docs/rationale/excluded-domains.md § One classifier, because two copies fail open
#
# WHAT MAKES A DOMAIN "EXCLUDED": it is a change a human must own, always, even under an autonomy
# mandate — because an agent that may merge it can lower the very bar it is judged against, move
# money, open the door, break the contract other repos depend on, or delete someone's data. Seven
# tags:
#
#   EX-GUARD  the hardcoded guardrail FLOOR (catalog, testing strategy, gate config, skills, CI,
#             build/lint enforcement). Never configurable, never human-listable — a-fortiori.
#   EX-PAY    payment / token / billing        }
#   EX-AUTH   auth / login / user management    }  the CONTRACT domain — CONTRACT_PATHS in
#   EX-API    API / contract / DTO surface      }  merge-gate.conf. A path match trips it; the
#   EX-SEC    security                          }  sub-family is read from the path SHAPE and is
#                                                   reporting only (EX-CONTRACT when indeterminate).
#   EX-MIG    a destructive DB migration (MIGRATION_PATHS touched AND a destructive statement).
#   EX-GDPR   erasure / data-deletion — ERASURE_PATHS touched OR an erasure statement ANYWHERE in
#             the diff. This is the hole the old gate left open: a `DELETE FROM users` /
#             `ON DELETE CASCADE` / `deleteAccount()` in an ordinary code PR, outside any migration
#             folder, was never caught. The grep runs over the WHOLE diff for exactly that.
#
# THE ORDER OF AUTHORITY (ADR-0003):
#   PATHS and DIFF STATEMENTS are authoritative. A cited catalog-ID FAMILY PREFIX (`PAY-`, `AUTH`,
#   `API-`, `SEC-`, `GDPR-`) or a PR label may only *widen* the excluded set — never suppress it,
#   and a missing/renamed label can never make a real path match go away (tested). The prefix is
#   read as a family only: `GDPR-3` and `GDPR-6` both mean "GDPR family" — the bare number is NEVER
#   resolved against a catalog and NEVER copied across a repo boundary. So a repo-local PAY-family
#   local ID (minted at >=100) still trips EX-PAY, and nothing here needs to know what number means what.
#
# EXIT CODES — fail closed, because this is a gate:
#   default mode
#     0  CLEAR     — no excluded domain touched
#     1  EXCLUDED  — one or more; the tags + tripping file/statement print, plus a parseable
#                    `EXCLUDED-DOMAINS: EX-PAY EX-GDPR` line for callers
#     2  UNKNOWN   — a file list or diff could not be read. A gate that says CLEAR when unsure is
#                    an invitation, not a gate, so unreadable == held for the human.
#   --autonomy mode  (the ALLOWLIST eligibility gate — see below)
#     0  AUTONOMY-ELIGIBLE   1  HELD   2  UNKNOWN (held)
#   --list-domains mode      0 always.
#
# WHY --autonomy IS AN ALLOWLIST AND NOT JUST THE BLOCKLIST ABOVE:
#   The blocklist (the seven tags) is UNDER-inclusive by construction — it cannot know a novel
#   risky path idiom no rule was written for. Trusting "the blocklist is CLEAR" to authorize an
#   unattended merge fails OPEN on exactly the paths nobody thought to name. So autonomy inverts
#   the polarity: a diff is eligible ONLY if every touched path is inside the human-affirmed
#   AUTONOMY_SAFE_PATHS allowlist (from coordination.conf) AND the blocklist is CLEAR AND the
#   exclusion surface is actually configured (CONTRACT_PATHS, ERASURE_PATHS and AUTONOMY_SAFE_PATHS
#   all non-empty) AND a human affirmed it (AUTONOMY_AFFIRMED present). Anything not provably safe
#   is HELD. An empty CONTRACT_PATHS under --autonomy means "every path is contract-domain"
#   (fail-closed) — never "no path touched". The blocklist stays on as defense-in-depth; it is
#   never the authorization.
#
# WHAT THIS SCRIPT DOES NOT DECIDE: whether a finding is a Blocker/Major (the reviewer's judgment;
# the gate is a conjunction of this AND that); WHICH repo paths are contract/migration/erasure/safe
# (a human authors those globs in the confs — the script only resolves them); whether autonomy
# SHOULD be enabled (a one-time human decision). It owns mechanics, the model/human owns judgment.
#
# Usage:
#   sh excluded-domains.sh --pr <n> [--repo OWNER/NAME]   classify a PR (needs gh)
#     --repo (or $GH_REPO) says WHICH repository the PR is in. Without it gh follows the local
#     remote — a guess, and a wrong one classifies a DIFFERENT repo's PR of the same number.
#     A caller that resolved the repo itself (merge-gate.sh does) MUST pass it on.
#   sh excluded-domains.sh --files <f> --diff <f>   classify a captured file-list + diff (no gh)
#   sh excluded-domains.sh ... --autonomy           the allowlist eligibility gate
#   sh excluded-domains.sh --list-domains [--policy-only]
#
# Config (parsed, never sourced — a repo-local file a script executes is an injection vector):
#   docs/architecture/merge-gate.conf     CONTRACT_PATHS · MIGRATION_PATHS · ERASURE_PATHS
#   docs/architecture/coordination.conf   AUTONOMY_ENABLED · AUTONOMY_SAFE_PATHS · AUTONOMY_AFFIRMED
# (override the two locations for testing with EXCLUDED_DOMAINS_MERGE_CONF / _COORD_CONF.)

set -u

# This script needs POSIX pattern semantics. zsh does NOT expand a variable's contents as a glob
# inside `case` without GLOB_SUBST — so under zsh every path check would silently match nothing and
# a contract-domain change would be reported CLEAR: a gate that fails OPEN on the wrong shell. If we
# were launched under zsh, re-exec under sh. (Same guard as merge-gate.sh, for the same reason.)
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

# Default paths are REPO-relative, not cwd-relative (merge-gate.sh carries the incident that
# forced this; same rule here so the two halves of one gate read the same files). Overrides win;
# outside a git repo the cwd stays the base. --show-toplevel on purpose — see merge-gate.sh.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
MERGE_CONF="${EXCLUDED_DOMAINS_MERGE_CONF:-${REPO_ROOT:-.}/docs/architecture/merge-gate.conf}"
COORD_CONF="${EXCLUDED_DOMAINS_COORD_CONF:-${REPO_ROOT:-.}/docs/architecture/coordination.conf}"

# --- The guardrail FLOOR — hardcoded here, NOT configurable --------------------------------------
# Byte-for-byte the same floor merge-gate.sh §5 carries, and for the same reason: if it lived in the
# config an agent could merge a PR that drops billing from it, then merge billing freely — two
# harmless-looking steps. It stays in the shared script so no config can lower it, and so BOTH the
# everyday gate and the autonomy gate inherit it. (a) what DEFINES "good"; (b) what ENFORCES it — the
# second layer is the one that bites: protecting ci.yml protects `run: pnpm lint`, not what lint DOES.
GUARDRAIL_PATHS="docs/architecture/quality-attributes.md docs/architecture/catalog/*
                 docs/architecture/testing-strategy.md docs/architecture/merge-gate.conf
                 docs/architecture/coordination.conf
                 .claude/skills/*
                 .github/*
                 package.json */package.json
                 turbo.json nx.json
                 Makefile */Makefile Taskfile.yml
                 pyproject.toml */pyproject.toml tox.ini
                 build.gradle build.gradle.kts */build.gradle */build.gradle.kts pom.xml
                 Cargo.toml */Cargo.toml
                 tsconfig.json tsconfig.*.json */tsconfig.json */tsconfig.*.json
                 *eslint.config.* *.eslintrc*
                 ruff.toml .ruff.toml .golangci.yml .golangci.yaml
                 detekt.yml .swiftlint.yml"

# =================================================================================================
# Argument parsing
# =================================================================================================
PR=""
FILES_ARG=""
DIFF_ARG=""
AUTONOMY=0
LIST=0
POLICY_ONLY=0

# WHICH repository do we ask about? `--repo OWNER/NAME`, else $GH_REPO, else gh's own default (the
# local git remote). A caller that resolved the repo itself MUST pass it on: this was the gate's one
# fail-open path — a PR of the same NUMBER in another repo, reported CLEAR on a diff never seen.
# Why: docs/rationale/excluded-domains.md § Which repository do we ask about
REPO_SEL="${GH_REPO:-}"

die_usage() { echo "excluded-domains: $1" >&2; exit 2; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr)           [ "$#" -ge 2 ] || die_usage "--pr needs a PR number"; PR="$2"; shift 2 ;;
    # An EMPTY value is refused like a missing one. merge-gate.sh shipped the silent version of
    # this — `--repo` with no value fell back to the local remote, the exact failure `--repo` was
    # added to prevent — and this parser carried the same hole for `--repo ""` and `--repo=`.
    --repo)         [ "$#" -ge 2 ] && [ -n "${2:-}" ] || die_usage "--repo needs OWNER/NAME"; REPO_SEL="$2"; shift 2 ;;
    --repo=)        die_usage "--repo needs OWNER/NAME" ;;
    --repo=*)       REPO_SEL="${1#--repo=}"; shift ;;
    --files)        [ "$#" -ge 2 ] || die_usage "--files needs a file";  FILES_ARG="$2"; shift 2 ;;
    --diff)         [ "$#" -ge 2 ] || die_usage "--diff needs a file";   DIFF_ARG="$2"; shift 2 ;;
    --autonomy)     AUTONOMY=1; shift ;;
    --list-domains) LIST=1; shift ;;
    --policy-only)  POLICY_ONLY=1; shift ;;
    -h|--help)      grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)              die_usage "unknown argument '$1'" ;;
  esac
done

# =================================================================================================
# --list-domains — the single source of the policy-domain vocabulary
# =================================================================================================
# coordination-lint.sh sources its floor from `--list-domains --policy-only` so the two can never
# drift into two independently-typed copies. --policy-only therefore prints BARE tags, one per line,
# nothing else to parse. The six policy domains are everything a human can enumerate for the
# autonomy floor — that is, all seven EXCEPT EX-GUARD, which is hardcoded and never human-listable.
if [ "$LIST" -eq 1 ]; then
  if [ "$POLICY_ONLY" -eq 1 ]; then
    printf '%s\n' EX-PAY EX-AUTH EX-API EX-SEC EX-MIG EX-GDPR
  else
    echo "EX-GUARD   (the hardcoded guardrail floor — never configurable, never human-listable)"
    printf '%s\n' EX-PAY EX-AUTH EX-API EX-SEC EX-MIG EX-GDPR
  fi
  exit 0
fi

# =================================================================================================
# Shared helpers
# =================================================================================================
# Parse ONE key out of a conf. Never sources it. Empty/absent → empty string (a real statement for
# the everyday gate; a fail-closed trigger under --autonomy — handled by the caller).
conf_val() {   # $1 = key, $2 = conf file
  [ -f "$2" ] || return 0
  sed -n "s/^$1=//p" "$2" 2>/dev/null | tr -d '"' | head -1
}

# Match a newline file-list ($1) against a whitespace glob-list ($2); print the files that hit.
# Uses `read`, never `for x in $VAR`: the latter splits in POSIX sh but NOT in zsh, and that failure
# is silent AND fails open (every path reported clean). Feeding both through read behaves identically
# in every shell — the lesson merge-gate.sh paid for twice.
match_any() {   # $1 = files (newlines), $2 = globs (whitespace) → matching files on stdout
  _mf="$1"; _mg="$2"
  printf '%s\n' "$_mf" | while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    printf '%s\n' "$_mg" | tr -s ' \t\n' '\n' | while IFS= read -r _g; do
      [ -n "$_g" ] || continue
      # shellcheck disable=SC2254  # _g is a glob on purpose
      case "$_f" in $_g) printf '%s\n' "$_f" ;; esac
    done
  done
}

# The files in $1 that match NO glob in $2 — the "not provably safe" set for the autonomy allowlist.
# Computed as a set difference against match_any so it uses the exact same matcher (no second, subtly
# different globber to drift). grep -xF is a whole-line fixed-string test — no regex, no surprises.
outside_globs() {   # $1 = files, $2 = globs → files matching no glob, on stdout
  _of="$1"; _og="$2"
  _matched="$(match_any "$_of" "$_og" | sort -u)"
  printf '%s\n' "$_of" | while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    printf '%s\n' "$_matched" | grep -qxF "$_f" || printf '%s\n' "$_f"
  done | sort -u
}

# Added lines of the diff (excluding the `+++ b/file` header lines). The authoritative statement
# stream for the destructive-migration and erasure greps.
added_lines() { grep '^+' "$DIFF_FILE" 2>/dev/null | grep -v '^+++' ; }

# Sub-classify a contract-domain PATH into a reporting sub-family from its SHAPE. This never changes
# the DECISION (any CONTRACT_PATHS hit is EXCLUDED regardless); it only makes the tag legible, and
# it may only widen — a path that looks like both billing and auth earns both tags. When nothing
# matches, EX-CONTRACT says honestly "contract-domain, sub-family not determinable from the path".
contract_subtags() {   # $1 = a matched path → one or more EX-* tags on stdout
  _p="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  _any=0
  case "$_p" in *billing*|*payment*|*/pay/*|*token*|*invoice*|*subscription*|*checkout*|*wallet*|*ledger*) echo EX-PAY; _any=1 ;; esac
  case "$_p" in *auth*|*login*|*session*|*user*|*account*|*identity*|*password*|*credential*) echo EX-AUTH; _any=1 ;; esac
  case "$_p" in *api*|*contract*|*/dto*|*schema*|*proto*|*graphql*|*swagger*) echo EX-API; _any=1 ;; esac
  case "$_p" in *secur*|*/sec/*|*crypto*|*permission*|*authz*|*rbac*|*acl*|*csrf*|*cors*) echo EX-SEC; _any=1 ;; esac
  [ "$_any" -eq 1 ] || echo EX-CONTRACT
}

# =================================================================================================
# Acquire inputs → FILES_FILE (newline file list), DIFF_FILE (unified diff), META_FILE (pr text)
# Sets INPUT_UNKNOWN=1 (and a reason) when an AUTHORITATIVE input cannot be read. Labels/title/body
# are NOT authoritative: if they cannot be read, widening from them is simply skipped — an absent
# label can never suppress a real match.
# =================================================================================================
WORK=""
# shellcheck disable=SC2329  # invoked indirectly via the trap below
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK" 2>/dev/null; return 0; }
trap cleanup EXIT INT TERM
mktmp() { WORK="${WORK:-$(mktemp -d 2>/dev/null)}"; printf '%s/%s' "$WORK" "$1"; }

FILES_FILE=""
DIFF_FILE=""
META_FILE=""
INPUT_UNKNOWN=0
INPUT_REASON=""

# Every PR-scoped call goes through here, so the repository is pinned in ONE place. A future call
# added straight to `gh pr` would silently fall back to the local remote — the bug this closes.
gh_pr() {
  if [ -n "$REPO_SEL" ]; then gh pr "$@" --repo "$REPO_SEL"; else gh pr "$@"; fi
}

acquire_inputs() {
  if [ -n "$PR" ]; then
    if [ -n "$FILES_ARG$DIFF_ARG" ]; then die_usage "--pr and --files/--diff are mutually exclusive"; fi
    command -v gh  >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="gh is not installed"; return; }
    command -v git >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="git is not installed"; return; }
    gh auth status >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="gh is not authenticated"; return; }
    FILES_FILE="$(mktmp files)"; DIFF_FILE="$(mktmp diff)"; META_FILE="$(mktmp meta)"
    if ! gh_pr diff "$PR" --name-only >"$FILES_FILE" 2>/dev/null || [ ! -s "$FILES_FILE" ]; then
      INPUT_UNKNOWN=1; INPUT_REASON="could not read the file list for PR #$PR"; return
    fi
    if ! gh_pr diff "$PR" >"$DIFF_FILE" 2>/dev/null; then
      INPUT_UNKNOWN=1; INPUT_REASON="could not read the diff for PR #$PR"; return
    fi
    # Best-effort widening text — never fatal.
    { gh_pr view "$PR" --json title,body --jq '.title, .body' 2>/dev/null
      gh_pr view "$PR" --json labels --jq '.labels[].name' 2>/dev/null; } >"$META_FILE" 2>/dev/null || true
  else
    [ -n "$FILES_ARG" ] && [ -n "$DIFF_ARG" ] || die_usage "give --pr <n>, or both --files <f> and --diff <f>"
    [ -f "$FILES_ARG" ] || { INPUT_UNKNOWN=1; INPUT_REASON="file list '$FILES_ARG' is not readable"; return; }
    [ -f "$DIFF_ARG" ]  || { INPUT_UNKNOWN=1; INPUT_REASON="diff '$DIFF_ARG' is not readable"; return; }
    FILES_FILE="$FILES_ARG"; DIFF_FILE="$DIFF_ARG"; META_FILE=""
  fi
}

# =================================================================================================
# Classify — populate TAGS (space list) and DETAIL (human lines). AUTHORITATIVE from paths+diff;
# labels/prefixes only widen. Reads globals FILES_FILE / DIFF_FILE / META_FILE.
# =================================================================================================
TAGS=""
DETAIL=""
ADVISORY=""
add_tag()    { TAGS="$TAGS $1"; }
add_advisory() { ADVISORY="$ADVISORY $1"; }

# Is a family ANCHORED — does this repo declare paths that belong to it? (#30, decided 2026-08-18.)
# EX-GDPR anchors on a non-empty ERASURE_PATHS. EX-PAY/AUTH/API/SEC anchor on a CONTRACT_PATHS glob
# whose SHAPE classifies into that family; an indeterminate glob (EX-CONTRACT) anchors nothing — the
# paths stay fully protected by the path check regardless, this only scopes the CITATION channel.
# Unanchored, a citation is still REPORTED (advisory line, visible in the verdict) but no longer
# DECIDES. Anchored, nothing changes. Paths and diff statements remain authoritative everywhere;
# under --autonomy the advisory set still HOLDS the drain — autonomy errs closed, always.
# Why: docs/rationale/excluded-domains.md § The citation dial: why unanchored citations stopped gating
ANCHORED=""
compute_anchored() {
  _cp="$(conf_val CONTRACT_PATHS "$MERGE_CONF")"
  _ep="$(conf_val ERASURE_PATHS  "$MERGE_CONF")"
  [ -n "$_ep" ] && ANCHORED="$ANCHORED EX-GDPR"
  if [ -n "$_cp" ]; then
    _fams="$(printf '%s\n' "$_cp" | tr -s ' \t' '\n' | while IFS= read -r _g; do
               [ -n "$_g" ] || continue; contract_subtags "$_g"
             done | sort -u | tr '\n' ' ')"
    case "$_fams" in *EX-PAY*)  ANCHORED="$ANCHORED EX-PAY"  ;; esac
    case "$_fams" in *EX-AUTH*) ANCHORED="$ANCHORED EX-AUTH" ;; esac
    case "$_fams" in *EX-API*)  ANCHORED="$ANCHORED EX-API"  ;; esac
    case "$_fams" in *EX-SEC*)  ANCHORED="$ANCHORED EX-SEC"  ;; esac
  fi
}
anchored() { case " $ANCHORED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
# Widen into the deciding set only where anchored; elsewhere the citation stays visible as advisory.
widen() {   # $1 = tag, $2 = detail
  if anchored "$1"; then add_tag "$1"; add_detail "$2"
  else add_advisory "$1"; add_detail "advisory only ($1 not anchored — no declared paths for this family): $2"; fi
}
add_detail() { DETAIL="$DETAIL  x $1
"; }

classify() {
  FILES="$(cat "$FILES_FILE" 2>/dev/null)"

  # --- EX-GUARD — the floor ---------------------------------------------------------------------
  G="$(match_any "$FILES" "$GUARDRAIL_PATHS")"
  if [ -n "$G" ]; then
    add_tag EX-GUARD
    add_detail "EX-GUARD  touches the suite's own guardrails (a human merges these, always): $(printf '%s' "$G" | tr '\n' ' ')"
  fi

  # --- EX-CONTRACT / EX-PAY/AUTH/API/SEC — CONTRACT_PATHS ---------------------------------------
  CONTRACT_PATHS="$(conf_val CONTRACT_PATHS "$MERGE_CONF")"
  if [ -n "$CONTRACT_PATHS" ]; then
    C="$(match_any "$FILES" "$CONTRACT_PATHS")"
    if [ -n "$C" ]; then
      CSUB="$(printf '%s\n' "$C" | while IFS= read -r _cf; do
                [ -n "$_cf" ] || continue
                contract_subtags "$_cf"
              done | sort -u)"
      # CSUB holds only EX-* tokens (no spaces), so word-splitting it is safe and intended.
      # shellcheck disable=SC2086
      for _st in $CSUB; do add_tag "$_st"; done
      add_detail "contract domain (human merges): $(printf '%s' "$C" | tr '\n' ' ')"
    fi
  fi

  # --- EX-MIG — MIGRATION_PATHS touched AND a destructive statement -----------------------------
  MIGRATION_PATHS="$(conf_val MIGRATION_PATHS "$MERGE_CONF")"
  if [ -n "$MIGRATION_PATHS" ]; then
    M="$(match_any "$FILES" "$MIGRATION_PATHS")"
    if [ -n "$M" ]; then
      D="$(added_lines | grep -icE 'drop (table|column|constraint)|rename (table|column|to)|alter column .* type|set not null' 2>/dev/null || true)"
      if [ "${D:-0}" -gt 0 ]; then
        add_tag EX-MIG
        add_detail "EX-MIG  migration with $D destructive statement(s): $(printf '%s' "$M" | tr '\n' ' ')"
      fi
    fi
  fi

  # --- EX-GDPR — ERASURE_PATHS touched OR an erasure statement ANYWHERE in the diff -------------
  # The OR is the point (EX-MIG is an AND; this is not). An ad-hoc `DELETE FROM users` in a code PR
  # outside any migration folder was the self-merge hole; the grep runs over the WHOLE diff, and a
  # matched ERASURE_PATHS file trips it even with no statement (a dedicated erasure module IS the
  # signal). The regex is a narrow, high-signal backstop; ERASURE_PATHS is the primary anchor and a
  # repo tunes the globs. Soft-deletes that read as erasure are the known false-positive; err toward
  # the human.
  ERASURE_PATHS="$(conf_val ERASURE_PATHS "$MERGE_CONF")"
  EP=""
  [ -n "$ERASURE_PATHS" ] && EP="$(match_any "$FILES" "$ERASURE_PATHS")"
  EG="$(added_lines | grep -icE 'delete[[:space:]]+from[[:space:]]+[^;()[:space:]]*(user|account|person|customer|member|profile|subscriber|contact)|on[[:space:]]+delete[[:space:]]+cascade|drop[[:space:]]+database|truncate[[:space:]]+(table[[:space:]]+)?[^;()[:space:]]*(user|account|person|customer|member)|delete[_[:space:]]?account|erase[_[:space:]]?(user|account|personal|data)|right[_[:space:]]?to[_[:space:]]?be[_[:space:]]?forgotten|gdpr[_[:space:] -]*(delet|eras|purge|forget|remov)|hard[_[:space:]]?delet|purge[_[:space:]]?(user|account|personal|data)|forget[_[:space:]]?(me|user|account)' 2>/dev/null || true)"
  if [ -n "$EP" ] || [ "${EG:-0}" -gt 0 ]; then
    add_tag EX-GDPR
    _why=""
    [ -n "$EP" ] && _why="erasure module touched: $(printf '%s' "$EP" | tr '\n' ' ')"
    [ "${EG:-0}" -gt 0 ] && _why="${_why:+$_why; }$EG erasure statement(s) in the diff"
    add_detail "EX-GDPR  $_why"
  fi

  # --- Advisory widening: family prefixes + labels (may only ADD) -------------------------------
  # Scan the diff (and, in --pr mode, the PR title/body/labels) for cited catalog-ID family
  # prefixes. Read as a FAMILY only — the number is stripped and never resolved. This can flip CLEAR
  # to EXCLUDED (a cited PAY-family local ID trips EX-PAY with no path match); it can never subtract a domain.
  _scan="$(mktmp scan)"
  cat "$DIFF_FILE" 2>/dev/null > "$_scan" || true
  [ -n "$META_FILE" ] && [ -f "$META_FILE" ] && cat "$META_FILE" >> "$_scan" 2>/dev/null
  PREFIXES="$(grep -oiE '(PAY|AUTH|API|SEC|GDPR)-[0-9]+' "$_scan" 2>/dev/null \
              | sed 's/-[0-9].*//' | tr '[:lower:]' '[:upper:]' | sort -u)"
  compute_anchored
  for _pf in $PREFIXES; do
    case "$_pf" in
      PAY)  widen EX-PAY  "widened by a cited PAY- family id (family only, number not resolved)" ;;
      AUTH) widen EX-AUTH "widened by a cited AUTH- family id (family only)" ;;
      API)  widen EX-API  "widened by a cited API- family id (family only)" ;;
      SEC)  widen EX-SEC  "widened by a cited SEC- family id (family only)" ;;
      GDPR) widen EX-GDPR "widened by a cited GDPR- family id (family only)" ;;
    esac
  done
  if [ -n "$META_FILE" ] && [ -f "$META_FILE" ]; then
    LB="$(tr '[:upper:]' '[:lower:]' < "$META_FILE" 2>/dev/null)"
    case "$LB" in *billing*|*payment*|*token*) widen EX-PAY  "widened by a payment/billing label" ;; esac
    case "$LB" in *auth*|*login*|*'user management'*) widen EX-AUTH "widened by an auth/user label" ;; esac
    case "$LB" in *gdpr*|*erasure*|*deletion*|*'right to be forgotten'*) widen EX-GDPR "widened by a gdpr/erasure label" ;; esac
  fi

  # Dedupe — and an advisory tag that is ALSO a real tag collapses into the real one.
  # shellcheck disable=SC2086  # TAGS must word-split
  TAGS="$(printf '%s\n' $TAGS | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
  # grep, NOT `case … esac` — a case inside $( ) is a syntax error in bash 3.2, which is what
  # /bin/sh IS on macOS. shellcheck passes it; the shell does not. This suite has now relearned
  # that FIVE times (merge-gate.sh's comment counted four), and this line was the fifth.
  # shellcheck disable=SC2086
  ADVISORY="$(printf '%s\n' $ADVISORY | grep -v '^$' | sort -u | while IFS= read -r _a; do
                printf '%s\n' "$TAGS" | tr ' ' '\n' | grep -qxF "$_a" || printf '%s ' "$_a"
              done | sed 's/ $//')"
}

# =================================================================================================
# Run
# =================================================================================================
acquire_inputs
if [ "$INPUT_UNKNOWN" -eq 1 ]; then
  echo "excluded-domains: UNKNOWN — $INPUT_REASON" >&2
  if [ "$AUTONOMY" -eq 1 ]; then
    echo "VERDICT: UNKNOWN — could not read the change; held for the human."
  else
    echo "VERDICT: UNKNOWN — could not read the change; held for the human."
  fi
  exit 2
fi

classify

# --- Autonomy: the ALLOWLIST eligibility gate ---------------------------------------------------
if [ "$AUTONOMY" -eq 1 ]; then
  # Fail-closed setup checks first — an unconfigured or unaffirmed surface refuses autonomy outright.
  AUTONOMY_ENABLED="$(conf_val AUTONOMY_ENABLED "$COORD_CONF")"
  AUTONOMY_SAFE_PATHS="$(conf_val AUTONOMY_SAFE_PATHS "$COORD_CONF")"
  AUTONOMY_AFFIRMED="$(conf_val AUTONOMY_AFFIRMED "$COORD_CONF")"
  CONTRACT_PATHS="$(conf_val CONTRACT_PATHS "$MERGE_CONF")"
  ERASURE_PATHS="$(conf_val ERASURE_PATHS "$MERGE_CONF")"

  # The canonical eligibility list (AUTONOMY_AFFIRMED + non-empty surfaces below) is the authority.
  # AUTONOMY_ENABLED is orchestration-level (wai-team checks it before ever calling --autonomy),
  # so an ABSENT key defers to those checks — a present AUTONOMY_AFFIRMED is itself the human's
  # on-switch. But an EXPLICIT non-affirmative value is honored as a hard, fail-closed short-circuit:
  # it can only make the gate stricter, never looser.
  case "$AUTONOMY_ENABLED" in
    ""|yes|YES|true|1) : ;;
    *) echo "VERDICT: UNKNOWN — AUTONOMY_ENABLED is '$AUTONOMY_ENABLED' (not enabled) in $COORD_CONF; held."; exit 2 ;;
  esac
  # An empty CONTRACT_PATHS under --autonomy means "every path is contract-domain", never "clean".
  if [ -z "$CONTRACT_PATHS" ]; then
    echo "VERDICT: UNKNOWN — CONTRACT_PATHS is empty; under autonomy that means every path is contract-domain. Held."; exit 2
  fi
  if [ -z "$ERASURE_PATHS" ]; then
    echo "VERDICT: UNKNOWN — ERASURE_PATHS is empty; the erasure surface is unconfigured. Held."; exit 2
  fi
  if [ -z "$AUTONOMY_SAFE_PATHS" ]; then
    echo "VERDICT: UNKNOWN — AUTONOMY_SAFE_PATHS is empty; nothing is affirmed safe. Held."; exit 2
  fi
  if [ -z "$AUTONOMY_AFFIRMED" ]; then
    echo "VERDICT: UNKNOWN — AUTONOMY_AFFIRMED is absent; no human affirmed this surface. Held."; exit 2
  fi

  # Defense-in-depth: the blocklist must be CLEAR — including the ADVISORY set. The everyday gate
  # lets an unanchored citation report without deciding; the unattended drain does not get that
  # nuance. Autonomy errs closed, always.
  if [ -n "$ADVISORY" ]; then
    printf '%s' "$DETAIL"
    echo "VERDICT: HELD — advisory domain citation(s) ($ADVISORY) are not clear enough for an unattended merge; held for the human."
    exit 1
  fi
  if [ -n "$TAGS" ]; then
    printf '%s' "$DETAIL"
    echo "EXCLUDED-DOMAINS: $TAGS"
    echo "VERDICT: HELD — the excluded-domain blocklist is not clear ($TAGS); held for the human."
    exit 1
  fi

  # The allowlist floor: every touched path must be provably safe.
  FILES="$(cat "$FILES_FILE" 2>/dev/null)"
  UNSAFE="$(outside_globs "$FILES" "$AUTONOMY_SAFE_PATHS")"
  if [ -n "$UNSAFE" ]; then
    echo "  x path(s) not in the affirmed AUTONOMY_SAFE_PATHS allowlist: $(printf '%s' "$UNSAFE" | tr '\n' ' ')"
    echo "VERDICT: HELD — a touched path is not provably safe; held for the human (fail-closed)."
    exit 1
  fi

  echo "VERDICT: AUTONOMY-ELIGIBLE — blocklist clear, every touched path affirmed safe, surface configured and affirmed."
  exit 0
fi

# --- Default mode -------------------------------------------------------------------------------
if [ -z "$TAGS" ]; then
  if [ -n "$ADVISORY" ]; then
    printf '%s' "$DETAIL"
    echo "ADVISORY-DOMAINS: $ADVISORY"
    echo "VERDICT: CLEAR — no excluded domain touched (advisory citations reported above; not gating, per #30)."
  else
    echo "VERDICT: CLEAR — no excluded domain touched."
  fi
  exit 0
else
  printf '%s' "$DETAIL"
  echo "EXCLUDED-DOMAINS: $TAGS"
  echo "VERDICT: EXCLUDED — a human owns this change; do not agent-merge or act on it autonomously."
  exit 1
fi
