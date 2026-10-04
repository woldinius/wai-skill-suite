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
#   EX-GUARD  the hardcoded guardrail FLOOR (catalog, testing strategy, gate config, Claude
#             Code's configuration directory — `.claude/` at any depth, the directory itself
#             included: skills, agents, settings, hooks, commands — the plugin manifest, `.mcp.json`
#             at any depth, CI, build/lint enforcement; instruction files such as CLAUDE.md are an
#             open decision, #128). Never configurable, never human-listable — a-fortiori.
#   EX-PAY    payment / token / billing        }
#   EX-AUTH   auth / login / user management    }  the CONTRACT domain — CONTRACT_PATHS in
#   EX-API    API / contract / DTO surface      }  merge-gate.conf. A path match trips it; the
#   EX-SEC    security                          }  sub-family is read from the path SHAPE and is
#                                                   reporting only (EX-CONTRACT when indeterminate).
#   EX-MIG    a destructive DB migration (MIGRATION_PATHS touched AND a destructive statement).
#   EX-GDPR   erasure / data-deletion — ERASURE_PATHS touched OR an erasure statement in an ADDED
#             CODE line anywhere in the diff. This is the hole the old gate left open: a
#             `DELETE FROM users` / `ON DELETE CASCADE` / `deleteAccount()` in an ordinary code PR,
#             outside any migration folder, was never caught. The same statement in an added PROSE
#             line (a `.md`, a changelog, a ledger) is reported as advisory, not gating (#67).
#
# THE ORDER OF AUTHORITY (ADR-0003):
#   PATHS and DIFF STATEMENTS are authoritative. A cited catalog-ID FAMILY PREFIX (`PAY-`, `AUTH`,
#   `API-`, `SEC-`, `GDPR-`) or a PR label may only *widen* the excluded set — never suppress it,
#   and a missing/renamed label can never make a real path match go away (tested). The prefix is
#   read as a family only: `GDPR-3` and `GDPR-6` both mean "GDPR family" — the bare number is NEVER
#   resolved against a catalog and NEVER copied across a repo boundary. So a repo-local PAY-family
#   local ID (minted at >=100) still trips EX-PAY, and nothing here needs to know what number means what.
#
# WHAT THE TEXT CHANNELS READ (#67 — one reach for all three, measured in the field):
#   The citation scan DECIDES from ADDED CODE LINES only — never from a context line the author did
#   not touch, never from a removed line, never from the PR title or body. An added line of a PROSE
#   file (a citation, or an erasure statement) is reported as ADVISORY: visible in the verdict, it
#   holds the unattended drain, it does not gate. Labels still widen: a label is a declaration, a
#   description is not. The prose deny-list is exactly PROSE_EXT below; an extension nobody listed
#   counts as CODE, so the list's incompleteness fails toward the gate, not away from it. Where a
#   file begins is read so that no content line can forge it (see added_lines_of); a failed or
#   missing awk, no work directory, a coloured diff, or a hunk that is not unified-diff shaped (a
#   word diff) is UNKNOWN, never clean. Why, with numbers:
#   docs/rationale/excluded-domains.md § Three text channels, one reach
#
# WHAT COUNTS AS A TOUCHED PATH (#111, #112): every listed file, decoded from git's quoting (one that
# does not decode is UNKNOWN), plus what the diff's git headers add — both sides of a rename, and the
# path a symlink points at (one that cannot be resolved inside the repo is UNKNOWN). The blocklist
# folds case as file systems do (see fold_key) and reads each path as a directory too; the
# --autonomy allowlist matches exactly.
# Why: docs/rationale/excluded-domains.md § Four reads that failed open
#
# EXIT CODES — fail closed, because this is a gate:
#   default mode
#     0  CLEAR     — no excluded domain touched
#     1  EXCLUDED  — one or more; the tags + tripping file/statement print, plus a parseable
#                    `EXCLUDED-DOMAINS: EX-PAY EX-GDPR` line for callers
#   every classified default-mode run (0 or 1) also prints `ANCHORED-DOMAINS: EX-GDPR EX-PAY` (or
#   `ANCHORED-DOMAINS: none`): the families whose citations DECIDE here. Beside it, exit 0 may
#   carry `ADVISORY-DOMAINS: …` (reported, not gating).
#     2  UNKNOWN   — a file list or diff could not be read, or there is no config to read it
#                    against (no git work tree, no docs/architecture/ in the cwd, no override). A
#                    gate that says CLEAR when unsure is an invitation, not a gate, so unreadable ==
#                    held for the human.
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

# A path is BYTES here. A decoded non-ASCII name that is not valid UTF-8 makes tr, sort and grep
# fail with "illegal byte sequence" under a UTF-8 locale — and a path that drops out of a pipeline
# is a path nobody classified. The C locale reads every byte as itself, on every platform.
LC_ALL=C; export LC_ALL

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
# A bare `.claude` or `src/billing` in a file list is a symlink in that directory's place, read
# through by everything that loads it: the blocklist also matches every path as a directory
# (`path/`, see match_any), so `.claude/*` catches the bare name too (#112).
GUARDRAIL_PATHS="docs/architecture/quality-attributes.md docs/architecture/catalog/*
                 docs/architecture/testing-strategy.md docs/architecture/merge-gate.conf
                 docs/architecture/coordination.conf
                 .claude/* */.claude/* .claude-plugin/* .mcp.json */.mcp.json
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

