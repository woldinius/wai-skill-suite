# 0004 · One master, three generated catalog variants

**Status:** accepted · 2026-08-07
**References:** `docs/known-criticism.md` K8 (the criticism this answers) ·
ADR-0001 (one file per repo — unchanged) · ADR-0002 (the boundary the generator must respect).

## Context

The shipped catalog baseline is the full platform build: 13 sections, backend + web + iOS +
Android, AI orchestration, token economy. K8 named the cost honestly: **a repo without a token
economy pays for the `PAY-*` framing forever** — `wai-init` scaled *which IDs exist* (the scope
dial) and *how much prose each carries* (the tier dial), but the scoping was a judgment the model
made per repo, at init time, against one platform-shaped seed. A reader could not see what a
smaller catalog would look like without running init; and the model doing the cut per run is
exactly the kind of unauditable step this suite argues against.

The obvious fix — ship three hand-maintained catalogs — is the failure mode this repo documents
everywhere else: a `SEC` fix that lands in two copies out of three is silent drift, and a stale
catalog reads exactly like a current one. The suite has already lost this game once with prose
copies (the 55-of-89 incident); three near-identical 200–500-line files would be the same bet at
better odds and higher stakes.

## Decision

**One master, three generated views.**

- `quality-attributes.baseline.md` stays the **single source of truth** — the only file whose
  content is authored.
- `catalog-variant.sh` derives three variants from it: **platform** (the master, verbatim,
  behind a variant banner), **web** (backend + web frontend — no AI, no token economy, no store
  surfaces) and **minimum** (core software engineering: `MAINT-*`, `SEC-*`, `GDPR-*`, plus
  `RES-3`).
- The variants are **checked in** so a reader can read them and `wai-init` can copy them — and
  `tests/run.sh` **re-derives all three on every run and diffs** them against the checked-in
  files. A master edited without regenerating, or a variant edited by hand, goes red in CI.
- **Section numbers and IDs are never renumbered** in a variant. A gap means "not in this
  variant"; `SEC-8` means the same dimension everywhere. The ID is the suite's only linking
  primitive (ADR-0003), and a variant that renumbered would silently rebind every citation.
- `RES-3` survives every cut — the same exception the master's scoping table already makes,
  because correctness under repetition is core, not platform flavor.

**Where the ADR-0002 line runs here.** *Which* section and ID belongs to *which* variant is a
judgment — made once, by the author, and frozen as data in the script (the section lists and the
per-ID drop lists, each with its stated reason). What the script does at runtime is mechanics:
select, extract, assemble — which is why its output can be diffed. The script never decides
anything per run. A generator that made per-run choices would be a judgment smuggled into a
`.sh` file, and ADR-0002 says that script gets deleted.

**ADR-0001 is unchanged.** A target repo still gets exactly one live catalog file; only the
*offering* of seeds is now three instead of one.

## Consequences

- `wai-init`'s scope dial becomes a **variant choice** — deterministic and readable before init
  ever runs, instead of a per-run model judgment. The tier dial (prose depth) stays orthogonal.
- Repos without a token economy or AI integration no longer carry `PAY-*`/`AI-*` sections at
  all. **What this does not solve** — and K8 keeps open: the *prose inside kept dimensions* is
  still platform-flavored in places (`MAINT-2` speaks of model mocks, `GDPR-1` of model
  providers). De-flavoring prose per variant is authoring, not selection, and would put judgment
  into the generator; if it is ever done, it is done in the master with neutral wording.
- The variants add derived content to the installed footprint. The alternative — generating at
  install time — was rejected: a file a reader cannot read before installing is a file nobody
  reviews, and the install path is deliberately dumb (copy + manifest).
- One more script to hold the line on: `catalog-variant.sh` exits `0` (generated) or `2` (could
  not generate — fail closed, partial output is worse than none). It has no exit 1, because it
  renders no verdicts.
