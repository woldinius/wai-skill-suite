#!/usr/bin/env sh
# backlog-scan.sh — the PROPOSAL a team run stops on, emitted by a script instead of read by eye.
#
# wai-team must never self-mandate. Invoked without a named issue set, it does not claim,
# branch, or work anything — it runs THIS, presents the overview as a proposal, and stops until the
# human confirms the set, the decision handling, the budget and the integration mode. The reason it
# is a script and not "the model reads the backlog": the frontier and the default order are a
# dependency computation, and a model re-deriving a topo order by eye on every run is exactly the
# brittle-prompt failure ADR-0002 exists to remove. Compute it once, here, and let step 2 refine a
# single source instead of inventing its own.
#
# THE ONE THING THIS SCRIPT MUST NOT DO IS RENDER A VERDICT IT CANNOT JUSTIFY.
# `has_ac_checkboxes` is a MECHANICAL FACT — the issue body contains a `- [ ]` / `- [x]` line, or it
# does not. It is NOT a judgment that the issue is "actionable": a checklist-free issue can be
# perfectly workable and a checklist-heavy one can be noise. The drop/keep call stays with the model
# (comment what's missing, label needs-info, move on — or keep it). Emitting an "actionable: no"
# verdict from a checkbox count is the same category error as a lint that fails a repo for tailoring:
# a mechanical signal wearing a semantic verdict's clothes. So it emits the fact and names it a fact.
#
# The exclusion-domain column is likewise a HINT, and says so: an issue carries no diff yet, so the
# authoritative excluded-domain classification (wai/scripts/excluded-domains.sh, obeyed by its
# exit code) can only run later, on the PR. Here we can only read the issue's own text and labels —
# a widening advisory, never a clearance.
#
#   exit 0  overview produced — INCLUDING an empty backlog (zero open issues is a valid answer,
#           not an error; the proposal is then "nothing to work")
#   exit 2  gh is missing or unauthenticated, or the listing call failed — UNKNOWN. The skill falls
#           back to proposing from the chat/issue links it was given; it does NOT guess a backlog.
#
# There is no exit 1: this script renders no negative verdict. It reports; the human decides.
#
# Usage: sh backlog-scan.sh [label]      (optional: restrict the scan to one label, e.g. ready-for-agent)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX word/glob semantics required

command -v gh >/dev/null 2>&1 || { echo "backlog-scan: gh is not installed — cannot read the backlog (UNKNOWN)." >&2; exit 2; }
gh auth status >/dev/null 2>&1 || { echo "backlog-scan: gh is not authenticated — cannot read the backlog (UNKNOWN)." >&2; exit 2; }

# Attendance (issue #11: the record measures side effects, not work — a team run that files nothing
# vanishes). This scan opens every wai-team run and maps 1:1 to that skill, so it self-logs the row.
# Resolved as a ../../wai/scripts/ sibling like the shared classifier; FAIL-OPEN — a logging failure
# must never break a scan.
RUNLOG_SH="$(dirname "$0")/../../wai/scripts/run-log.sh"
runlog() { [ -f "$RUNLOG_SH" ] && sh "$RUNLOG_SH" wai-team "backlog scan" "$1" >/dev/null 2>&1 || true; }

LABEL="${1:-}"

# One record per open issue, fields joined by the FS control byte (0x1C) so a title or body can hold
# any punctuation without breaking the split; newlines/tabs/FS inside the body are flattened to
# spaces first. Fields: number, title, assignees(csv), labels(csv), flattened-body.
JQ='.[] | [ (.number|tostring), (.title // ""), ([.assignees[].login] | join(",")), ([.labels[].name] | join(",")), ((.body // "") | gsub("\n";" ") | gsub("\t";" ") | gsub("\u001c";" ")) ] | join("\u001c")'

if [ -n "$LABEL" ]; then
  RECORDS="$(gh issue list --state open --limit 200 --label "$LABEL" --json number,title,assignees,labels,body --jq "$JQ" 2>/dev/null)"; rc=$?
else
  RECORDS="$(gh issue list --state open --limit 200 --json number,title,assignees,labels,body --jq "$JQ" 2>/dev/null)"; rc=$?
fi

# A NON-ZERO gh IS "COULD NOT READ", NOT "EMPTY BACKLOG". The two look identical downstream (both
# produce no records), and folding them would let a transient auth failure read as "nothing to work"
# — a silent, wrong all-clear. So the exit status of the call is the arbiter, checked before content.
if [ "$rc" -ne 0 ]; then
  echo "backlog-scan: gh could not list issues (exit $rc) — UNKNOWN, propose from what you were given." >&2
  exit 2
fi

if [ -n "$LABEL" ]; then
  echo "backlog-scan: open issues [label: $LABEL]"
else
  echo "backlog-scan: open issues"
fi

if [ -z "$RECORDS" ]; then
  echo "  (no open issues) — the proposal is: nothing to work here."
  echo
  echo "NOTE: an empty backlog is a valid answer, not a failure."
  runlog "0 open issues"
  exit 0
fi
NREC="$(printf '%s\n' "$RECORDS" | grep -c .)"

