#!/usr/bin/env sh
# shuffle-ingredients.sh — neutralise ORDER so a combine-tier gap does not leak the answer.
#
# At box 3 a gap is "combine the building blocks": the line is removed and the marker lists the
# INGREDIENTS the human must assemble — the calls/keywords, the variables, the operators — as an
# UNORDERED set. The pedagogy only works if the order in which they are listed carries no signal:
# if the ingredients appear in the exact sequence they are used, the exercise collapses into "type
# them out in the order shown". So the presentation order must be scrubbed.
#
# "Shuffle" here is deterministic ON PURPOSE — a stable lexical sort within each bucket, NOT random.
# Randomness would make the same gap look different on every run (and a test un-writable); a stable
# sort neutralises usage order just as well and is reproducible. The bucket LABELS keep their given
# order (they are fixed pedagogical categories, not a usage sequence); only the items inside each
# bucket are sorted.
#
# Input (stdin): buckets, each a header line beginning with '# ', followed by one ingredient per
# line. Blank lines are ignored. Example:
#     # calls/keywords
#     await
#     map
#     # variables
#     total
#     items
#     # operators/math
#     +
#     *
#
#   exit 0  transformed and written to stdout
#   exit 1  malformed input (an ingredient before any bucket header, or no ingredients at all)
#
# What this does NOT decide: the BUCKETING — deciding whether a token is a call, a variable or an
# operator is a judgment (a lexer across every language would be brittle). Only order is scripted.
#
# Usage:  sh shuffle-ingredients.sh < bucketed-ingredients

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi

TMP="$(mktemp -d)" || { echo "shuffle-ingredients: cannot create a temp dir" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT INT TERM

nb=0        # number of buckets seen
cur=""      # index of the current bucket
items=0     # total ingredients seen

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    '#'*)
      name="${line#\#}"; name="${name# }"       # strip the leading '#' and one following space
      nb=$((nb + 1)); cur="$nb"
      printf '%s\n' "$name" > "$TMP/h.$nb"
      : > "$TMP/i.$nb"
      ;;
    '')
      : ;;                                       # blank line — ignore
    *)
      if [ -z "$cur" ]; then
        echo "shuffle-ingredients: ingredient before any bucket header — malformed input." >&2
        exit 1
      fi
      printf '%s\n' "$line" >> "$TMP/i.$cur"
      items=$((items + 1))
      ;;
  esac
done

if [ "$nb" -eq 0 ] || [ "$items" -eq 0 ]; then
  echo "shuffle-ingredients: no ingredients to neutralise — malformed input." >&2
  exit 1
fi

# Emit each bucket in its given order; sort the ingredients inside it bytewise (LC_ALL=C) so the
# result is stable across locales and machines. Duplicates are kept — two calls to the same
# function are two ingredients.
b=1
while [ "$b" -le "$nb" ]; do
  printf '# %s\n' "$(cat "$TMP/h.$b")"
  LC_ALL=C sort "$TMP/i.$b"
  b=$((b + 1))
done

exit 0
