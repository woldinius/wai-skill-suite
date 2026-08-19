#!/usr/bin/env sh
# catalog-variant.sh — derive a catalog VARIANT from the one master baseline.
#
# There is ONE master (`quality-attributes.baseline.md`) and this script derives the three
# variants from it — never three hand-maintained files. The checked-in variant files exist so a
# reader can read them and `wai-init` can copy them; tests/run.sh regenerates and diffs them, so
# they cannot drift from the master without CI going red.
# Why: docs/rationale/catalog-variant.md § One master, derived variants
#
#   platform  — today's full build: backend + web + iOS + Android, AI model integrations,
#               token economy. The master, verbatim, behind a variant banner.
#   web       — backend + web frontend. No AI-model integration, no token economy, no store
#               surfaces.
#   minimum   — the core of software engineering: architecture & maintainability (MAINT),
#               security (SEC), privacy (GDPR) — plus RES-3, because correctness under
#               repetition is core, not platform flavor.
#
# WHAT IS MECHANICS HERE AND WHAT IS NOT (ADR-0002, ADR-0004). Which sections and IDs belong to
# which variant is a JUDGMENT — made once, by the author, and frozen below as data. What this
# script does at runtime is pure mechanics: select, extract, assemble. It never decides anything
# per run, which is why its output can be diffed in CI.
#
# Section numbers and IDs are NOT renumbered in a variant: a gap in the numbering means "not in
# this variant", and `SEC-8` means the same dimension in every variant. Stable IDs are the suite's
# only linking primitive; a variant that renumbered them would silently rebind every citation.
#
# Usage:  sh catalog-variant.sh <platform|web|minimum> [path-to-baseline]
# Output: the variant catalog on stdout.
# Exit:   0 variant generated · 2 could not generate (bad variant name, unreadable or
#         structurally unexpected master — fail closed, partial output is worse than none).

set -u
if [ -n "${ZSH_VERSION:-}" ]; then exec /bin/sh "$0" "$@"; fi   # POSIX pattern semantics required

VARIANT="${1:-}"
BASE="${2:-.claude/skills/wai-init/references/quality-attributes.baseline.md}"
[ -f "$BASE" ] || { echo "catalog-variant: no baseline at $BASE" >&2; exit 2; }

# ── the frozen judgment: what each variant keeps ────────────────────────────────────────────────
# SECTIONS: section numbers kept (master numbering). DROP_IDS: IDs excluded from kept sections —
# each entry is there because the dimension's SUBJECT belongs to a dropped concern, not merely
# because its prose mentions one (prose ties to absent IDs are covered by the banner note):
#   SEC-2/CLIENT-2  app attestation      — a mobile-store concept (App Attest / Play Integrity)
#   SEC-4/CLIENT-9  prompt injection / model-output rendering — need an AI model to attack
#   SEC-13          token-economy fraud  — the adversarial view of PAY-*, dropped with PAY
#   OBS-3           token-level cost     — AI inference cost observability
#   GDPR-6          in-app account deletion — an App Store requirement
#   WEB-1           Stripe token payments — the web leg of the token economy
#   RES-1/2/5/6     backend operations   — dropped from minimum only; RES-3 stays everywhere,
#                                          the same exception the master's scoping table makes.
case "$VARIANT" in
  platform) SECTIONS="1 2 3 4 5 6 7 8 9 10 11 12 13"; DROP_IDS="" ;;
  web)      SECTIONS="2 3 4 5 6 7 8 10 13"
            DROP_IDS="SEC-2 SEC-4 SEC-13 OBS-3 GDPR-6 CLIENT-2 CLIENT-9 WEB-1" ;;
  minimum)  SECTIONS="2 4 5 7"
            DROP_IDS="RES-1 RES-2 RES-5 RES-6 SEC-2 SEC-4 SEC-13 GDPR-6" ;;
  *) echo "catalog-variant: unknown variant '${VARIANT}' (platform|web|minimum)" >&2; exit 2 ;;
esac

# Config rot guard: a DROP_ID the master no longer defines means this list is stale — refuse to
# generate rather than silently "dropping" nothing. (An ID is never reassigned, but it can retire.)
for d in $DROP_IDS; do
  grep -qE "^- \*\*$d · " "$BASE" \
    || { echo "catalog-variant: DROP_ID $d not found in master — the variant config is stale" >&2; exit 2; }
  [ "$d" != "RES-3" ] \
    || { echo "catalog-variant: RES-3 may not be dropped — it is the master's one scoping exception" >&2; exit 2; }
done
grep -qE '^- \*\*RES-3 · ' "$BASE" \
  || { echo "catalog-variant: master lost RES-3 — every variant depends on it" >&2; exit 2; }

