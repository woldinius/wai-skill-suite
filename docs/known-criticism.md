# Known criticism — named here before a reader has to

An external audit (2026-08-06, conducted cold: read, executed, re-measured, GitHub API queried)
produced two lists. Both belong in the repo, because the publication rule cuts both ways: claims
need measurements, and criticism that is right needs naming by the author — not discovery by the
reader.

## Provable — with status

| # | Criticism | Status |
|---|---|---|
| K1 | The repo shipping branch-protection templates had none itself (`rulesets: []`, protection: 404) — the Semmelweis failure its own docs describe five times, unnoticed at home | **closed** — ruleset active since PR #19: required checks on `main`, no admin bypass |
| K2 | The gate had never said GO in the published repo; by its own doctrine an unvalidated branch | **closed for existence** — first GO row 2026-08-06 (PR #17), reproduced in a second repo over 30 runs ([field report](field-reports/2026-08-06-thirty-runs-zero-false-negatives.md)); open as a *rate* — Q1 |
| K3 | fp/fn — "the measurement that matters" — had n ≈ 0 | **open, first data in** — this repo's rows are tagged; a field repo reports 12 judged NO-GOs, 0 fp, 0 fn (dated); Q3 wants ≥ 20 tagged rows here |
| K4 | Context cost per run: named as the biggest cost lever, never measured | **open** — Q5 |
| K5 | Six test cases pinned KNOWN DEFECTs as `ok` — a green that reads exactly like health | **closed** — pins have their own `XFAIL` column, and a pin that stops reproducing **fails red** (PR #26) |
| K6 | No plugin packaging; the marketplace channel — where most users look — is closed | **open, planned** |
| K7 | Repair density: 11 of 19 commits in three July days fixed just-shipped work; the first cold checkout filed three blockers in one day | **accepted as record** — it is the origin story, dated in the [retrospective](retrospective-2026-07.md) and [history](history.md); hiding it would break the thesis |
| K8 | The author's product shape is restated in 7 of 12 skills; `wai-init` scales the catalog, not the prose — repos without a token economy pay for `PAY-*` framing forever | **half closed** (2026-08-07) — the *catalog* half: three variant seeds (platform / web / minimum) generated from one master and CI-diffed against it ([ADR-0004](adr/0004-one-master-three-generated-variants.md)), so a repo without a token economy starts from a seed that never carried `PAY-*`/`AI-*` — 22 IDs at `minimum` against 87. Still open: the platform framing in the *skill prose*, and residual flavor inside kept dimensions (`MAINT-2` speaks of model mocks, `GDPR-1` of model providers) |

## Expected — and what the record answers

Objections that will come regardless of the facts, with the honest response. "Justified?" is the
audit's judgment, not a defense.

| Objection | Justified? | The answer |
|---|---|---|
| "Prompt engineering with extra steps — tens of thousands of words of prose" | No | The deciding layer is not prose: 220 cases, two shells, in CI, for the scripts that own the verdict |
| "One author, a young repo, bus factor 1" | Partly | Correct, and stated in *Limits*. Q7 exists because of it; the field-report path costs one paste |
| "The self-criticism is marketing" | No — but unfalsifiable by more self-criticism | Only foreign data answers it. That is Q7, and the reason the evidence channel optimizes for a single paste |
| "Determinism is nothing new" | Conceptually yes | The README names the prior art and claims only the level: a deterministic *verdict* in the agent's own loop — not the category |
| "Too opinionated for my repo" | Yes | Deliberate, and K8 names the cost honestly. The catalog now ships in three sizes — a `minimum` seed carries no `PAY-*`/`AI-*` at all; the skill prose does not scale yet |
| "Claude Code + GitHub only" | No | A named narrowing with documented seams (*Porting*) — one tested path over a matrix of half-tested ones |
| "The field reports are unverifiable — the repos are private" | Yes, unavoidably | No counter exists. What is public: this repo's own append-only ledger, and every number CI re-measures |
