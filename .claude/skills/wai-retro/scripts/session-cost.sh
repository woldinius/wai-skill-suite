#!/usr/bin/env sh
# session-cost.sh — what a session cost in context, as raw token counters from its transcripts.
#
# Claude Code appends one JSON line per event to <dir>/<session-id>.jsonl, and a subagent's lines to
# <dir>/<session-id>/subagents/*.jsonl; every API response leaves its usage record there. This
# script sums those records — the instrument Q5 of docs/open-questions.md did not have.
# Why: docs/rationale/session-cost.md § Q5 had no instrument
#
# WHAT COUNTS
#   · A line whose TOP-LEVEL "type" is "assistant" and whose "message" holds a "usage" object —
#     decided by walking the JSON structure, never by substring. An escaped \"usage\" (a tool result
#     quoting transcript JSON) is string content and never counts; neither does a usage-shaped key
#     inside a tool input.
#   · One response per requestId (fallback: message.id; neither → the line itself). A response
#     streamed over several lines keeps the usage of its line with the largest output_tokens. A key
#     met twice in one run counts once, for the file read first (main transcripts before subagents).
#   · Only the usage object's own keys, matched exactly, first occurrence: output_tokens is not
#     output_tokens_details, input_tokens is not cache_creation_input_tokens, and the nested
#     "iterations" array that repeats them is never read.
#   · model "<synthetic>" is a placeholder Claude Code writes itself (a failed request, an
#     interrupted turn), with zero usage — not a response: skipped, and the skip is counted.
# Why: docs/rationale/session-cost.md § A response is a requestId, not a line
#
# WHAT IT PRINTS — raw counters, per session and in total, the main thread and subagents apart:
# responses · output tokens · fresh input (input_tokens + cache_creation_input_tokens) · cache read
# (cache_read_input_tokens) · average context per response = (fresh input + cache read) / responses;
# and output tokens per model, on one line.
# NEVER PRINTED: a price or a cost share (prices are not in the transcript), message content, a
# timestamp, a time of day, a duration.
# Why: docs/rationale/session-cost.md § Counters, no clock and no price
#
# An extractor, not a skill run: it writes no run-log row — it writes nothing at all.
#
#   exit 0  the counters were printed — zeros included
#   exit 2  the transcript dir is missing, it holds no readable *.jsonl (for the --session prefix),
#           the transcripts could not be parsed, or misuse — the path that was tried is named.
#           There is deliberately no exit 1: this script renders no verdict.
#
# Usage: sh session-cost.sh [--dir <path>] [--session <id-prefix>]
#        Default dir: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>, the slug being the repo
#        toplevel with every character outside [A-Za-z0-9] replaced by '-'. In a linked worktree
#        whose own slug has no dir, the main checkout's slug is tried next.
# Why: docs/rationale/session-cost.md § The default dir

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

USAGE="usage: sh session-cost.sh [--dir <path>] [--session <id-prefix>]"
DIR=""; SESSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)       [ $# -ge 2 ] && [ -n "${2:-}" ] || { echo "session-cost: --dir needs a path ($USAGE)" >&2; exit 2; }
                 DIR="$2"; shift ;;
    --dir=)      echo "session-cost: --dir needs a path — an empty value must not silently become the default dir" >&2; exit 2 ;;
    --dir=*)     DIR="${1#--dir=}" ;;
    --session)   [ $# -ge 2 ] && [ -n "${2:-}" ] || { echo "session-cost: --session needs an id prefix ($USAGE)" >&2; exit 2; }
                 SESSION="$2"; shift ;;
    --session=)  echo "session-cost: --session needs an id prefix — an empty value must not silently become every session" >&2; exit 2 ;;
    --session=*) SESSION="${1#--session=}" ;;
    *)           echo "session-cost: unknown argument '$1' ($USAGE)" >&2; exit 2 ;;
  esac
  shift
done

# The slug, as Claude Code derives it: one '-' per character outside [A-Za-z0-9], characters
# counted the way a JavaScript string counts them — a 2- or 3-byte UTF-8 character is one, a
# 4-byte one is two. Byte classes under LC_ALL=C, so the result does not depend on the locale.
U2="$(printf '[\300-\337][\200-\277]')"
U3="$(printf '[\340-\357][\200-\277][\200-\277]')"
U4="$(printf '[\360-\367][\200-\277][\200-\277][\200-\277]')"
slug() {
  printf '%s' "$1" | LC_ALL=C sed -e "s/$U4/--/g" -e "s/$U3/-/g" -e "s/$U2/-/g" -e 's/[^A-Za-z0-9]/-/g'
}

TRIED="$DIR"; HINT=""
if [ -z "$DIR" ]; then
  HINT=" (pass --dir <path>)"
  CFG="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
  TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$TOP" ] || TOP="$(pwd -P)"
  DIR="$CFG/projects/$(slug "$TOP")"
  TRIED="$DIR"
  if [ ! -d "$DIR" ]; then
    # The first `worktree` entry is always the main checkout.
    MAIN="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
    if [ -n "$MAIN" ] && [ "$MAIN" != "$TOP" ]; then
      DIR="$CFG/projects/$(slug "$MAIN")"
      TRIED="$TRIED, then $DIR (the main checkout of this linked worktree)"
    fi
  fi