printf '%s\n' "$RECORDS" | awk '
  BEGIN { FS = "\034" }

  # Every #N declared as a dependency in the body. RSTART/RLENGTH of the OUTER match must be captured
  # before the inner #-match overwrites them (a bug that silently truncates the scan).
  function blockers(s,   res, bs, bl, tok) {
    res = ""
    while (match(s, /(depends on|depends-on|blocked by|blocked-by|blocked on|needs) *#[0-9]+/)) {
      bs = RSTART; bl = RLENGTH
      tok = substr(s, bs, bl)
      if (match(tok, /#[0-9]+/)) res = res " " substr(tok, RSTART, RLENGTH)
      s = substr(s, bs + bl)
    }
    return res
  }

  {
    n++
    num[n]   = $1
    title[n] = $2
    asg[n]   = $3
    lab[n]   = $4
    body[n]  = $5
    openset[$1] = 1
  }

  END {
    for (i = 1; i <= n; i++) {
      # has_ac_checkboxes — a MECHANICAL fact, not a verdict.
      hchk[i] = (body[i] ~ /[-*] \[[ xX]\]/) ? "yes" : "no"

      # exclusion-domain HINT — advisory, from issue text only; the PR diff is the authority.
      hay = tolower(title[i] " " lab[i] " " body[i])
      eh = ""
      if (hay ~ /billing|payment|invoice|subscription|checkout|refund|token econ/) eh = eh "billing,"
      if (hay ~ /authentic|authoriz|oauth|login|logout|password|jwt|permission|access control|user management/) eh = eh "auth,"
      if (hay ~ /api contract|openapi|swagger|endpoint contract|api version|api schema|graphql schema/) eh = eh "api,"
      if (hay ~ /security|vulnerab|cve|xss|csrf|ssrf|injection|secret|encryption|crypto|tls/) eh = eh "security,"
      if (hay ~ /migration|alter table|drop table|ddl|schema change/) eh = eh "migration,"
      if (hay ~ /gdpr|erasure|data deletion|delete account|right to be forgotten|hard delete|purge user|forget me/) eh = eh "gdpr,"
      if (hay ~ /contract/) eh = eh "contract,"
      sub(/,$/, "", eh)
      if (eh == "") eh = "none"
      exhint[i] = eh

      # size label — reported verbatim when present; NO estimate is invented when it is absent.
      sz = "none"
      cnt = split(lab[i], La, ",")
      for (j = 1; j <= cnt; j++) {
        s = La[j]; gsub(/^ +| +$/, "", s); ls = tolower(s)
        if (ls ~ /^size[:\/]/ || ls ~ /^(xs|s|m|l|xl|xxl)$/ || ls ~ /estimate/ || ls ~ /^points?[:\/]/) { sz = s; break }
      }
      size[i] = sz

      # claim state.
      claim[i] = (asg[i] == "") ? "unclaimed" : ("claimed:" asg[i])

      # blockers + how many are still OPEN (a blocker that is closed no longer holds the frontier).
      bl = blockers(body[i])
      blist[i] = bl
      obc[i] = 0; obopen[i] = ""
      m = split(bl, Bk, " ")
      for (j = 1; j <= m; j++) {
        b = Bk[j]; gsub(/[^0-9]/, "", b)
        if (b == "") continue
        if (b in openset) { obc[i]++; obopen[i] = obopen[i] " #" b }
      }
    }

    # Mechanical default order: fewest OPEN blockers first (0 = on the frontier), ties by issue
    # number ascending. Small n; a stable insertion sort keeps it deterministic and dependency-free.
    for (i = 1; i <= n; i++) ord[i] = i
    for (i = 2; i <= n; i++) {
      k = ord[i]; j = i - 1
      while (j >= 1 && (obc[ord[j]] > obc[k] || (obc[ord[j]] == obc[k] && (num[ord[j]] + 0) > (num[k] + 0)))) {
        ord[j + 1] = ord[j]; j--
      }
      ord[j + 1] = k
    }

    printf "  %d open issue(s). Default order below is fewest-open-blockers-first; frontier = no open blocker.\n\n", n
    for (r = 1; r <= n; r++) {
      i = ord[r]
      fr = (obc[i] == 0) ? "yes" : "no"
      printf "  #%s  order=%d  frontier=%s  %s  size=%s\n", num[i], r, fr, claim[i], size[i]
      printf "        has_ac_checkboxes=%s   exclusion_domain_hint=%s\n", hchk[i], exhint[i]
      bshow = blist[i]; gsub(/^ +/, "", bshow)
      if (bshow == "") bshow = "none"
      oshow = obopen[i]; gsub(/^ +/, "", oshow)
      if (oshow == "") oshow = "none"
      printf "        blockers=%s (open: %s)\n", bshow, oshow
      printf "        title: %s\n", title[i]
    }
  }
'

echo
echo "NOTE — read these as SIGNALS for the proposal, not decisions:"
echo "  · has_ac_checkboxes is a mechanical fact (a checklist line is present or not), never an"
echo "    'actionable' verdict — dropping or keeping a checklist-free issue is the model's call."
echo "  · exclusion_domain_hint is advisory, inferred from the issue's own text/labels. The"
echo "    authoritative excluded-domain classification runs later on the PR diff"
echo "    (wai/scripts/excluded-domains.sh), obeyed by its exit code — this hint only WIDENS."
echo "  · order/frontier are the mechanical default; step 2 refines with judgment but never reorders"
echo "    a blocker after its dependent. Present this as a PROPOSAL and stop before claiming."
runlog "$NREC open issues"
exit 0