banner() {
  cat <<EOF
# Quality Catalog — ${VARIANT} variant (Seed)

> ⚙️ **This is a seed/template, NOT the live catalog — and a GENERATED file.** It is derived
> from the master \`quality-attributes.baseline.md\` by \`catalog-variant.sh\`; edit the master
> and regenerate, never this file (tests/run.sh re-derives it and fails on drift). \`wai-init\`
> copies the variant that fits the repo to \`docs/architecture/quality-attributes.md\` and adapts
> it there. The other skills read exclusively the live file under \`docs/architecture/\`.
>
> **Section numbers and IDs match the platform master.** A gap in the numbering means "not in
> this variant", never "missing" — and an ID cited here means the same dimension in every
> variant. Prose may still reference an ID that only the platform master carries; such a
> reference points at the master, not at a hole in this file.
>
EOF
}

case "$VARIANT" in
  platform)
    banner
    echo "> Variant scope: the full multi-surface platform — backend + web + iOS + Android, AI"
    echo "> model integrations and the token economy. This variant IS the master, verbatim."
    echo
    # Content-anchored, not line-anchored: everything from the master's first body paragraph to
    # EOF. If the anchor sentence is ever reworded, fail closed rather than emit a bannerless tail.
    grep -q '^The binding quality bar' "$BASE" \
      || { echo "catalog-variant: master body anchor not found" >&2; exit 2; }
    awk '/^The binding quality bar/{f=1} f' "$BASE"
    exit 0 ;;
  web)
    banner
    echo "> Variant scope: a backend + web-frontend product. No AI-model integration, no token"
    echo "> economy, no mobile store surfaces — the sections and dimensions that exist only for"
    echo "> those live in the platform variant."
    ;;
  minimum)
    banner
    echo "> Variant scope: the core of software engineering — clean architecture and"
    echo "> maintainability (\`MAINT-*\`), security (\`SEC-*\`), privacy (\`GDPR-*\`), and"
    echo "> correctness under repetition (\`RES-3\`). Everything surface- or platform-specific"
    echo "> lives in the web and platform variants."
    ;;
esac
echo

# ── extracted from the master, mechanically ─────────────────────────────────────────────────────
# The status/config blockquote (Repo mode, Tier, Docs language + the SSoT note): wai-init sets
# these lines in the copied file, so every variant must carry them. Contiguous `>` block only.
awk '/^> \*\*Status:\*\*/{f=1} f{ if ($0 ~ /^>/) print; else exit }' "$BASE"
echo

echo "Table of contents (master numbering — gaps are sections not in this variant):"
for n in $SECTIONS; do
  grep -E "^$n\. " "$BASE" | head -1
done
echo
echo "Each item names: what it means, how you recognize it *well*, and typical *Red Flags*."
echo
echo "---"

# Sections: keep the heading and the kept items; drop the intro prose between a heading and its
# first item (it describes surfaces the variant may not have; the dimensions carry the content).
awk -v sections="$SECTIONS" -v drop="$DROP_IDS" '
  BEGIN { split(sections, s, " "); for (i in s) keep[s[i]] = 1
          split(drop, d, " ");     for (i in d) dropid[d[i]] = 1 }
  /^## [0-9]+\. / { n = $2; sub(/\./, "", n)
                    insec = (n in keep); seen = 0; emit = 0; blanked = 0
                    if (insec) { print ""; print }
                    next }
  /^## /          { insec = 0; next }
  !insec          { next }
  /^- \*\*[A-Z]+-[0-9]+ · / { id = $2; gsub(/\*/, "", id)
                              seen = 1; emit = !(id in dropid)
                              if (emit) { if (!blanked) { print ""; blanked = 1 }; print }
                              next }
  { if (seen && emit) print }
' "$BASE" | cat -s

echo "---"
echo
echo "## Prioritization"
echo
# Authored per variant — the master's prioritization ranks platform concerns (token economy,
# FinOps) that the smaller variants deliberately do not contain. Same judgment-frozen-as-data
# rule as the section lists above.
case "$VARIANT" in
  web)
    cat <<'EOF'
When not everything can be addressed at once, the following dominate for this system class:
**asynchronous resilience** (`RES-1`, `RES-3`), **protection of credentials and sessions**
(`SEC-3`, `SEC-1`, `SEC-10`), **object-level authorization** (`SEC-8`), **API backward
compatibility** (`API-1`, `API-2`, `CLIENT-3`) and the **GDPR third-country transfer**
(`GDPR-1`). Scalability, modularity and clean code are important, but table stakes — not what
such projects typically fail on.

The structural dimensions `MAINT-1` (modularity & context-window fit), `MAINT-7` (dead-code
hygiene), `MAINT-8` (drift control), `MAINT-9` (data-model integrity) and `PERF-5` (container
topology) are table stakes too, but they erode **silently over many changes** rather than failing
a single PR. They are tracked periodically over the whole codebase by
`wai-architecture-audit` — which measures their **trend** rather than a one-time pass/fail.
EOF
    ;;
  minimum)
    cat <<'EOF'
When not everything can be addressed at once, the following dominate: **object-level
authorization and tenant isolation** (`SEC-8`), **secrets out of the code** (`SEC-3`),
**input validation at the boundary** (`SEC-7`), **correctness under repetition** (`RES-3`),
and the two GDPR dimensions that cannot be retrofitted — **third-country transfer** (`GDPR-1`)
and **implementable deletion** (`GDPR-3`).

The structural dimensions `MAINT-1` (modularity & context-window fit), `MAINT-7` (dead-code
hygiene), `MAINT-8` (drift control) and `MAINT-9` (data-model integrity) erode **silently over
many changes** rather than failing a single PR. They are tracked periodically over the whole
codebase by `wai-architecture-audit` — which measures their **trend** rather than a one-time
pass/fail.
EOF
    ;;
esac
echo

# Retired IDs travel with every variant: an ID is never reused, and old findings must stay
# resolvable no matter which variant a repo adopted.
awk '/^## Retired IDs/{f=1} f' "$BASE"

exit 0
