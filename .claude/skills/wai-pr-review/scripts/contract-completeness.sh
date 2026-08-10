#!/usr/bin/env sh
# contract-completeness.sh — is this OpenAPI spec complete ENOUGH to hand across a repo boundary?
#
# A cross-repo contract is the one artefact two teams build against without talking. Every hole in it
# becomes a round-trip: the consumer codegens, hits an `any`, and files a question the producer could
# have answered in the spec. This lint closes the AVOIDABLE round-trips — the mechanical ones a script
# can see — so the only ones left are the irreducible cross-domain ones a human must own anyway.
#
# THE SPLIT IS THE WHOLE DESIGN (ADR-0002), and it is drawn to keep this gate from crying wolf:
#
#   STRUCTURAL FLOOR — drives the exit. These are presence facts a line reader can decide without
#   judgement: every response (including 4xx/5xx) carries a body schema; a canonical error schema
#   exists and is referenced; at least one security scheme is defined and every MUTATING operation
#   requires one; an API version is stated. A missing one of these is a hole, full stop.
#
#   NAME HEURISTICS — WARN only, and NEVER move the exit. "A field called `amount` typed as a float",
#   "a field called `status` with no enum", "a mutating op with no idempotency key", "a `*_at` field
#   without format: date-time". These are GUESSES from a NAME. A name-based gate that blocked a merge
#   would fail on the first field that breaks the naming convention — so it advises, and a human reads.
#
# WHAT IT CANNOT SEE, AND SAYS SO: it is a LINE reader, not an OpenAPI parser. It reads indented YAML
# or pretty-printed JSON. It does not resolve $refs across files, evaluate JSON Schema composition, or
# read a minified one-line document (it returns UNKNOWN for that, never a false pass). And it cannot
# judge whether an enum's MEMBERS are right or whether a security binding is CORRECT — that is the
# irreducible human round-trip the checklist explicitly does not remove.
#
#   exit 0  the structural floor is met (WARN advisories may still print)
#   exit 1  a structural floor check failed — the hole is named
#   exit 2  unparseable: not an OpenAPI document this line reader can read (e.g. minified JSON)
#
# Usage: sh contract-completeness.sh [openapi.yaml]   (default: docs/contract/openapi.yaml)

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

SPEC="${1:-docs/contract/openapi.yaml}"
{ [ -f "$SPEC" ] && [ -r "$SPEC" ]; } || { echo "contract-completeness: cannot read spec '$SPEC' — UNKNOWN." >&2; exit 2; }

Q="[\"']?"   # an optional single or double quote — lets every check read YAML and pretty JSON alike

FAIL=0
note() { echo "  ✗ $1"; FAIL=1; }
pass() { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; }              # advisory — NEVER changes the exit
hint() { echo "      $1"; }

echo "contract-completeness: $SPEC"

# --- Is this a document we can read at all? -----------------------------------------------------
# The identifying keys must appear on their OWN indented lines — which is true for YAML and for
# pretty-printed JSON, and FALSE for a minified one-liner. So this doubles as the minified-JSON guard:
# a document we cannot line-read returns UNKNOWN rather than a green we did not earn.
if ! grep -qiE "^[[:space:]]*${Q}(openapi|swagger)${Q}[[:space:]]*:" "$SPEC" || ! grep -qiE "^[[:space:]]*${Q}paths${Q}[[:space:]]*:" "$SPEC"; then
  echo "contract-completeness: no line-readable 'openapi:'/'swagger:' + 'paths:' — not an OpenAPI doc this reader can parse (minified JSON? use a real parser)." >&2
  exit 2
fi

# ================================================================================================
# STRUCTURAL FLOOR
# ================================================================================================

