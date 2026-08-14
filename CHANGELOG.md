# Changelog

Notable changes to the wAI skill suite. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags, and every claim here is
checkable against the tagged tree — `tests/numbers-lint.sh` keeps the measurable ones honest.

## [0.2.0] — 2026-08-14

### Added

- **`wai-retro`** — the thirteenth skill (#14): retrospectives **from artifacts, at a threshold —
  never from recall** ("reports happen when someone asks": ~250 field verdicts produced zero
  reports in between, and a from-memory retrospective reported 2 of 6 verified collaboration
  failures). Triggered by doctor's report-cadence advisory or on request, it consumes
  `gate-stats.sh --report`, the run log and the open-items footer, narrates with raw row counts
  beside every rate (ADR-0002: scripts extract, the model narrates, the human judges), and
  finishes with `--report --mark` so the cadence resets. Ships
  `wai-retro/scripts/retro-compliance.sh`: run-log rows × gate-ledger rows × `git log --merges`
  → the share of merged PRs that left a trace. The collaboration level is gated until a question
  trace exists; publication to this repo is explicit-request only, sanitized and pseudonymized
  (`fr-<12hex>`, keyed hash, key stays with the reporter).

- **Hand-back instrumentation** (#11, #7). A **run log** beside the gate ledger
  (`wai/scripts/run-log.sh` → `docs/architecture/run-log.md`, append-only, fail-open): one
  attendance row per skill run, because the record used to measure side effects, not work — a run
  that filed nothing vanished. `merge-gate.sh`, `backlog-scan.sh` and `dep-cve-scan.sh` self-log
  (their script↔skill mapping is 1:1); the prose skills log at their hand-off step.
- **`wai/scripts/open-items.sh`** — the derived hand-back footer: open PRs, issues assigned to the
  handle, branches with unique commits and no PR, the merged-but-unreachable sweep, untagged
  ledger rows, merged PRs since the last audit, foreign worktrees — pasted verbatim beneath every
  `▶ Recommended next`, because self-recall under-reports ~3×. Empty lines name their derivation,
  absent artifact classes are skipped and named, a dead `gh` degrades per line.

- **`wai-team` package mode** (#12): the mandate can group issues into ordered packages with one
  branch/PR per package; worktree handling is honest about what exists, and a run that finds
  nothing to fix has a name — "Verified — nothing to fix" — instead of inventing work.
- **Counterproof as the rule** (#9): prove a test red before trusting it green, verify survivors,
  count hits, snapshot before sabotage — in the testing skill, the audit playbook and the git
  protocol's snapshot pattern.
- **Evidence-chain repair** (#8, #10): ledger outcome tags match on a 2-char prefix and unmatched
  tags are counted, never silently dropped; ledger why-cells put ✗/? reasons first; `gate-stats.sh
  --report [--mark]` emits the dated report extract and plants the cadence marker; doctor carries
  the report-cadence advisory (threshold 25, `REPORT_THRESHOLD` override).
- **The installer's ledger guarantee** (#10): every `rm -rf` in `install.sh` stays inside
  `.claude/skills/`, and `docs/` — above all the gate ledger and the run log — is never touched by
  an update; held by a byte-identical fixture test. The three-week field-ledger report landed as
  dated evidence beside it.
- The suite is its own **plugin marketplace**: `/plugin marketplace add woldinius/wai-skill-suite`,
  then `/plugin install wai-suite@wai`. `install.sh` remains as the copy-into-repo path.
- This changelog, and a README section stating exactly what the suite writes into a repo — and
  what it never touches.

### Changed

- **Token-reduction pass** over the 13 SKILL.md bodies (−2,972 words, −7.7%): repeated rationale
  and narrative padding removed, every normative rule, script contract, pinned format and counted
  claim kept — the full battery holds it.
- **`wai-learning-gap`**: the open-gap sweep sees every worktree of the repo (#13), and difficulty
  now scales hint strength instead of answer visibility (#3).

- **Provider-neutral deployment**: `wai-cicd`'s model is unchanged (GitHub Actions → GHCR →
  Docker Compose over SSH to your own Linux server) but no longer names a hosting provider;
  the runbook reference is now `references/deployment-guide.md`.
- **Platform context framed as the worked example** in the seven skills that carry it: the
  suite's home platform stays concrete, and the framing sentence says what it is — an
  illustration `wai-init` scopes to *your* repo, not a claim about your codebase.
- **Skill prompts phrase script calls relative to the skill's own directory**, so the same
  sentence is true in a repo install and in the plugin cache.
- Timestamps written by suite scripts carry normal UTC time again; the date-only rule is retired.

### Fixed

- **PR #19's gate row, lost to a merge-conflict resolution, restored verbatim** with provenance —
  field evidence for the known class "append-only files are what merge tools silently truncate".
- **doctor's hooksPath check canonicalizes both sides** (#18), so an absolute `core.hooksPath`
  pointing at the repo's own `.githooks` no longer reads as drift.
- Every inline rule in the skills is anchored to its catalog ID, and two contradictions between
  skills were resolved.
- Dead references to archived audit/proposal files unlinked.

## [0.1.0] — 2026-08-10

### Added

- First release of the fresh repository: twelve skills, twenty-four enforcement scripts, the
  quality-catalog system (one master, three generated variants — ADR-0004), the mechanical merge
  gate with its append-only ledger, the numbers/lang/link lints, and the dated evidence base
  (field reports, empirics, ADRs, retrospective). The prior repository's history is summarized
  in `docs/history.md`.