# THE BLOCKLIST'S FOLD (#112, review of #134). A case-insensitive file system maps more than ASCII
# onto an ASCII name: APFS folds ſ→s, K→k, both sharp s→ss and the ligatures ﬀ ﬁ ﬂ ﬃ ﬄ ﬅ ﬆ; NTFS upper-cases
# ı→I; İ lower-cases to i; HFS+ skips the zero-width and bidi-control code points git's own HFS
# check skips. Those are mapped as UTF-8 bytes, then ASCII case. Every other non-ASCII letter folds
# to a non-ASCII one, so it cannot alias an ASCII glob; a non-ASCII letter IN a conf glob gets the
# ASCII fold only. Why: docs/rationale/excluded-domains.md § Four reads that failed open
FOLD_SED="$(printf 's/\305\277/s/g\ns/\304\261/i/g\ns/\304\260/i/g\ns/\342\204\252/k/g\ns/\303\237/ss/g\ns/\341\272\236/ss/g\ns/\357\254\200/ff/g\ns/\357\254\201/fi/g\ns/\357\254\202/fl/g\ns/\357\254\203/ffi/g\ns/\357\254\204/ffl/g\ns/\357\254[\205\206]/st/g\ns/\342\200[\214-\217]//g\ns/\342\200[\252-\256]//g\ns/\342\201[\252-\257]//g\ns/\357\273\277//g')"
fold_key() { sed "$FOLD_SED" | tr '[:upper:]' '[:lower:]'; }

# Match a newline file-list ($1) against a whitespace glob-list ($2); print the files that hit.
# $3 = ci is the BLOCKLIST's mode, and it reads a path the way a file system may: folded on both
# sides (fold_key — on macOS `.Claude/agents/x.md` lands in `.claude/agents/`), and as a directory
# too (`path/`), so a symlink at `.claude` or `src/billing`, or one resolving there, is that whole
# directory (#112). The allowlist gets neither: there each could only make more paths "safe". The
# ORIGINAL name is printed, once.
# Uses `read`, never `for x in $VAR`: the latter splits in POSIX sh but NOT in zsh, and that failure
# is silent AND fails open (every path reported clean). Feeding both through read behaves identically
# in every shell — the lesson merge-gate.sh paid for twice.
match_any() {   # $1 = files (newlines), $2 = globs (whitespace), $3 = ci or empty → matching files
  _mf="$1"; _mg="$(printf '%s\n' "$2" | tr -s ' \t\n' '\n')"; _mc="${3:-}"
  if [ "$_mc" = ci ]; then _mg="$(printf '%s\n' "$_mg" | fold_key)"; fi
  printf '%s\n' "$_mf" | while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _k="$_f"
    if [ "$_mc" = ci ]; then _k="$(printf '%s\n' "$_f" | fold_key)"; fi
    printf '%s\n' "$_mg" | while IFS= read -r _g; do
      [ -n "$_g" ] || continue
      # shellcheck disable=SC2254  # _g is a glob on purpose
      case "$_k" in $_g) printf '%s\n' "$_f"; break ;; esac
      # shellcheck disable=SC2254
      if [ "$_mc" = ci ]; then case "$_k/" in $_g) printf '%s\n' "$_f"; break ;; esac; fi
    done
  done
}

# The files in $1 that match NO glob in $2 — the "not provably safe" set for the autonomy allowlist.
# Computed as a set difference against match_any so it uses the exact same matcher (no second, subtly
# different globber to drift), without the case fold. grep -xF is a whole-line fixed-string test.
outside_globs() {   # $1 = files, $2 = globs → files matching no glob, on stdout
  _of="$1"; _og="$2"
  _matched="$(match_any "$_of" "$_og" | sort -u)"
  printf '%s\n' "$_of" | while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    printf '%s\n' "$_matched" | grep -qxF "$_f" || printf '%s\n' "$_f"
  done | sort -u
}

# Added lines of the diff (excluding the `+++ b/file` header lines), from EVERY file. The statement
# stream for the destructive-migration grep — EX-MIG is already AND-gated on a MIGRATION_PATHS hit,
# so it needs no file-kind split.
added_lines() { grep '^+' "$DIFF_FILE" 2>/dev/null | grep -v '^+++' ; }