fi
if [ ! -d "$DIR" ]; then
  echo "session-cost: no transcript dir at $TRIED — nothing was counted$HINT" >&2
  exit 2
fi
cd "$DIR" 2>/dev/null || { echo "session-cost: cannot enter $DIR — nothing was counted" >&2; exit 2; }
DIR="$(pwd -P)"

# The file list. Relative ./ paths on purpose: awk would read an operand shaped `name=value` as an
# assignment, and a ./ path can never have that shape.
want() {
  case "$1" in "$SESSION"*) return 0 ;; esac
  return 1
}
UNREAD=""
set --
for f in ./*.jsonl ./*/subagents/*.jsonl; do
  [ -f "$f" ] || continue                              # an unmatched glob stays literal
  sid="${f#./}"
  case "$sid" in
    */*) sid="${sid%%/*}" ;;
    *)   sid="${sid%.jsonl}" ;;
  esac
  want "$sid" || continue
  if [ -r "$f" ]; then set -- "$@" "$f"; else UNREAD="$UNREAD ${f#./}"; fi
done
if [ $# -eq 0 ]; then
  SCOPE=""
  [ -z "$SESSION" ] || SCOPE=" for session prefix '$SESSION'"
  echo "session-cost: no readable *.jsonl in $DIR$SCOPE (read: <id>.jsonl and <id>/subagents/*.jsonl) — nothing was counted" >&2
  exit 2
fi

# One streamed pass; every line is read once. A line without the text "usage" in quotes is
# skipped before any parsing, and the walk in scan() decides the rest.
# shellcheck disable=SC2016  # an awk program: its $0 is awk's, not the shell's
PROG='
function where(f,    s) {                 # ./<sid>.jsonl → main · ./<sid>/subagents/x.jsonl → sub
  s = f; sub("^[.]/", "", s)
  if (index(s, "/") > 0) { KIND = "sub"; sub("/.*", "", s) }
  else                   { KIND = "main"; sub("[.]jsonl$", "", s) }
  SID = s
}
function delta(s,    a) {                 # the bracket depth change across text outside strings
  if (s == ":" || s == ",") return 0
  a  = gsub(/\{/, "", s); a += gsub(/\[/, "", s)
  a -= gsub(/\}/, "", s); a -= gsub(/\]/, "", s)
  return a
}
function num(s) {                         # the integer after ":" — "" when the value is none
  if (!match(s, /^[ \t]*:[ \t]*[0-9]+/)) return ""
  s = substr(s, RSTART, RLENGTH); gsub(/[^0-9]/, "", s)
  return s
}
# The walk. With every escape pair dropped, no quote is left inside a string, so splitting at
# quotes alternates: odd parts lie outside strings, even parts are string contents. A string is a
# key when the part after it begins with ":". Depth 1 is the line, 2 its "message", 3 that "usage".
function scan(line,    t, n, p, i, d, k, nx, inm, inu, seenm) {
  T_type = ""; T_req = ""; T_id = ""; T_model = ""; T_usage = 0
  T_in = ""; T_cc = ""; T_cr = ""; T_out = ""
  t = line
  gsub(/\\./, "", t)
  n = split(t, p, "\"")
  d = 0; inm = 0; inu = 0; seenm = 0
  for (i = 1; i <= n; i++) {
    if (i % 2 == 1) {
      d += delta(p[i])
      if (inu && d < 3) inu = 0
      if (inm && d < 2) inm = 0
      continue
    }
    if (i + 1 > n) break
    nx = p[i + 1]
    if (nx !~ /^[ \t]*:/) continue
    k = p[i]
    if (d == 1) {
      if (k == "type" && T_type == "" && nx ~ /^[ \t]*:[ \t]*$/ && i + 2 <= n) T_type = p[i + 2]
      else if (k == "requestId" && T_req == "" && nx ~ /^[ \t]*:[ \t]*$/ && i + 2 <= n) T_req = p[i + 2]
      else if (k == "message" && !seenm && nx ~ /^[ \t]*:[ \t]*\{/) { inm = 1; seenm = 1 }
    } else if (d == 2 && inm) {
      if (k == "id" && T_id == "" && nx ~ /^[ \t]*:[ \t]*$/ && i + 2 <= n) T_id = p[i + 2]
      else if (k == "model" && T_model == "" && nx ~ /^[ \t]*:[ \t]*$/ && i + 2 <= n) T_model = p[i + 2]
      else if (k == "usage" && !T_usage && nx ~ /^[ \t]*:[ \t]*\{/) { inu = 1; T_usage = 1 }
    } else if (d == 3 && inu) {
      if      (k == "input_tokens"                && T_in  == "") T_in  = num(nx)
      else if (k == "cache_creation_input_tokens" && T_cc  == "") T_cc  = num(nx)
      else if (k == "cache_read_input_tokens"     && T_cr  == "") T_cr  = num(nx)
      else if (k == "output_tokens"               && T_out == "") T_out = num(nx)
    }
  }
}
function row(label, r, o, f, c) {
  if (r == 0) { printf "    %s: none — 0 responses\n", label; return }
  printf "    %s: %.0f response%s · output %.0f · fresh input %.0f · cache read %.0f · avg context per response %.0f\n", \
    label, r, (r == 1 ? "" : "s"), o, f, c, (f + c) / r
}
function ntr(n) { return n == 1 ? "1 transcript" : n " transcripts" }
function models(s,    j, m, x, best, tmp, out) {   # one line, the largest output first
  for (j = 1; j <= M_n[s]; j++) x[j] = M_name[s, j]
  for (j = 1; j <= M_n[s]; j++) {
    best = j
    for (m = j + 1; m <= M_n[s]; m++)
      if (M_out[s, x[m]] > M_out[s, x[best]] || (M_out[s, x[m]] == M_out[s, x[best]] && x[m] < x[best])) best = m
    tmp = x[j]; x[j] = x[best]; x[best] = tmp
    out = out (j > 1 ? " · " : "") x[j] " " sprintf("%.0f", M_out[s, x[j]])
  }
  printf "    output per model: %s\n", (M_n[s] ? out : "none")
}
function block(s,    a, b) {
  a = s SUBSEP "main"; b = s SUBSEP "sub"
  row("main thread (" ntr(N_files[a] + 0) ")", A_r[a] + 0, A_o[a] + 0, A_f[a] + 0, A_c[a] + 0)
  row("subagents (" ntr(N_files[b] + 0) ")", A_r[b] + 0, A_o[b] + 0, A_f[b] + 0, A_c[b] + 0)
  row("main + subagents", A_r[a] + A_r[b], A_o[a] + A_o[b], A_f[a] + A_f[b], A_c[a] + A_c[b])
  models(s)
}
BEGIN {
  TOT = "\001total"                       # the totals row: a key no file name can produce
  for (i = 1; i < ARGC; i++) {            # every file, an empty one included, is a transcript
    where(ARGV[i])
    if (!(SID in S_known)) { S_known[SID] = 1; S_n++; S_ord[S_n] = SID }
    N_files[SID, KIND]++; N_files[TOT, KIND]++
  }
}
FNR == 1 { where(FILENAME) }
index($0, "\"usage\"") == 0 { next }
{
  scan($0)
  if (T_type != "assistant" || !T_usage) next
  if (T_model == "<synthetic>") { SYNTH++; next }
  k = T_req
  if (k == "") k = T_id
  if (k == "") k = FILENAME ":" FNR
  o = T_out + 0
  if (!(k in P_sid)) {
    P_sid[k] = SID; P_kind[k] = KIND; K_n++; K_list[K_n] = k
    P_out[k] = o; P_in[k] = T_in + 0; P_cc[k] = T_cc + 0; P_cr[k] = T_cr + 0; P_model[k] = T_model
  } else if (o > P_out[k]) {
    P_out[k] = o; P_in[k] = T_in + 0; P_cc[k] = T_cc + 0; P_cr[k] = T_cr + 0; P_model[k] = T_model
  }
}
END {
  for (j = 1; j <= K_n; j++) {
    k = K_list[j]; m = P_model[k]; if (m == "") m = "(no model)"
    for (w = 1; w <= 2; w++) {
      s = (w == 1) ? P_sid[k] : TOT; a = s SUBSEP P_kind[k]
      A_r[a]++; A_o[a] += P_out[k]; A_f[a] += P_in[k] + P_cc[k]; A_c[a] += P_cr[k]
      if (!((s, m) in M_out)) { M_n[s]++; M_name[s, M_n[s]] = m }
      M_out[s, m] += P_out[k]
    }
  }
  for (i = 1; i <= S_n; i++) { printf "  session %s\n", S_ord[i]; block(S_ord[i]) }
  printf "  total — %d session%s\n", S_n, (S_n == 1 ? "" : "s")
  block(TOT)
  printf "    not counted: %d synthetic line%s (model <synthetic>: a placeholder Claude Code writes itself, zero usage — not a response)\n", \
    SYNTH, (SYNTH == 1 ? "" : "s")
}'

# Captured, not piped: a parse that fails halfway must print no partial counters. awk's own error
# goes to stderr, above this line.
if ! OUT="$(LC_ALL=C awk "$PROG" "$@")"; then
  echo "session-cost: the transcripts in $DIR could not be parsed — nothing was counted" >&2
  exit 2
fi

echo "session-cost: $DIR${SESSION:+ (session prefix $SESSION)}"
[ -z "$UNREAD" ] || echo "  not read (unreadable):$UNREAD — the counters below leave these out"
printf '%s\n' "$OUT"
echo
echo "COUNTS ONLY: tokens as the transcripts record them. Prices are not in the transcript, so no"
echo "price, cost or cost share is printed — and no message content, timestamp, time of day or duration."
exit 0
