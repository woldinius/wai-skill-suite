---
description: >-
  Plugin smoke case. A PR review must load wai-pr-review from the plugin and run its merge gate by
  the path beside the skill, with the workspace as the repo root (the #95 call form). The workspace
  is empty and no git repo, and gh has no credentials there, so the gate can only say UNKNOWN. The
  proof that the gate RAN is a line it assembles at run time when it skips its ledger rows outside
  a repo; no file holds it, so reading the script cannot fake it (tests/scripts.sh pins both). It
  calls the model, so it is run by hand and not in CI; the command is in README.md, Repo structure.
tags: [smoke]
runs: 1
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
expected_outcome: >-
  wai-suite:wai-pr-review is invoked; a Bash call runs
  `sh /<plugin root>/.claude/skills/wai-pr-review/scripts/merge-gate.sh 1` and its output carries
  the gate's skipped-rows line; the reply quotes the gate's VERDICT line (UNKNOWN here).
---

Can PR #1 be merged? Review it, and include the merge gate's verdict.