# The same stream split by FILE KIND (#67). A prose file is one whose extension is on this deny-list;
# everything else — including a file with no extension, or one nobody thought of — is CODE. The list
# is a deny-list on purpose: its incompleteness fails toward the gate (an unlisted extension is still
# scanned and still gates), where an allow-list of code extensions would fail away from it. `.mdx`
# and `.org` are NOT on it although the field's list carried them: MDX embeds JSX and org files run
# babel blocks — a format that can execute is code here.
# WHERE A FILE BEGINS is the one question a content line must never be able to answer. An added
# line whose text begins with `++ b/x.md` renders as `+++ b/x.md`; read as a header, it relabels the
# rest of a code file as prose and turns a DELETE FROM users two lines later into an advisory. The
# fresh-context reviews of #71 found that hole twice — once inside a hunk, once through a blank
# context line that `diff.suppressBlankEmpty` writes as an empty line. Two formats, two rules:
#  · GIT FORMAT (the diff holds a `diff --git` line — every `gh pr diff` and `git diff`): the file
#    boundary IS that line, and no content line can start with it, because every content line
#    carries a one-character prefix. The `+++ b/<path>` header is read only between that line and
#    the file's first `@@`. Blank-context style and hunk counts no longer matter.
#  · BARE FORMAT (no `diff --git` line: `diff -u`, the fixtures' `--- / +++ / @@` shape): the hunk's
#    own `@@ -o,l +n,m @@` counts bound its content, an empty line inside a hunk is blank context,
#    a `+++ ` header counts only right after a `--- ` line, and ANY desync the parser can see — a
#    line that fits no rule inside a hunk, an `@@` while counts remain, a content-shaped line
#    between hunks — LATCHES every later line to code. Every desync the parser can SEE fails toward
#    code; a bare diff is trusted as far as its generator's counts (a hand-crafted one with lying
#    counts and a forged second file can still pass as prose — no real caller writes one).
#  · MIXED: a `+++ ` line outside a git header region — a `diff -u` section appended to a `git diff`,
#    or an added line that starts with `++ ` — turns that line and the rest of that file to code
#    (third review of #71). A diff carrying terminal colour codes matches no line shape at all:
#    UNKNOWN (see acquire_inputs).
# A diff captured without any header (a bare `+line` stream) is all code — the fail-closed default.
# `CMakeLists.txt` is code although `.txt` is prose: a build file that runs commands.
# NOT A UNIFIED DIFF (#78, review of #134): a word diff (`--word-diff`, `--color-words`) writes an
# added word without a `+`, so it reads as nothing added. A git-format hunk runs exactly as far as
# its `@@ -o,l +n,m @@` counts: inside it every line starts with `+ - space \` (or is empty or a lone
# CR), the counts come out exact, and one line at least is `+` or `-`. A line after the counts run
# out is no hunk's (a format-patch signature, the next commit of `git log -p`). A bare hunk keeps
# its latch rules and adds one: a line inside it that fits none. Any breach leaves the `not-unified`
# marker in $WORK: UNKNOWN.
# awk is the one tool this split adds to the deciding path, so its failure must not read as "no
# text": a non-zero exit leaves a marker in $WORK that the run turns into UNKNOWN, never CLEAR —
# and classify() refuses to run without a work directory to hold that marker.
PROSE_EXT="md markdown txt rst adoc rdoc textile"
CODE_NAMES="cmakelists.txt"
added_lines_of() {   # $1 = code | prose → the added lines of files of that kind, header lines dropped
  _gitfmt=0; grep -q '^diff --git ' "$DIFF_FILE" 2>/dev/null && _gitfmt=1
  awk -v prose="$PROSE_EXT" -v codenames="$CODE_NAMES" -v want="$1" -v gitfmt="$_gitfmt" \
      -v nu="${WORK:+$WORK/not-unified}" '
    function kind_of(line,   f, base, ext) {
      f = line; sub(/^\+\+\+ /, "", f); sub(/\r$/, "", f); sub(/\t.*/, "", f)
      sub(/^"/, "", f); sub(/"$/, "", f)
      base = f; sub(/.*\//, "", base)
      if (tolower(base) in iscode) return "code"
      if (base ~ /\./) { ext = base; sub(/.*\./, ".", ext); if (tolower(ext) in isprose) return "prose" }
      return "code" }
    function latch() { latched = 1; kind = "code" }
    function endhunk() { if (inh && (!chg || ro > 0 || rn > 0)) bad = 1; inh = 0 }
    BEGIN { n = split(prose, p, " "); for (i = 1; i <= n; i++) isprose["." p[i]] = 1
            n = split(codenames, q, " "); for (i = 1; i <= n; i++) iscode[q[i]] = 1
            kind = "code"; ro = 0; rn = 0; hdr = 0; pm = 0; latched = 0; inh = 0; chg = 0; bad = 0 }
    # GIT FORMAT — a hunk is exactly as long as its @@ counts; a line after it is in no hunk
    gitfmt && /^diff --git / { endhunk(); kind = "code"; hdr = 1; next }
    gitfmt && hdr && !/^@@ / { if ($0 ~ /^\+\+\+ /) kind = kind_of($0); next }
    gitfmt && /^@@ / {
      endhunk(); hdr = 0; ro = 1; rn = 1; split($0, h, " ")
      if (index(h[2], ",")) ro = substr(h[2], index(h[2], ",") + 1) + 0
      if (index(h[3], ",")) rn = substr(h[3], index(h[3], ",") + 1) + 0
      inh = 1; chg = 0; next }
    gitfmt && /^\+\+\+ / { kind = "code" }
    gitfmt { c = substr($0, 1, 1)
             if (inh) {
               if ($0 == "" || $0 == "\r" || c == " ") { ro--; rn-- }
               else if (c == "-") { ro--; chg = 1 }
               else if (c == "+") { rn--; chg = 1 }
               else if (c != "\\") bad = 1
               if (ro < 0 || rn < 0) bad = 1
               if (ro <= 0 && rn <= 0) endhunk() }
             if (c == "+" && kind == want) print; next }
    # BARE FORMAT
    /^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@/ {
      if (ro > 0 || rn > 0) latch()
      ro = 1; rn = 1; split($0, h, " ")
      if (index(h[2], ",")) ro = substr(h[2], index(h[2], ",") + 1) + 0
      if (index(h[3], ",")) rn = substr(h[3], index(h[3], ",") + 1) + 0
      pm = 0; next }
    (ro > 0 || rn > 0) {
      c = substr($0, 1, 1)
      if ($0 == "" || $0 == "\r") { ro--; rn--; next }
      if (c == "+")  { rn--; if (kind == want) print; next }
      if (c == "-")  { ro--; next }
      if (c == " ")  { ro--; rn--; next }
      if (c == "\\") { next }
      bad = 1; latch(); ro = 0; rn = 0 }
    /^--- / { pm = 1; next }
    /^\+\+\+ / { if (pm && !latched) kind = kind_of($0); else latch(); pm = 0; next }
    /^[-+ ]/ { latch(); pm = 0; if (substr($0, 1, 1) == "+" && want == "code") print; next }
    { pm = 0 }
    END { if (gitfmt) endhunk(); if (bad && nu != "") { printf "" > nu; close(nu) } }
  ' "$DIFF_FILE" 2>/dev/null || { [ -n "$WORK" ] && : > "$WORK/awk-failed" 2>/dev/null; true; }
}
added_code_lines()  { added_lines_of code; }
added_prose_lines() { added_lines_of prose; }

# A QUOTED NAME (review of #134). `git diff --name-only`, `gh pr diff --name-only` and every git
# header quote a path with a non-ASCII byte (core.quotePath): `"src/billing/caf\303\251.ts"`. Matched
# as printed, the leading `"` made `.claude/agents/évil.md` CLEAR. gitpath() decodes `\ooo`, `\\`
# and `\"`; any other escape, a control character, or an unbalanced quote is UNDECODABLE — the raw
# entry is still matched, and the run is UNKNOWN (the `undecodable` marker).
GITPATH_AWK='
  function gitpath(s,   r, i, c, n) {
    if (substr(s, 1, 1) != "\"") return s
    if (length(s) < 2 || substr(s, length(s), 1) != "\"") { undec = 1; return s }
    s = substr(s, 2, length(s) - 2); r = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "\"") { undec = 1; return s }
      if (c != "\\") { r = r c; continue }
      c = substr(s, ++i, 1)
      if (c == "\\" || c == "\"") { r = r c; continue }
      if (c !~ /^[0-3]$/ || substr(s, i + 1, 2) !~ /^[0-7][0-7]$/) { undec = 1; return s }
      n = c * 64 + substr(s, i + 1, 1) * 8 + substr(s, i + 2, 1); i += 2
      if (n < 32 || n == 127) { undec = 1; return s }
      r = r sprintf("%c", n) }
    return r }
  function undecmark() { if (undec && mk != "") { printf "" > mk; close(mk) } }'
