# The review in an agent, measured — a lifecycle A/B (2026-09-28)

**Question.** [#103](https://github.com/woldinius/wai-skill-suite/pull/103) moves the review into
`wai-reviewer`, an agent with `wai-pr-review` preloaded; as measured here (`fad0db7`), a session
dispatched it whenever it wrote the change. Does that lower what a lifecycle run costs — on the
main thread and in total — and does the review stay as good?

## Method

- **Two arms.** A = the suite at `666860d` (v0.5.1, the review runs in the session) · B = #103's
  branch at `fad0db7` (the session dispatches `wai-reviewer`).
- **One task**, the one of the [lean-output A/B](2026-09-26-lean-output-ab.md): build `inventory`,
  a small standard-library Python CLI and library, through plan → implement → test → review →
  hand-back.
- **Per run:** a fresh sandbox repo (the `minimum` catalog, the arm's suite installed with its own
  `install.sh`), one session agent reading the skills from the sandbox, the same prompt with only
  the path changed. Local only: `gh` was withheld, so the gate returned UNKNOWN.
- **The dispatch, emulated.** A subagent cannot start one, so a dispatch went through the main
  session: the session wrote its brief to `dispatch-<agent>.md` and ended its turn with a
  `DISPATCH` line; the main session started a fresh subagent that read the agent file and its
  preloaded skill from the sandbox, did what the brief asked, and returned its final message,
  which went back to the session verbatim. For the session that is about one turn, as a real
  agent call is (see *Limits*); the preload was read, not injected.
- **Grading, blind to the runs, not to the arms.** A third agent received the four reviews and
  branches renamed `P1`–`P4` at random, with the `Reviewed by` line and the dispatch lines removed
  from the reviews. The repos kept their history, and the grader noted it could pair them by arm.
  It checked each Blocker, Major and Minor finding against the code (*valid*, *overstated* — true,
  but not a defect of this change or rated too high — or *invalid*) and was asked to spend about
  15 minutes per repo on missed defects of Minor or higher, counting only what it reproduced.
- **Two runs per arm (n = 2).** The sandboxes were deleted after this report was reviewed.

**Metrics.** `session-cost.sh`, with the session's transcript as the main thread and the
reviewer's as its subagent; *all tokens* = output + fresh input + cache read. *Review step:*
responses between the `[[STEP review]]` and `[[STEP handback]]` markers, where they reached
visible text.

<details><summary>The session's prompt (path removed) and the reviewer's</summary>

```
Build a small piece of software in the git repo at <sandbox> using the wAI skill suite installed
in that repo.
Rules: work only inside that repo; use the suite by READING each skill's instructions from
.claude/skills/<skill>/SKILL.md inside that repo (no Skill tool); local only — no GitHub, no gh,
no push, no network; where a skill step needs GitHub, skip it and say so in one line; no
questions to the user — decide sensibly and state the assumption.
Agents: you cannot start subagents yourself. When a skill tells you to dispatch an agent, write
the brief you would give it to <repo>/dispatch-<agent>.md and end your turn with exactly the
line: DISPATCH <agent> dispatch-<agent>.md — the agent's final message comes back as your next
message.
The software: inventory, a Python 3 command-line tool and library, standard library only, that
tracks stock items — add <name> <qty>, remove <name> <qty>, list, and low --threshold N —
persisted as a JSON file, with unit tests run by python3 -m unittest.
Lifecycle, each step begun with a plain-text line [[STEP <name>]]: plan
(wai-requirements-planning) · implement (wai-implementation, branch agent/sandbox/feat-inventory)
· test (wai-testing) · review (wai-pr-review: review the branch against main as if it were the
PR, the review written to review.md, the scripts the skill names run where they run locally) ·
handback (the final message, as the skills instruct).
```

```
You are the agent defined in <sandbox>/.claude/agents/wai-reviewer.md: read that file first — it
is your system prompt. Its `skills:` list preloads wai-pr-review: read
<sandbox>/.claude/skills/wai-pr-review/SKILL.md next, as your procedure, with the references it
names as it says. Use only Read, Grep, Glob and Bash. Work only inside <sandbox>; local only — no
GitHub, no gh, no push, no network.
The session that dispatched you wrote this brief: <sandbox>/dispatch-wai-reviewer.md. Do what it
asks, and end with the final message your agent file prescribes.
```
</details>

## Results

| Metric | A1 | A2 | B1 | B2 | mean A | mean B | Δ |
|---|---:|---:|---:|---:|---:|---:|---:|
| Main thread: responses | 64 | 52 | 47 | 45 | 58 | 46 | −21 % |
| Main thread: all tokens | 16.1 M | 11.6 M | 10.7 M | 10.0 M | 13.9 M | 10.4 M | −25 % |
| Main thread: review step, responses · tokens | 11 · 4.0 M | — | 8 · 2.5 M | 9 · 2.7 M | | | |
| Reviewer agent: responses | | | 30 | 43 | | 36.5 | |
| Reviewer agent: all tokens | | | 3.3 M | 5.5 M | | 4.4 M | |
| Run: responses | 64 | 52 | 77 | 88 | 58 | 82.5 | +42 % |
| Run: output tokens | 182,745 | 145,087 | 225,391 | 230,393 | 163,916 | 227,892 | **+39 %** |
| Run: all tokens | 16.1 M | 11.6 M | 14.0 M | 15.5 M | 13.9 M | 14.8 M | **+6 %** |
| Minor findings: valid · overstated | 1 · 1 | 2 · 2 | 2 · 0 | 2 · 1 | | | |
| Missed, Minor or higher (blind grader) | 1 | 0 | 0 | 0 | | | |
| Tests green | 31 | 40 | 53 | 28 | | | |

No review found a Blocker or a Major, no finding was graded invalid, and the grader found no
missed Major.

## Reading

- **The run got more expensive.** The fresh reviewer re-reads what the session already knew — the
  change, the plan, the catalog, the skill — and took 30 and 43 responses of its own. Output rose
  39 %, responses 42 %; all tokens rose 6 %, inside the spread of the A runs (11.6 against
  16.1 M).
- **The main thread got lighter; how much of that is the agent, this sample cannot say.** Both B
  main threads used fewer tokens than both A runs (−25 %). The review step was lighter in B — 8 and
  9 responses, 2.5 and 2.7 M tokens, against 11 responses and 4.0 M in A1, the one A run whose
  markers reached that step — which covers about a quarter of A1's gap to the B mean (1.4 of 5.8 M).
  The rest sits in planning and implementation, which the arms share. One comparable A run cannot
  separate the agent from the spread.
- **The review held.** Both agent reviews had every Minor valid or, once, overstated, and missed
  nothing the grader reproduced. One in-session review (A1) missed a Minor the three others each
  found in their own code: `add` and `remove` print after the save, so an output failure exits
  non-zero after the change was written, and a retry applies it twice.

**What follows.** The agent's case is fresh context, not tokens. #103 narrowed its attended
default before the merge: every `wai-team` review runs in the agent — no human stands between the
verdict and the merge there — and an attended session reviews in place, dispatching the agent
when the human asks for an independent review or its own context has grown long.

**Limits.** n = 2 per arm, one small task; each run wrote its own code, so the reviews read
different changes. The dispatch was emulated: the preload was read rather than injected, each result
was relayed by a third session, and handing over took each B session one reply a real agent call
does not (the `DISPATCH` line after the brief). The step markers reached visible text in three of
four review steps. Both B sessions ran into a usage limit near the end: B1's hand-back was complete
but its closing reply was cut; B2 was resumed with one message after the reviewer's result had
reached it. The same model (`claude-opus-5-5`) ran every session, reviewer and the grader; local
only.
