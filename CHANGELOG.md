# Changelog

Notable changes to the wAI skill suite. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags, and every claim here is
checkable against the tagged tree — `tests/numbers-lint.sh` keeps the measurable ones honest.

## [Unreleased]

### Added

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

- The suite is its own **plugin marketplace**: `/plugin marketplace add woldinius/wai-skill-suite`,
  then `/plugin install wai-suite@wai`. `install.sh` remains as the copy-into-repo path.
- This changelog, and a README section stating exactly what the suite writes into a repo — and
  what it never touches.

### Changed

- **Provider-neutral deployment**: `wai-cicd`'s model is unchanged (GitHub Actions → GHCR →
  Docker Compose over SSH to your own Linux server) but no longer names a hosting provider;
  the runbook reference is now `references/deployment-guide.md`.
- **Platform context framed as the worked example** in the seven skills that carry it: the
  suite's home platform stays concrete, and the framing sentence says what it is — an
  illustration `wai-init` scopes to *your* repo, not a claim about your codebase.
- **Skill prompts phrase script calls relative to the skill's own directory**, so the same
  sentence is true in a repo install and in the plugin cache.
- Timestamps written by suite scripts carry normal UTC time again; the date-only rule is retired.

## [0.1.0] — 2026-08-10

### Added

- First release of the fresh repository: twelve skills, twenty-four enforcement scripts, the
  quality-catalog system (one master, three generated variants — ADR-0004), the mechanical merge
  gate with its append-only ledger, the numbers/lang/link lints, and the dated evidence base
  (field reports, empirics, ADRs, retrospective). The prior repository's history is summarized
  in `docs/history.md`.