gitpaths() { awk -v mk="${WORK:+$WORK/undecodable}" "$GITPATH_AWK"' { print gitpath($0) } END { undecmark() }'; }

# The paths a git diff's HEADERS touch beyond its file list. `--name-only` names a rename's
# destination only, so a move out of a guarded path read CLEAR (#111): both `rename from` and
# `rename to` are printed. A symlink (mode 120000) is the path it points at (#112): its target — the
# one added line — is resolved against the link's directory. A target that is absolute, empty,
# climbs out of the repo or IS its root cannot be classified: `U <reason>`, which the run holds.
# Header lines exist only between `diff --git` and the first `@@`, where no content line can be.
# Why: docs/rationale/excluded-domains.md § Four reads that failed open
header_facts() {   # → `P <path>` per extra path to classify, `U <reason>` per unresolvable symlink
  awk -v mk="${WORK:+$WORK/undecodable}" "$GITPATH_AWK"'
    function unq(s) { sub(/\r$/, "", s); sub(/\t.*/, "", s); return gitpath(s) }
    function flush(   d, full, n, parts, i, m, k, res, out) {
      if (!link) return
      link = 0; sub(/\r$/, "", tgt)
      if (lpath == "") return
      if (tgt == "")                 { print "U " lpath " is a symlink whose target the diff does not show"; return }
      if (substr(tgt, 1, 1) == "/")  { print "U " lpath " -> " tgt " points outside the repository"; return }
      d = lpath; if (d ~ /\//) sub(/\/[^\/]*$/, "", d); else d = ""
      full = (d == "") ? tgt : d "/" tgt
      n = split(full, parts, "/"); m = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] == ".") continue
        if (parts[i] == "..") { if (m == 0) { print "U " lpath " -> " tgt " points outside the repository"; return }
                                m--; continue }
        out[++m] = parts[i] }
      if (m == 0) { print "U " lpath " -> " tgt " points at the repository root"; return }
      res = out[1]; for (k = 2; k <= m; k++) res = res "/" out[k]
      print "P " res }
    /^diff --git / { flush(); hdr = 1; lpath = ""; tgt = ""; next }
    hdr && /^@@ / { hdr = 0; next }
    hdr && /^rename (from|to) / { s = $0; sub(/^rename (from|to) /, "", s); print "P " unq(s); next }
    hdr && /^(new file mode|new mode) 120000/ { link = 1; next }
    hdr && /^index [0-9a-f]+\.\.[0-9a-f]+ 120000/ { link = 1; next }
    hdr && /^\+\+\+ / { s = $0; sub(/^\+\+\+ /, "", s); s = unq(s)
                        if (s == "/dev/null") s = ""; else sub(/^[bciwo]\//, "", s); lpath = s; next }
    !hdr && link && /^\+/ { tgt = substr($0, 2) }
    END { flush(); undecmark() }
  ' "$DIFF_FILE" 2>/dev/null || { [ -n "$WORK" ] && : > "$WORK/awk-failed" 2>/dev/null; true; }
}

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
# Acquire inputs → FILES_FILE (newline file list), DIFF_FILE (unified diff), LABELS_FILE (pr labels)
# Sets INPUT_UNKNOWN=1 (and a reason) when an AUTHORITATIVE input cannot be read. Labels are NOT
# authoritative: if they cannot be read, widening from them is simply skipped — an absent label can
# never suppress a real match. The PR title and body are not read at all (#67): the suite REQUIRES a
# catalog ID in every review finding and PR body, so reading them made the gate trip on its own
# mandatory citation — a label is a declaration, a description is not.
# =================================================================================================
WORK=""
# shellcheck disable=SC2329  # invoked indirectly via the trap below
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK" 2>/dev/null; return 0; }
trap cleanup EXIT INT TERM
mktmp() { WORK="${WORK:-$(mktemp -d 2>/dev/null)}"; printf '%s/%s' "$WORK" "$1"; }

FILES_FILE=""
DIFF_FILE=""
LABELS_FILE=""
INPUT_UNKNOWN=0
INPUT_REASON=""

# Every PR-scoped call goes through here, so the repository is pinned in ONE place. A future call
# added straight to `gh pr` would silently fall back to the local remote — the bug this closes.
gh_pr() {
  if [ -n "$REPO_SEL" ]; then gh pr "$@" --repo "$REPO_SEL"; else gh pr "$@"; fi
}

# THE WRONG CWD (#122). No git work tree and no override leaves `./docs/architecture/` as the
# config base; from a plugin cache it does not exist, the contract paths read as none, and a billing
# path classified CLEAR. Without a docs/architecture/ here, there is nothing to classify against.
# Why: docs/rationale/excluded-domains.md § Four reads that failed open
no_config_base() {
  [ -z "${EXCLUDED_DOMAINS_MERGE_CONF:-}" ] && [ -z "$REPO_ROOT" ] && [ ! -d docs/architecture ]
}
NO_CONF_REASON="not inside a git work tree and no docs/architecture/ here — no merge-gate.conf to classify against (run it from the repo root, or set EXCLUDED_DOMAINS_MERGE_CONF)"

acquire_inputs() {
  # awk splits the diff by file kind for both text channels (#67). Without it neither channel runs,
  # and "did not run" must never read as CLEAR — the same rule gh and git get below.
  command -v awk >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="awk is not installed"; return; }
  if [ -n "$PR" ]; then
    if [ -n "$FILES_ARG$DIFF_ARG" ]; then die_usage "--pr and --files/--diff are mutually exclusive"; fi
    if no_config_base; then INPUT_UNKNOWN=1; INPUT_REASON="$NO_CONF_REASON"; return; fi
    command -v gh  >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="gh is not installed"; return; }
    command -v git >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="git is not installed"; return; }
    gh auth status >/dev/null 2>&1 || { INPUT_UNKNOWN=1; INPUT_REASON="gh is not authenticated"; return; }
    FILES_FILE="$(mktmp files)"; DIFF_FILE="$(mktmp diff)"; LABELS_FILE="$(mktmp labels)"
    if ! gh_pr diff "$PR" --name-only >"$FILES_FILE" 2>/dev/null || [ ! -s "$FILES_FILE" ]; then
      INPUT_UNKNOWN=1; INPUT_REASON="could not read the file list for PR #$PR"; return
    fi
    if ! gh_pr diff "$PR" >"$DIFF_FILE" 2>/dev/null; then
      INPUT_UNKNOWN=1; INPUT_REASON="could not read the diff for PR #$PR"; return
    fi
    # Best-effort widening text — LABELS only, never fatal. Not title, not body (#67).
    gh_pr view "$PR" --json labels --jq '.labels[].name' >"$LABELS_FILE" 2>/dev/null || true
  else
    [ -n "$FILES_ARG" ] && [ -n "$DIFF_ARG" ] || die_usage "give --pr <n>, or both --files <f> and --diff <f>"
    if no_config_base; then INPUT_UNKNOWN=1; INPUT_REASON="$NO_CONF_REASON"; return; fi
    [ -f "$FILES_ARG" ] || { INPUT_UNKNOWN=1; INPUT_REASON="file list '$FILES_ARG' is not readable"; return; }
    [ -f "$DIFF_ARG" ]  || { INPUT_UNKNOWN=1; INPUT_REASON="diff '$DIFF_ARG' is not readable"; return; }
    FILES_FILE="$FILES_ARG"; DIFF_FILE="$DIFF_ARG"; LABELS_FILE=""
  fi
  # A coloured diff (color.ui=always in the caller's git config) matches no line shape the parser
  # knows, so every added line would be read as nothing: that is "could not read", not "clean".
  # Anchored to the START of a line: every content line of a well-formed diff starts with +, -, a
  # space or \, so a line that begins with an ESC sequence is colour — while an ESC byte INSIDE
  # content (a CLI fixture, a snapshot file) is content, and must not turn a readable PR UNKNOWN
  # (fourth review of #71).
  if [ "$INPUT_UNKNOWN" -eq 0 ] && grep -q "^$(printf '\033')\[" "$DIFF_FILE" 2>/dev/null; then
    INPUT_UNKNOWN=1; INPUT_REASON="the diff carries terminal colour codes — capture it with --no-color"
  fi
}

