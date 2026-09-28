# 0005 · The review runs in an agent — and only the review

**Status:** accepted · 2026-09-27
**References:** ADR-0002 (the gate is a conjunction: the script's exit code and the reviewer's
judgment) · `wai-team` §*Attended or unattended* (the fresh-context reviewer it already required) ·
[lean-output A/B](../experiments/2026-09-26-lean-output-ab.md) and
[grilling A/B](../experiments/2026-09-27-grilling-rounds-ab.md) (what the token bill follows).

## Context

Two facts met in the 0.5 line.

**The review needs fresh context.** `wai-team` has required it since #58 (2026-09-13): the
session that built a change reviews it under completion pressure, with the author's reasoning
still loaded. So every unattended review ran in a subagent briefed ad hoc — the diff, the issue or
plan, the catalog, never the transcript. Each run wrote that brief again, and nothing checked it.

**The main thread pays for every turn with its whole context.** The lean-output A/B found that
cutting visible text left the token bill where it was; the grilling A/B found the bill following
the turn count (responses −42 %, all tokens −37 %). A review is a long run of turns — read the
diff, the spec and the catalog, run the lints and the gate, write and post the comment — and in
the session that implemented the change, each of them re-reads that session's context.

## Options

1. **Keep briefing a subagent per run.** Works where it is done; the brief drifts, and an attended
   session that wrote the change reviews it in its own context.
2. **Ship a named reviewer agent** with the review skill preloaded, and dispatch it whenever the
   session asking wrote the change or carries a long context.
3. **Also ship a gate-runner** — a small model that runs `merge-gate.sh` and returns its output.
   *Rejected:* dispatching an agent costs the main thread one response, exactly what one compound
   shell command costs, and the agent adds its own context on top. An agent pays off only where
   it replaces several main-thread turns; the review does, a script run does not.

## Decision

**Option 2.** `.claude/agents/wai-reviewer.md` preloads `wai-pr-review`, carries read-only tools
plus `Bash` (for `gh` and the gate), posts the review, runs the gate, adds its result — and merges
nothing: the merge decision stays with the caller, which owns the repo's policy. `wai-team`
dispatches it for every review; attended, `wai-pr-review` runs in place and dispatches it on
request or once the session's context has grown long. `install.sh` and the plugin ship it.

The attended default was narrowed before the merge, by a measurement: it had read "dispatch
whenever the session wrote the change" (see *Consequences*).

The skill preloads through the agent's `skills:` list. Checked on 2026-09-27 with Claude Code
2.1.283 before anything was built: a plugin agent listing a probe skill answered with a token
that exists only in that skill, the same agent without the list answered `NONE`, and the bare and
the plugin-namespaced skill name both resolved. The preloaded skill's base directory reaches the
agent too — it named the probe skill's absolute path — so a plugin install finds
`merge-gate.sh`. The plugin loader takes agent *files*, not a
directory, so `plugin.json` names each one and `tests/run.sh` checks the list against the files.

## Consequences

- One brief, in one file, for every fresh-context review; the comment names the agent, so a
  reader can tell a fresh review from a self-review.
- **What it does not fix.** "Merges nothing" is an instruction, not a mechanism: `Bash` can run
  `gh pr merge`, and plugin agents ignore permission modes and hooks. The mechanical guards stay
  where they were — the gate's exit code, and in `team` mode the approval rule on `main`.
- **Measured on 2026-09-28** ([lifecycle A/B](../experiments/2026-09-28-review-agent-ab.md),
  n = 2, with the broad attended default): the fresh review took 30 and 43 responses of its own;
  the run's tokens moved +6 % (inside the spread) and its output +39 %. The main thread's review
  step was lighter (2.5 and 2.7 M tokens against 4.0 M in the one comparable run) without making
  the run cheaper. The agent's reviews missed nothing a blind grader found; one in-session review
  missed a Minor. So its case is fresh context, not tokens — the default only where no human
  stands between the verdict and the merge.
- Without the agent, the caller briefs a subagent the same way; without subagents, the review
  runs in place and says so (`wai-pr-review` §*Process*). In a `wai-team` run that means no
  merge: its fallback stays a hand-over.