# --- Floor 1. Every response (incl. 4xx/5xx) has a body schema ----------------------------------
# A response with only a `description:` is the classic hole: the consumer knows an error CAN happen
# and nothing about its shape. 204/304 are exempt (no body by definition). We only FAIL on a response
# we POSITIVELY parsed as under-specified; if no responses block parses, we SKIP rather than invent.
STRUCT="$(awk '
  BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); qc = "[" DQ SQ "]" }
  {
    if ($0 ~ /^[ ]*$/) next
    ind = match($0, /[^ ]/) - 1
    lc = tolower($0); gsub(qc, "", lc)              # lowercase + quote-stripped, indent preserved

    # dedent-driven closes, BEFORE any detection on this line
    if (in_resp && cur_code != "" && ind <= C)      close_code()
    if (in_resp && ind <= R)                        in_resp = 0
    if (op_open && ind <= op_i)                      close_op()

    # paths: — record its indent (the "top level" for the global-security test)
    if (lc ~ /^[ ]*paths[ ]*:/)      { paths_i = ind; print "PATHSIND " ind }

    # responses: — open a responses block
    if (lc ~ /^[ ]*responses[ ]*:/)  { close_code(); in_resp = 1; R = ind; resp_seen = 1; next }

    if (in_resp && ind > R) {
      # a status-code key: 3 digits/x, or default
      code = ""
      s = lc; sub(/^[ ]+/, "", s)
      if (s ~ /^[0-9][0-9x][0-9x][ ]*:/ )   code = substr(s, 1, 3)
      else if (s ~ /^default[ ]*:/)          code = "default"
      if (code != "") { close_code(); cur_code = code; C = ind; cur_has = 0; next }
      if (cur_code != "" && ind > C) {
        if (index(lc, "schema") || index(lc, "content") || index(lc, "$ref")) cur_has = 1
      }
    }

    # path item (a key beginning with /) — resets the current operation
    if (lc ~ /^[ ]*\/[^:]*:/) { close_op(); cur_path = lc; sub(/^[ ]+/, "", cur_path); sub(/[ ]*:.*$/, "", cur_path) }

    # method key
    if (lc ~ /^[ ]*(get|post|put|patch|delete|head|options|trace)[ ]*:/) {
      close_op()
      m = lc; sub(/^[ ]+/, "", m); sub(/[ ]*:.*$/, "", m)
      op_open = 1; op_i = ind; op_m = m; op_sec = 0; op_idem = 0
      op_mut = (m ~ /^(post|put|patch|delete)$/) ? 1 : 0
      next
    }

    # security: — inside an op it binds that op; outside an op it is a global candidate
    if (lc ~ /^[ ]*security[ ]*:/) {
      if (op_open) op_sec = 1
      else print "GSEC " ind
    }
    if (op_open) {
      if (index(lc, "security"))    op_sec  = 1
      if (index(lc, "idempotency")) op_idem = 1
    }
  }
  function close_code() {
    if (cur_code != "" && cur_code != "204" && cur_code != "304" && !cur_has) print "VIOL " cur_code
    cur_code = ""; cur_has = 0
  }
  function close_op() {
    if (op_open && op_mut) print "MUTOP " op_m " " cur_path " " op_sec " " op_idem
    op_open = 0
  }
  END { close_code(); close_op(); print "RESPSEEN " (resp_seen + 0); print "PATHSMAX " paths_i }
' "$SPEC")"

get1() { printf '%s\n' "$STRUCT" | sed -n "s/^$1 //p" | head -1; }

RESPSEEN="$(get1 RESPSEEN)"
VIOLS="$(printf '%s\n' "$STRUCT" | awk '$1=="VIOL"{print $2}' | sort -u | tr '\n' ' ')"
if [ -n "$VIOLS" ]; then
  note "response(s) with no body schema (only a description): $VIOLS — a 4xx/5xx without a shape is an avoidable round-trip"
  hint "give each error response a content schema, ideally a \$ref to the canonical error schema."
elif [ "${RESPSEEN:-0}" = "1" ]; then
  pass "every parsed response declares a body schema (204/304 exempt)"
else
  warn "no responses block parsed — Floor 1 (response schemas) could not be verified on this document"
fi

# --- Floor 2. A canonical error schema exists AND is referenced ----------------------------------
# One error envelope, referenced from the error responses — not a bespoke shape per endpoint.
ERR_DEF=0; ERR_REF=0
grep -qiE "^[[:space:]]+${Q}[a-z0-9_]*(error|problem|fault)[a-z0-9_]*${Q}[[:space:]]*:[[:space:]]*$" "$SPEC" && ERR_DEF=1
grep -qiE '#/components/(schemas|responses)/[A-Za-z0-9_]*(error|problem|fault)' "$SPEC" && ERR_REF=1
if [ "$ERR_DEF" = 1 ] && [ "$ERR_REF" = 1 ]; then
  pass "a canonical error schema is defined and referenced"
elif [ "$ERR_REF" = 1 ] && [ "$ERR_DEF" = 0 ]; then
  note "error responses \$ref an error schema, but no component schema named *Error*/*Problem* is defined — define the envelope"
elif [ "$ERR_DEF" = 1 ] && [ "$ERR_REF" = 0 ]; then
  note "an error schema is defined but never referenced by a response — wire the 4xx/5xx responses to it"
else
  note "no canonical error schema (a component schema named *Error*/*Problem*, referenced from error responses) — define one and \$ref it"
fi

# --- Floor 3. A security scheme is defined AND required by every mutating op ----------------------
SEC_DEF=0
if grep -qiE "^[[:space:]]*${Q}securityschemes${Q}[[:space:]]*:" "$SPEC" \
   && grep -qiE "^[[:space:]]*${Q}type${Q}[[:space:]]*:[[:space:]]*${Q}(http|apikey|oauth2|openidconnect|mutualtls)" "$SPEC"; then
  SEC_DEF=1
fi
PATHSMAX="$(get1 PATHSMAX)"; PATHSMAX="${PATHSMAX:-0}"
GLOBAL=0
GSECS="$(printf '%s\n' "$STRUCT" | awk '$1=="GSEC"{print $2}')"
for g in $GSECS; do
  case "$g" in ''|*[!0-9]*) continue ;; esac
  [ "$g" -le "$PATHSMAX" ] && GLOBAL=1
done
if [ "$SEC_DEF" = 0 ]; then
  note "no security scheme is defined (components.securitySchemes with a real type) — a mutating contract needs one"
