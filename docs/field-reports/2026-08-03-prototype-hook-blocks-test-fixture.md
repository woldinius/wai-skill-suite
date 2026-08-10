# DEFECT: the wai-learning-gap hook blocks the commit of the suite itself (false positive)

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a game-server prototype).

**Context:** suite update via `install.sh` (the 2026-08-02 suite version) committed in the
prototype repo. The locally installed pre-commit hook (from `install-hook.sh`) blocked the
commit:

```
✋ Commit blocked: an open learning task (LEARN #) is staged.
```
*(message translated)*

## Cause
`scripts/tests/run.sh` in the wai-learning-gap skill contains:
```sh
printf '// LEARN #7 [x]\n' >> "$Rog/src/a.txt"
```
— a test fixture that tests the hook **against itself**. The installed hook greps
`LEARN #[0-9]` across all non-markdown files (`-- . ':!*.md' ':!*.mdx' ':!*.markdown'`) — and
`run.sh` is `.sh`, not `.md`, so it matches its own test-fixture literal.

**Consequence:** as soon as someone commits the suite **into a repo that already has its own
hook installed**, the hook blocks itself. That is not an edge case — every repo that actively
uses the wai-learning-gap skill AND versions the suite itself (as here: `install.sh` puts
`.claude/skills/` into the target repo) hits this on the next suite update.

## Proposal
- Extend the hook (or the grep pattern `install-hook.sh` generates) with a path exclusion for
  the suite itself, e.g. `':!.claude/skills/**'` in addition to the markdown exceptions —
  analogous to how `*.md` is already excluded as "the marker never lives in docs": test fixtures
  that need the marker as a text payload are the same case.
- Alternative: write the fixture in `run.sh` so it assembles the string at runtime
  (`printf '// LEARN #%s [x]\n' 7`) instead of carrying it as a contiguous literal in the source
  — then no grep matches the source file itself, only actually generated test trees.

## Fixed (in the incident)
Committed with `--no-verify`, reason documented in the commit body (no `--no-verify` without a
traceable justification). No real gap was lost — ledger + tree verified beforehand.
