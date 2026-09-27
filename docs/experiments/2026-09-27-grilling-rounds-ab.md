# Grilling in rounds, measured — a controlled A/B with a simulated product owner (2026-09-27)

**Question.** Grilling v2 ([#98](https://github.com/woldinius/wai-skill-suite/pull/98)) asks
every open decision whose prerequisites are settled in one round, instead of one question at a
time. Does that save the human interruptions and the run tokens, and does the plan stay as good?

## Method

- **Two arms.** A = the suite at `7a795f9` (v0.5.0, one question at a time) · B = `a1f28d6`
  (after #98, rounds over the frontier).
- **One fuzzy requirement.** Extend `inventory`, a small stock CLI described only by its README:
  track stock per storage location, move stock between locations, get reorder alerts before items
  run out; existing data must keep working. Planning only, with `wai-requirements-planning` and the
  directive "grill me".
- **Per run:** a fresh sandbox repo (README, the requirement, the `minimum` catalog; the arm's
  suite installed with its own `install.sh`), one planner agent and one simulated product owner.
  The planner read the skills from the sandbox; local only, no subagents, no question UI.
- **The simulated owner** is a second agent, the same instructions in all four runs. It answers
  only from a hidden brief of 12 decisions (below); on anything else: "No preference — go with
  your recommendation". It does not volunteer decisions; at a playback or a plan to approve it
  vetoes only what contradicts the brief.
- **The channel is files.** The planner writes each message to `grill/q-<n>.md` and ends its
  turn, as in a chat; the owner replies in `grill/a-<n>.md`. The main session relayed only the
  file names (one exception: see *Limits*).
- **Grading, blind.** A third agent received the four plans renamed `P1`–`P4` in random order,
  with the requirement and the brief, and graded each brief item: *match*, *absent* (silent, open,
  or only a risk) or *contradicts*.
- **Two runs per arm (n = 2).** The sandboxes were deleted after this report was reviewed.

**Metrics.** *Interruptions:* messages to the owner before the plan was written (question rounds
and the playback). *Numbered questions:* the question numbers across all rounds; *asks, as the
owner counted them:* its own log, which counts a second ask under one number separately. *Words
the owner read:* those messages, without the plan sent for approval (three of four runs sent it).
*Tokens and responses:* `session-cost.sh` on the planner's transcript; *all tokens* = output +
fresh input + cache read.

<details><summary>Requirement, brief (hidden from the planner) and both prompts</summary>

The requirement (`REQUIREMENT.md`):

```
Extend `inventory` so a small shop with several storage locations can track stock per location,
move stock between locations, and get reorder alerts before items run out. Existing data must keep
working.
```

The brief:

```
# Product owner brief (hidden from the planner)

You own `inventory`, a small shop's stock tool. Your decisions, and ONLY these:

1. Locations are free-text names (a shop has at most ~10). Existing data goes into a location called `main`.
2. Existing single-location JSON files migrate automatically on first load; keep a `.bak` copy of the old file.
3. Transfers: `move <item> <qty> <from> <to>`, all-or-nothing — fail if the source has too little; never a partial move.
4. Stock can never go negative, anywhere.
5. The reorder threshold is per item (one number across all locations), not per location. Default: no threshold.
6. An alert fires when an item's TOTAL stock across locations drops strictly below its threshold.
7. Alerts: a warning line printed by the command that caused it, plus an `alerts` command listing every item below threshold. No email, no webhooks.
8. `list` shows each item with a per-location breakdown and a total, sorted by item name.
9. Item names are case-insensitive and Unicode-NFC-normalized; show the first spelling ever entered.
10. One user at a time; no locking — document that.
11. Quantities are whole pieces only (integers).
12. A location can be removed only when empty; otherwise it is an error.

Anything else: you have no preference.
```

The planner's prompt:

```
Plan a change in the git repo at <sandbox> using the wAI skill suite installed in that repo.
Rules: work only inside that repo; use the suite by READING the skill's instructions from
.claude/skills/<skill>/SKILL.md inside that repo, and the references they name (no Skill tool,
no subagents); local only — no GitHub, no gh, no push, no network; where a skill step needs
GitHub, skip it and say so in one line.
The task: the requirement in REQUIREMENT.md, with the directive "grill me". Plan it with
wai-requirements-planning; planning only, no implementation. Write the plan the skill produces
under docs/planning/.
The human is a product owner you reach only through files; there is no question UI. To say
anything to the human, write it to grill/q-<n>.md (n = 1, 2, 3, …; one file per message) and
end your turn with exactly the line: ASKED grill/q-<n>.md
The human's reply will arrive as grill/a-<n>.md; your next message names it. When the plan is
written, end your turn with exactly the line: DONE
```

The simulated owner's prompt:

```
You play the product owner of `inventory`, a small shop's stock tool. A planner interviews you through files in the repo <sandbox>/grill/. Your decisions are in <brief> — the only source of your answers. Never copy the brief or mention that it exists.

Each time you get a path grill/q-<n>.md, read <sandbox>/grill/q-<n>.md and write your reply to <sandbox>/grill/a-<n>.md. Then append one line to <log>:
<n><TAB><questions answered><TAB><brief item numbers your reply used, comma-separated, or -><TAB><kind: questions|playback|other>
and end your turn with exactly the line: ANSWERED a-<n>

How to answer:
- Answer every question in the file, by its number where it has one. Count one question per decision asked (sub-options of one decision are one question).
- Where a brief item settles a question, give that decision, briefly, in your own words.
- Where no brief item settles it: "No preference — go with your recommendation." (or "No preference — your call." when none is given).
- Do not volunteer decisions the file does not ask about.
- A summary to confirm (playback): veto each line that contradicts a brief item, giving the brief's decision instead; otherwise confirm. Do not add points the summary lacks.
- Short, plain sentences, like a busy product owner.

The first file is grill/q-1.md.
```
</details>

## Results

| Metric | A1 | A2 | B1 | B2 | mean A | mean B | Δ |
|---|---:|---:|---:|---:|---:|---:|---:|
| Interruptions before the plan | 7 | 12 | 3 | 3 | 9.5 | 3 | **−68 %** |
| Numbered questions | 6 | 11 | 15 | 9 | 8.5 | 12 | +41 % |
| Asks, as the owner counted them | 6 | 25 | 15 | 9 | 15.5 | 12 | −23 % |
| Words the owner read before the plan | 2,777 | 4,929 | 3,730 | 2,745 | 3,853 | 3,238 | −16 % |
| Responses | 60 | 72 | 32 | 45 | 66 | 38.5 | −42 % |
| Output tokens | 100,923 | 118,464 | 146,272 | 121,818 | 109,694 | 134,045 | +22 % |
| Fresh input tokens | 213,048 | 210,032 | 394,391 | 234,375 | 211,540 | 314,383 | +49 % |
| Cache-read tokens | 8.2 M | 10.5 M | 4.6 M | 6.7 M | 9.4 M | 5.7 M | −40 % |
| All tokens | 8.5 M | 10.9 M | 5.2 M | 7.1 M | 9.7 M | 6.1 M | **−37 %** |
| Average context per response | 140,241 | 149,227 | 156,474 | 154,189 | 144,734 | 155,332 | +7 % |
| Plan (words) | 3,357 | 4,274 | 5,408 | 3,443 | 3,816 | 4,426 | +16 % |
| Brief items: match · absent · contradicts | 11 · 1 · 0 | 12 · 0 · 0 | 10 · 0 · 2 | 11 · 1 · 0 | | | |

## Reading

- **Fewer interruptions; the decisions asked within the noise.** Both B runs stopped the owner
  three times before the plan, the A runs 7 and 12 times. How many decisions reached the owner
  depends on the count: by numbered questions B asked more (12 against 8.5), by the owner's own
  count fewer (12 against 15.5) — A's single questions often carried a second ask. A round asks
  the whole frontier, so B's question rounds ran 814–1,766 words against 272–495 for A's single
  questions; in total the owner read about as much (−16 %, inside the spread).
- **The token bill fell with the turn count.** Responses −42 %, cache reads −40 %, all tokens −37 %;
  every B run is below every A run. The context per response stayed alike (+7 %); output (+22 %) and
  fresh input (+49 %) rose: fewer, larger turns. In the lean-output A/B
  ([2026-09-26](2026-09-26-lean-output-ab.md)) the turn count rose and the bill did not fall; here
  the turn count is the lever, and it moved the bill.
- **Plan quality: within the noise.** All four plans match 10–12 of the 12 brief items. Item 9 (how
  item names match) is absent from A1 and B2; neither interview asked it (for A1, see *Limits*).
  B1's two contradictions (negative and fractional numbers from old files carried over) trace to one
  answer of the simulated owner: asked in round 2 whether odd numbers in old files are carried over
  unchanged, it chose that option and confirmed the reading in the playback. The plan follows the
  answer.
- **The playback catches what the questions miss, in both arms.** B's playbacks listed the planner's
  assumptions and drew two vetoes each (the `move` syntax in both; whole-number quantities; name
  matching), and B2's plan approval vetoed an added rule (never remove the last location). A2's
  playback caught name matching; A1's playback passed, and its plan approval caught the `move`
  syntax.

**What follows.** Rounds cut the interruptions by two thirds and the planner's tokens by a third,
at plan quality within the noise of this sample — the first measured change in this release
line to lower the token bill, through the turn count.

**Limits.** n = 2 per arm, one requirement, one brief. The simulated owner is an instrument with
its own errors. Once it added a decision the plan lacked, against its rules: A1's first
plan-approval answer asked for item 9 (name matching). The main session reminded it of its
rules — the one message beyond a file name it relayed — and the answer was re-issued before the
planner read it; had it stood, item 9 would have reached A1's plan through the owner, not the
interview. Once it answered against its own brief (B1, above); at least once it named a detail
next to an asked decision (A1: the `.bak` copy); once it mentioned "the brief" to the planner
(A2, playback). B2 also watched for the answer files with background shell loops, which adds
wake-ups to its response count. No subagents, so the protocol's background lookup was not
exercised; no question UI; local only. The planners and the grader ran on `claude-opus-5-5`, the
simulated owners on `claude-sonnet-5`.