else
  if [ "$GLOBAL" = 1 ]; then
    pass "a security scheme is defined and a global security requirement covers every operation"
  else
    UNCOV="$(printf '%s\n' "$STRUCT" | awk '$1=="MUTOP" && $4==0 {print $2 " " $3}')"
    if [ -n "$UNCOV" ]; then
      note "a security scheme is defined but these MUTATING op(s) require none, and there is no global security:"
      printf '%s\n' "$UNCOV" | while IFS= read -r u; do [ -n "$u" ] && echo "        - $u"; done
      hint "add a top-level security: requirement, or a per-operation security: to each mutating op."
    else
      pass "a security scheme is defined and every mutating op requires one"
    fi
  fi
fi

# --- Floor 4. An API version is stated -----------------------------------------------------------
if grep -qiE "^[[:space:]]*${Q}info${Q}[[:space:]]*:" "$SPEC" \
   && grep -qiE "^[[:space:]]*${Q}version${Q}[[:space:]]*:[[:space:]]*${Q}?[^[:space:]\"']" "$SPEC"; then
  pass "an API version is stated (info.version)"
else
  note "no API version (info.version) — a consumer cannot pin or detect a breaking bump"
fi

# ================================================================================================
# NAME HEURISTICS — WARN ONLY. These never touch $FAIL or the exit. They are guesses from a NAME.
# ================================================================================================
echo "  --- advisories (name heuristics; never gate — a human reads these) ---"

WARNS="$(awk '
  BEGIN { SQ = sprintf("%c", 39); DQ = sprintf("%c", 34); qc = "[" DQ SQ "]" }
  function money(n)  { return (n ~ /(amount|price|total|cost|fee|balance|salary|payment|subtotal|refund)/) }
  function closed(n) { return (n ~ /(status|state|kind|role|mode|tier|level|category|currency)/) }
  function stamp(n)  { return (n ~ /(_at$|_time$|timestamp|datetime|created|updated|expires|expiry)/) }
  function flush(   n) {
    if (prop == "") return
    if (money(prop)  && p_numlike)            print "MONEY " prop
    if (closed(prop) && p_string && !p_enum)  print "ENUM " prop
    if (stamp(prop)  && p_string && !p_fmt)   print "STAMP " prop
    prop = ""
  }
  {
    if ($0 ~ /^[ ]*$/) next
    ind = match($0, /[^ ]/) - 1
    lc = tolower($0); gsub(qc, "", lc)

    if (prop != "" && ind <= p_ind) flush()

    # a property key with an EMPTY value opens a property block
    key = lc; sub(/^[ ]+/, "", key)
    if (key ~ /^[a-z0-9_.-]+[ ]*:[ ]*$/) {
      flush()
      n = key; sub(/[ ]*:.*$/, "", n)
      prop = n; p_ind = ind; p_numlike = 0; p_string = 0; p_enum = 0; p_fmt = 0
      next
    }
    if (prop != "" && ind > p_ind) {
      if (lc ~ /type[ ]*:[ ]*number/ || lc ~ /type[ ]*:[ ]*float/ || lc ~ /format[ ]*:[ ]*(float|double)/) p_numlike = 1
      if (lc ~ /type[ ]*:[ ]*string/) p_string = 1
      if (index(lc, "enum")) p_enum = 1
      if (lc ~ /format[ ]*:[ ]*date-time/) p_fmt = 1
    }
  }
  END { flush() }
' "$SPEC")"

MW="$(printf '%s\n' "$WARNS" | awk '$1=="MONEY"{print $2}' | sort -u | tr '\n' ' ')"
EW="$(printf '%s\n' "$WARNS" | awk '$1=="ENUM"{print $2}'  | sort -u | tr '\n' ' ')"
SW="$(printf '%s\n' "$WARNS" | awk '$1=="STAMP"{print $2}' | sort -u | tr '\n' ' ')"
NOIDEM="$(printf '%s\n' "$STRUCT" | awk '$1=="MUTOP" && $5==0 {print $2 " " $3}')"

ADV=0
[ -n "$MW" ]     && { warn "money-named field(s) typed as a float/number: $MW — floats lose cents; use integer minor units or a decimal string"; ADV=1; }
[ -n "$EW" ]     && { warn "closed-set-named string(s) with no enum: $EW — an enum turns a free string into a checkable contract"; ADV=1; }
[ -n "$SW" ]     && { warn "timestamp-named field(s) without format: date-time: $SW — declare the format so consumers parse it the same way"; ADV=1; }
if [ -n "$NOIDEM" ]; then
  warn "mutating op(s) with no idempotency key parameter:"
  printf '%s\n' "$NOIDEM" | while IFS= read -r u; do [ -n "$u" ] && echo "        - $u"; done
  ADV=1
fi
[ "$ADV" = 0 ] && echo "  · no name-heuristic advisories"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: OK — the structural floor is met. Advisories above (if any) are a human's call, not a gate."
  exit 0
else
  echo "VERDICT: FAILED — a structural floor check failed. Close the hole before the cross-repo hand-off."
  exit 1
fi
