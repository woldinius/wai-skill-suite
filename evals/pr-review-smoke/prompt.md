---
description: >-
  Plugin smoke case. A PR review must load wai-pr-review from the plugin and run its merge gate by
  the path beside the skill, with the workspace as the repo root (the #95 call form). The workspace
  is empty and no git repo, and gh has no credentials there, so the gate can only say UNKNOWN: the
  graders check that the skill loaded and that its script ran from the plugin, not the verdict.
  It calls the model, so it is run by hand and not in CI; the command is in README.md, Repo
  structure.
tags: [smoke]
runs: 1
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
expected_outcome: >-
  The wai-pr-review skill is invoked; a Bash call runs
  `sh /<plugin root>/.claude/skills/wai-pr-review/scripts/merge-gate.sh 1`; its output carries a
  VERDICT line (UNKNOWN here); the reply reports that verdict.
---

Can PR #1 be merged? Review it, and include the merge gate's verdict.