# =================================================================================================
# Classify — populate TAGS (space list) and DETAIL (human lines). AUTHORITATIVE from paths+diff;
# labels/prefixes only widen. Reads globals FILES_FILE / DIFF_FILE / LABELS_FILE.
# =================================================================================================
TAGS=""
DETAIL=""
ADVISORY=""
UNRESOLVED=""   # symlinks header_facts could not resolve inside the repo — UNKNOWN after classify
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
# Both branches name the tag: a detail line that reads "widened by a cited PAY- family id" without
# saying EX-PAY left the reader to infer which tag it had widened (#67).
widen() {   # $1 = tag, $2 = detail
  if anchored "$1"; then add_tag "$1"; add_detail "$1  $2"
  else add_advisory "$1"; add_detail "advisory only ($1 not anchored — no declared paths for this family): $2"; fi
}
add_detail() { DETAIL="$DETAIL  x $1
"; }

classify() {
  # Materialise $WORK in THIS shell first: added_lines_of runs inside $(…) subshells, and its
  # awk-failed marker needs a directory the parent can check afterwards.
  mktmp .work >/dev/null 2>&1 || true
  # No work directory, no marker: a failing awk would then read as "no text" and the verdict as
  # CLEAR (fresh-context review of #71). A classifier that cannot record its own failure holds.
  if [ -z "$WORK" ] || [ ! -d "$WORK" ]; then
    echo "excluded-domains: UNKNOWN — no work directory (mktemp failed); the text channels cannot run" >&2
    echo "VERDICT: UNKNOWN — could not scan the diff; held for the human."
    exit 2
  fi
  # Each entry decoded once (gitpath above): the list is matched as the names it means, not as git
  # printed them.
  FILES="$(gitpaths < "$FILES_FILE" 2>/dev/null)" || : > "$WORK/awk-failed"
  # The touched set is the file list PLUS what the diff's headers name (a rename's other side, a
  # symlink's target) — only ever added to, so a header can widen the set and never shrink it.
  _hf="$(header_facts)"
  UNRESOLVED="$(printf '%s\n' "$_hf" | sed -n 's/^U //p')"
  _xtra="$(printf '%s\n' "$_hf" | sed -n 's/^P //p' | while IFS= read -r _x; do
             [ -n "$_x" ] || continue
             printf '%s\n' "$FILES" | grep -qxF -- "$_x" || printf '%s\n' "$_x"
           done | sort -u)"
  if [ -n "$_xtra" ]; then
    FILES="$(printf '%s\n%s' "$FILES" "$_xtra")"
    add_detail "classified with the file list (a rename's other side, a symlink's target): $(printf '%s' "$_xtra" | tr '\n' ' ')"
  fi

  # --- EX-GUARD — the floor ---------------------------------------------------------------------
  G="$(match_any "$FILES" "$GUARDRAIL_PATHS" ci)"
  if [ -n "$G" ]; then
    add_tag EX-GUARD
    add_detail "EX-GUARD  touches the suite's own guardrails (a human merges these, always): $(printf '%s' "$G" | tr '\n' ' ')"
  fi

  # --- EX-CONTRACT / EX-PAY/AUTH/API/SEC — CONTRACT_PATHS ---------------------------------------
  CONTRACT_PATHS="$(conf_val CONTRACT_PATHS "$MERGE_CONF")"
  if [ -n "$CONTRACT_PATHS" ]; then
    C="$(match_any "$FILES" "$CONTRACT_PATHS" ci)"
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
    M="$(match_any "$FILES" "$MIGRATION_PATHS" ci)"
    if [ -n "$M" ]; then
      D="$(added_lines | grep -icE 'drop (table|column|constraint)|rename (table|column|to)|alter column .* type|set not null' 2>/dev/null || true)"
      if [ "${D:-0}" -gt 0 ]; then
        add_tag EX-MIG
        add_detail "EX-MIG  migration with $D destructive statement(s): $(printf '%s' "$M" | tr '\n' ' ')"
      fi
    fi
  fi

  # --- EX-GDPR — ERASURE_PATHS touched OR an erasure statement in an added CODE line -------------
  # The OR is the point (EX-MIG is an AND; this is not). An ad-hoc `DELETE FROM users` in a code PR
  # outside any migration folder was the self-merge hole; the grep runs over every added code line
  # of the diff, and a matched ERASURE_PATHS file trips it even with no statement (a dedicated
  # erasure module IS the signal). The regex is a narrow, high-signal backstop; ERASURE_PATHS is the
  # primary anchor and a repo tunes the globs. Soft-deletes that read as erasure are the known
  # false-positive; err toward the human.
  # The SAME statement in an added PROSE line — a changelog describing the erasure path, a review
  # quoting the pattern, a ledger row — is documentation, not contact: it is REPORTED as advisory
  # (visible in the verdict; it still HOLDS the unattended drain) but it does not gate (#67).
  ERASURE_PATHS="$(conf_val ERASURE_PATHS "$MERGE_CONF")"
  ERASURE_RE='delete[[:space:]]+from[[:space:]]+[^;()[:space:]]*(user|account|person|customer|member|profile|subscriber|contact)|on[[:space:]]+delete[[:space:]]+cascade|drop[[:space:]]+database|truncate[[:space:]]+(table[[:space:]]+)?[^;()[:space:]]*(user|account|person|customer|member)|delete[_[:space:]]?account|erase[_[:space:]]?(user|account|personal|data)|right[_[:space:]]?to[_[:space:]]?be[_[:space:]]?forgotten|gdpr[_[:space:] -]*(delet|eras|purge|forget|remov)|hard[_[:space:]]?delet|purge[_[:space:]]?(user|account|personal|data)|forget[_[:space:]]?(me|user|account)'
  EP=""
  [ -n "$ERASURE_PATHS" ] && EP="$(match_any "$FILES" "$ERASURE_PATHS" ci)"
  EG="$(added_code_lines  | grep -icE "$ERASURE_RE" 2>/dev/null || true)"
  EGP="$(added_prose_lines | grep -icE "$ERASURE_RE" 2>/dev/null || true)"
  if [ -n "$EP" ] || [ "${EG:-0}" -gt 0 ]; then
    add_tag EX-GDPR
    _why=""
    [ -n "$EP" ] && _why="erasure module touched: $(printf '%s' "$EP" | tr '\n' ' ')"
    [ "${EG:-0}" -gt 0 ] && _why="${_why:+$_why; }$EG erasure statement(s) in added code lines"
    add_detail "EX-GDPR  $_why"
  fi
  if [ "${EGP:-0}" -gt 0 ]; then
    add_advisory EX-GDPR
    add_detail "advisory only (EX-GDPR — in prose, not code): $EGP erasure statement(s) in added lines of prose files"
  fi

  # --- Advisory widening: family prefixes + labels (may only ADD) -------------------------------
  # Scan the ADDED CODE LINES of the diff — plus, in --pr mode, the PR labels — for cited catalog-ID
  # family prefixes. Not the context lines, not the removed lines, not the title or body: a cited ID
  # says what the author MEANS, it is not a finding in itself, and the suite's own reviews and PR
  # bodies are REQUIRED to cite (#67). Read as a FAMILY only — the number is stripped and never
  # resolved. This can flip CLEAR to EXCLUDED where the family is anchored (a cited PAY-family local
  # ID trips EX-PAY with no path match); it can never subtract a domain.
  _scan="$(mktmp scan)"
  added_code_lines > "$_scan" 2>/dev/null || true
  [ -n "$LABELS_FILE" ] && [ -f "$LABELS_FILE" ] && cat "$LABELS_FILE" >> "$_scan" 2>/dev/null
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
  # A citation in an added PROSE line — a document cites in order to document — never decides, even
  # where the family is anchored: it is reported as advisory, so it stays visible in the verdict and
  # still holds the unattended drain, and that is all.
  _pscan="$(mktmp pscan)"
  added_prose_lines > "$_pscan" 2>/dev/null || true
  PPREFIXES="$(grep -oiE '(PAY|AUTH|API|SEC|GDPR)-[0-9]+' "$_pscan" 2>/dev/null \
               | sed 's/-[0-9].*//' | tr '[:lower:]' '[:upper:]' | sort -u)"
  for _pf in $PPREFIXES; do
    add_advisory "EX-$_pf"
    add_detail "advisory only (EX-$_pf cited in prose, not code): a $_pf- family id in an added line of a prose file"
  done
  # Labels widen by their WORDS. Only labels: the variable holds exactly what its name says (#67 —
  # its predecessor was named "label" and held title + body + labels, so "widened by a gdpr/erasure
  # label" fired on the word gdpr in a paragraph, under a single label named ready-to-merge).
  if [ -n "$LABELS_FILE" ] && [ -f "$LABELS_FILE" ]; then
    LABELS="$(tr '[:upper:]' '[:lower:]' < "$LABELS_FILE" 2>/dev/null)"
    case "$LABELS" in *billing*|*payment*|*token*) widen EX-PAY  "widened by a payment/billing label" ;; esac
    case "$LABELS" in *auth*|*login*|*'user management'*) widen EX-AUTH "widened by an auth/user label" ;; esac
    case "$LABELS" in *gdpr*|*erasure*|*deletion*|*'right to be forgotten'*) widen EX-GDPR "widened by a gdpr/erasure label" ;; esac
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

