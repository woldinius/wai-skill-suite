#!/usr/bin/env sh
# This repo is English. Its private archive is German. Nothing but memory kept the two apart.
#
# The suite was built in German-speaking work, so every publication step is a translation step —
# and "English-only" was a rule a human applied by hand, on every commit, from recollection. That
# is the exact shape this repo argues against everywhere else, and it had already leaked: the
# learning-gap legacy-ledger fixture shipped ENTIRELY in German, and three manual review passes
# missed it because they grepped for umlauts and that text has none. Hence two patterns, not one.
#
# WHY THIS IS ITS OWN FILE. A detector written inline in `tests/run.sh` matches its own pattern
# literals and reports the test file as German. Excluding the test file would then blind the check
# to a real 600-line file. The repo has met this before with the LEARN marker and drew the same
# conclusion: isolate the literal instead of excluding paths. So the word list lives here, in a
# file whose only job is to hold it, and this file is the ONE self-exclusion — auditable in a
# glance, because there is nothing else in it.
#
# The umlaut match is byte-exact (UTF-8 pairs, built with printf) rather than literal, so the
# character class costs no exclusion at all.
#
# Exit: 0 clean · 1 German found · 2 could not check (not a clean bill of health).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" 2>/dev/null || { echo "lang-guard: cannot enter $ROOT" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "lang-guard: git is required" >&2; exit 2; }

# Evidence, not exceptions. Both files carry German because the German IS the finding:
# `tests/scripts.sh` holds the umlaut regression fixture, and the field report quotes the
# fragmented words as the defect it documents. Translating either deletes what is demonstrated.
is_exempt() {
  case "$1" in
    tests/lang-guard.sh) return 0 ;;                                       # this file: see above
    tests/scripts.sh) return 0 ;;                                          # umlaut regression fixture
    docs/field-reports/2026-08-03-prototype-issue-mining-umlaut.md) return 0 ;;  # quotes the defect
    *) return 1 ;;
  esac
}

# ä ö ü Ä Ö Ü ß as UTF-8 byte pairs — all begin 0xC3. Byte-matched under LC_ALL=C so the class
# never has to appear literally in a tracked file.
UMLAUT="$(printf '\303[\244\266\274\204\226\234\237]')"

# Conservative on purpose: no `die`, `was`, `man`, `will`, `also`, `hat` — each is English too.
# Every word here is one a normal English sentence does not contain. Measured against the whole
# repo, this list produces zero hits outside the exempt files.
WORDS='und|nicht|wird|werden|dass|kann|noch|schon|weil|wenn|sind|haben|muss|soll|sollte'
WORDS="$WORDS"'|eine|einer|einem|einen|keine|auch|aber|oder|nach|zum|zur|dem|den|des'
WORDS="$WORDS"'|ist|sich|nur|als|hier|dort|diese|dieser|mein|wir|uns'

HITS=0
for f in $(git ls-files); do
  is_exempt "$f" && continue
  [ -f "$f" ] || continue
  grep -Iq . "$f" 2>/dev/null || continue                 # binary: nothing to read
  if LC_ALL=C grep -q "$UMLAUT" "$f" 2>/dev/null; then
    printf '  %s — umlaut\n' "$f"; HITS=$((HITS+1)); continue
  fi
  w="$(grep -owE "$WORDS" "$f" 2>/dev/null | sort -u | tr '\n' ' ')"
  if [ -n "$w" ]; then
    printf '  %s — %s\n' "$f" "${w% }"; HITS=$((HITS+1))
  fi
done

if [ "$HITS" -gt 0 ]; then
  echo "lang-guard: $HITS file(s) carry German. This repo is English; the archive is where German belongs."
  exit 1
fi
echo "lang-guard: no German outside the three files that document it."
exit 0
