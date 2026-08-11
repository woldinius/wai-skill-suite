# Changelog

Notable changes to the wAI skill suite. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags, and every claim here is
checkable against the tagged tree — `tests/numbers-lint.sh` keeps the measurable ones honest.

## [Unreleased]

### Added

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