# A text channel that did not run is not a clean one. added_lines_of leaves this marker when awk
# exits non-zero (see there); like an unreadable diff, that is UNKNOWN — held for the human.
if [ -n "$WORK" ] && [ -f "$WORK/awk-failed" ]; then
  echo "excluded-domains: UNKNOWN — awk failed while splitting the diff by file kind; the text channels did not run" >&2
  echo "VERDICT: UNKNOWN — could not scan the diff; held for the human."
  exit 2
fi
# A hunk that breaks the unified-diff form (#78) — a word diff writes added text without a `+`, and
# read as unified it is "nothing added". Which tool wrote it is not knowable here; the form is.
if [ -n "$WORK" ] && [ -f "$WORK/not-unified" ]; then
  echo "excluded-domains: UNKNOWN — a hunk does not keep the unified-diff form (a line that is not + - space or \\, or line counts that differ from its @@ header); capture a plain diff (git diff --no-color, no --word-diff)" >&2
  echo "VERDICT: UNKNOWN — could not scan the diff; held for the human."
  exit 2
fi
# A quoted path that does not decode is a name nobody can match (review of #134).
if [ -n "$WORK" ] && [ -f "$WORK/undecodable" ]; then
  echo "excluded-domains: UNKNOWN — a quoted path in the file list or the diff headers does not decode (git's C-style quoting); it cannot be classified" >&2
  echo "VERDICT: UNKNOWN — could not read a path; held for the human."
  exit 2
fi
# A symlink is the path it points at (#112); one that cannot be resolved inside the repo is unknown.
if [ -n "$UNRESOLVED" ]; then
  printf '%s\n' "$UNRESOLVED" | sed 's/^/excluded-domains: UNKNOWN — symlink /' >&2
  echo "VERDICT: UNKNOWN — a symlink's target cannot be classified; held for the human."
  exit 2
fi

# ANCHORED-DOMAINS on EVERY classified run: which families a citation decides for is a property of
# merge-gate.conf, and removing a path there can un-anchor a family with nothing else saying so.
# (Not the shell variable ANCHORED — that is the internal set; this is the parseable output line.)
# Why: docs/rationale/excluded-domains.md § Un-anchoring was silent
ANCHORED_LINE="ANCHORED-DOMAINS: ${ANCHORED# }"
[ -n "${ANCHORED# }" ] || ANCHORED_LINE="ANCHORED-DOMAINS: none"

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
  # lets an unanchored citation, or a citation or erasure statement in prose, report without
  # deciding; the unattended drain does not get that nuance. Autonomy errs closed, always.
  if [ -n "$ADVISORY" ]; then
    printf '%s' "$DETAIL"
    echo "$ANCHORED_LINE"
    echo "VERDICT: HELD — advisory domain citation(s) or prose statement(s) ($ADVISORY) are not clear enough for an unattended merge; held for the human."
    exit 1
  fi
  if [ -n "$TAGS" ]; then
    printf '%s' "$DETAIL"
    echo "EXCLUDED-DOMAINS: $TAGS"
    echo "$ANCHORED_LINE"
    echo "VERDICT: HELD — the excluded-domain blocklist is not clear ($TAGS); held for the human."
    exit 1
  fi

  # The allowlist floor: every touched path must be provably safe — FILES as classify() built it,
  # rename sources and symlink targets included (#111): a move OUT of an unsafe path touches it.
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
    echo "$ANCHORED_LINE"
    echo "VERDICT: CLEAR — no excluded domain touched (advisory signals reported above; not gating, per #30 and #67)."
  else
    echo "$ANCHORED_LINE"
    echo "VERDICT: CLEAR — no excluded domain touched."
  fi
  exit 0
else
  printf '%s' "$DETAIL"
  echo "EXCLUDED-DOMAINS: $TAGS"
  echo "$ANCHORED_LINE"
  echo "VERDICT: EXCLUDED — a human owns this change; do not agent-merge or act on it autonomously."
  exit 1
fi
