---
name: wai-team
description: >-
  Mandated backlog orchestrator: works multiple GitHub issues through the full lifecycle — per issue
  one run of plan → implement → test → review on its own `agent/**` branch and PR, integrated
  serially through the merge queue. Requires an explicit mandate (which issues, and how decision
  points are handled) and hands back one collected decision list. Invoked without a named issue set,
  it first scans the backlog and proposes — it proposes, the human mandates — and an explicitly
  opted-in, bounded autonomous-integration mode exists. Use it when the human commissions an issue
  set: "work the backlog", "process issues #12–#18", "burn down the tier", "wai-team". Not for a
  single issue — use the lifecycle skills directly.
license: MIT
---

# Team (backlog orchestrator)

Work a **set of GitHub issues** through the suite's lifecycle — each issue as its own
plan → implement → test → review cycle on its own `agent/<handle>/<type>-<slug>` branch and PR —
and integrate the results **serially** through the merge queue. The human commissions a batch
once, the team runs the proven per-issue cycle repeatedly, and everything that needs a human lands
in **one collected decision list** instead of N interruptions.

## Mandate first — no mandate, no team run

This skill runs only on an **explicit mandate** from the human. **Propose, don't self-mandate:**
invoked *without* a named issue set, it does **not** start a run — it runs `backlog-scan.sh`,
presents a proposal (which issues, in what order, at what risk), and **stops**. No branch is cut
and no issue is claimed until the human confirms the four mandate dimensions below.

The mandate fixes:

- **The issue set** — explicit numbers (`#12–#18`), a label query (default:
  `gh issue list --label ready-for-agent`), a named tier/epic — or **packages**:
  `--packages "298,282,281,252" "288,260,270,287"`, where each quoted group is worked as **one
  branch and one PR per package**. Bundle when the issues **share a root cause or a single
  guard**; unrelated small fixes stay one-PR-per-issue. Inside a package the per-issue mechanics
  survive in full: every issue is **claimed individually**, keeps its **own counterproof and
  rigor**, and gets its own `Closes #N` line in the package PR body. First field run: eight
  issues, two packages, **2 PRs, 8/8 counterproofs, 2 skill cycles instead of 32**. (No conflict
  with `wai-requirements-planning`'s "a set means ONE requirement": planning **fuses** one
  requirement into one plan; a team package bundles issues that **share a cause but remain
  separate issues**.)
- **Decision-point handling** — per `issues-protocol.md` the default is: **collect** —
  Blocker/Major findings and excluded-domain merges are gathered and presented at the end as
  the decision list; the run continues with the next issue. The human can instead mandate
  "stop on the first Blocker" or "fix Majors directly".
- **A stop budget** — after how many issues / how many consecutive failures the run ends
  (default: the given set, stop after 2 consecutive failed issues).
- **Integration mode** — **solo**, **team**, or **autonomous** (opt-in, bounded — see
  *Autonomous integration*). The default follows the repo: a `team` repo where a second human
  approves every merge is `team`; a solo repo is `solo`. **`autonomous` is never a default**
  and is refused unless the repo has affirmed an autonomy allowlist (see below).

At kickoff, once the mandate is confirmed, record the run **START timestamp**
(`date -u +%FT%TZ`). It bounds the cross-issue digest (step 6) and the autonomous-merge report.
Keep its full time: it is compared against GitHub's own `updatedAt`/`createdAt`, and rounding
would widen the window.

Everything else (branch rules, merge gate, issue formats) comes from the suite protocols —
this skill adds orchestration, **not** new authority.

## Process

1. **Select & read** — **with no set named, do not resolve the backlog by eye:** run
   `backlog-scan.sh` and present its overview *as the proposal* — per open issue: number,
   title, claim-state, the **`has_ac_checkboxes`** advisory flag (a mechanical fact, not a
   verdict), the contract/exclusion-domain flag, size label, parsed blockers, and the frontier
   + mechanical default order — then **stop before claiming**. Whether a
   `has_ac_checkboxes: no` issue is genuinely un-actionable stays a **model judgment**: drop it
   (comment what's missing, label `needs-info`, move on) or keep it. Obey the exit code:
   `exit 0` = an overview was produced — **including an empty backlog** (zero open issues is a
   valid proposal, not an error) · `exit 2` = **UNKNOWN**: no `gh`, unauthenticated, or the
   listing failed — propose only from the issue links the human gave you and **say the backlog
   went unread**; never guess one. There is no `exit 1`: this script renders no negative
   verdict, it reports and the human decides.
   Once the set is mandated, `gh issue view <N> --comments` each selected issue.

2. **Classify & order** — take the **frontier and dependency graph from `backlog-scan.sh`**;
   do not re-derive them by eye. Refine the order with judgment, but **never reorder a blocker
   after its dependent**. Issues touching an **excluded domain** (the canonical set in
   `references/agent-git-protocol.md § Excluded domains`) stay **serial and human-gated in
   every mode — including autonomous**.
   - **Serial lane (mandatory)** for issues touching an excluded domain — never run alongside
     anything that touches the same ground.
   - **Disjointness check** for the rest: estimate the touched areas (paths, modules, surfaces)
     from the issue + a quick repo scan. Issues that overlap go in sequence, not in parallel.
   - **Order from the scan's dependency graph** (blockers first, then value/risk) — work the
     frontier: any issue whose blockers are done.

3. **Run the cycle per issue — serial by default.** For each issue, on its own
   `agent/<handle>/<type>-<slug>` branch: `wai-requirements-planning` (proportional — a
   well-specified small issue skips the plan doc, per the planning skill's own rules) →
   `wai-implementation` (includes the plan-delta check) → `wai-testing` → `wai-pr-review`. Under
   a **packaged mandate** the cycle runs once per **package**, on the package's one branch — the
   issues inside are still claimed one by one, counterproofed one by one, and each closes through
   its own `Closes #N`; the package shares the branch and the PR, never the evidence. Clean,
   non-excluded PRs merge under the normal gate (in a `team` repo that means auto-merge armed and
   waiting for another human's approval — see the git protocol); everything else joins the
   **decision list**. After each merged issue, the next cycle starts from the fresh `main`. In
   **autonomous** mode the allowlist eligibility floor and the serial post-merge barrier both
   apply — see *Autonomous integration*.

   Two things must hold **before each issue's branch is cut** — this skill switches branches more
   than any other, so it is where collisions and dirty trees actually bite:
   - **Claim the issue** (`issues-protocol.md` §*Claiming*): assign it to yourself. An issue
     already **assigned to someone else** is **skipped**, not built a second time — list it in
     the report as "claimed by @x". Same for a branch that exists for this slug and whose commits
     carry someone else's email.
   - **Clean working tree — and no learning gaps in an autopilot run.** A gap (🧩 `LEARN #`) is
     deliberately red and waits for a *human*; nobody is at the keyboard here.
     `wai-implementation` therefore plants **no** gap during a team run. If you nonetheless find
     one open (left over from an earlier interactive session), it blocks both the commit (local
     pre-commit hook) and the branch switch: resolve it first (`wai-learning-gap`, flow C), then
     move on. Never carry a gap into the next issue's branch.

   **In a `team` repo, nothing merges inside the run.** Every PR ends *auto-merge armed, waiting
   for another human's approval* — so `main` does **not** advance between issues. Two
   consequences, and they are not optional:
   - **Never start an issue whose blocker hasn't merged.** Its code isn't on `main`, so the
     branch would be cut without it. Leave it in the frontier and report it as *blocked — waiting
     on #X's approval*. Only **independent** issues keep running.
   - Say so plainly in the report: a team run delivers a **set of approval-ready PRs**, not a
     merged backlog. If the human wants the dependent chain built anyway, the honest options are
     to approve as the run goes, or to mandate stacked PRs (each branched off its predecessor),
     which trades review simplicity for throughput.

4. **Worktrees — and honesty about what they buy.** A single-agent session runs nothing
   concurrently: mandated "parallelize", it works **sequentially through multiple worktrees**,
   one per branch, and must say so. Still worth having — no branch switching, no rebase
   juggling, no ambiguity about which state is checked out — but pretending otherwise promises a
   simultaneity nobody delivers. **Genuine concurrency exists only when the runtime actually
   runs sessions in parallel** — then, and only when mandated, run at most **2–3 issues at
   once**, each in its own worktree on its own branch, and only issues the disjointness check
   cleared. Contract/migration issues stay serial in either mode. Name plainly, in the report,
   which of the two happened. Parallel results **never merge directly**: they enter the merge
   queue.

5. **Integrate through the merge queue — only what actually needs serializing.** The serial run
   (step 3) produces PRs that are **disjoint by construction**; those need no queue — each is
   handled by the normal gate as its cycle ends. The **merge queue** is for PRs that genuinely
   interact: results of **bounded parallelism** (step 4) and PRs that piled up. Hand those to
   `wai-pr-review` in **merge-queue mode** (rebase onto fresh `main` → re-run checks → re-review
   the delta → normal merge policy), strictly one at a time. A PR that doesn't rebase cleanly is
   parked for the human, the queue continues. **In `team` mode the queue cannot drain itself**:
   only the head is armed, and it merges when a human approves — possibly after your run ends.
   That is the expected outcome, not a failure: arm the head, hand the rest over in queue order
   as a `ready-to-merge` list (**not** armed), and say so in the report.

   **A queue merge is "merged" only when it ARRIVED.** After each single merge the queue lands,
   run `sh ../wai/scripts/verify-arrival.sh <mergeCommit>` (from this skill's directory — a
   sibling path): exit 0 = **ARRIVED** on the freshly fetched `origin/<default>` — the report may
   say "merged"; exit 1 = **LOST** — the forge says MERGED but the default branch never received
   the commit (the stacked-PR class): stop the queue, say so loudly, hand it to the human; exit 2
   = could not verify, which is never "arrived". `post-merge-verify.sh` stays the **batch**
   barrier — it verifies `main` is *green* after a merge, a different question from whether the
   commit *arrived*, and both must hold before the next merge starts.

6. **Consolidate cross-issue notes** — run `cross-issue-digest.sh <START-ts> <worked-set>` to
   gather comments and edits made *since the run started* on issues **outside** the worked set:
   #-references, depends-on / blocked-by relations, and new findings, grouped and deduped.
   Curate the survivors — keep the real dependencies, drop the noise — and present them as a
   **Cross-issue notes** section in the report. This **complements** the landing rule: a genuine
   finding still gets **filed** as its own issue per `issues-protocol.md`. ADR-0003: present any
   catalog ID as **ID + dimension name**, and never copy a bare ID across the upstream/local
   boundary. Obey the exit code: `exit 0` = a digest was produced — **including an empty one**
   (no cross-issue activity since the start is a common, valid answer) · `exit 2` = **UNKNOWN**:
   no `gh`, missing arguments, or the listing failed — the digest could not be bounded to this
   run, so **record the gap in the report** instead of reporting that there was nothing to
   gather. There is no `exit 1`.

7. **Report** — end the run with the team report (format below): autonomously merged (if any),
   merged, verified-nothing-to-fix, decision list, withheld, cross-issue notes, parked/failed,
   issues filed. The decision list is the deliverable the mandate promised — never bury it.
   (The run-log row for this skill is written by `backlog-scan.sh` itself — do not log it again.)
   **Then derive the closing state:** run `sh ../wai/scripts/open-items.sh` (from this skill's
   directory — a sibling path), paste its output verbatim beneath the ▶ Recommended next block,
   then give your recommendation — in that order: the script derives (exit 0 = emitted; exit 2 =
   nothing derivable — then say `not checked` yourself), the model recommends.

8. **Learning hand-off (clean run, opt-in)** — after a **clean run**, and **only at an
   interactive hand-back with a human present**, offer exactly **one** learning gap by
   **handing off to `wai-learning-gap` Flow D**. Flow D owns everything: the ledger-is-consent
   gate, the PR ranking, the one-open-gap check, and cutting the fresh `agent/learn-*` branch
   from merged code. wai-team plants nothing, installs nothing, and **checks no ledger** — it
   only makes the offer. **On a headless, scheduled, or otherwise non-interactive run, skip
   silently and offer nothing.** If the run was not clean, there is no offer.

## Autonomous integration (opt-in, bounded)

Three integration modes, and they are **not** interchangeable:

- **solo** — the default in a solo repo. Clean, non-excluded PRs merge under the normal gate as
  each cycle ends; everything else joins the decision list.
- **team** — the default in a `team` repo. Skills never approve, so nothing merges inside the
  run: every PR ends *auto-merge armed, waiting for another human's approval*.
- **autonomous** — opt-in, bounded, and **never a default**. Even here the skill issues **no**
  merge command of its own.

**The eligibility floor is an ALLOWLIST, not a blocklist.** A PR enters the autonomous drain
only when *all four* hold: (a) `merge-gate.sh` returns **GO**; (b) the review found **no
Blocker and no Major**; (c) the excluded-domain **blocklist is CLEAR**; and (d) **every touched
path is inside the human-affirmed `AUTONOMY_SAFE_PATHS` set**. `excluded-domains.sh --autonomy`
returns **eligible** for (c) and (d) together — fail-closed on an empty or unaffirmed exclusion
surface; (a) and (b) come from the gate and the review. Anything not provably safe — a path
nobody affirmed, an empty/unaffirmed surface, an UNKNOWN result — is **HELD for the human**
(fail-closed). **The blocklist alone is under-inclusive and does NOT authorize autonomy — the
allowlist is the floor**; the blocklist stays on only as defense-in-depth.

**There is no autonomous-merge command.** Every merge — autonomous or not — routes through the
same `merge-gate.sh` conjunction, and the model **obeys its exit code, never re-derives it**.
Any drain-preflight is **advisory fail-fast only**: it can drop an obviously-ineligible PR
early, but it can never authorize a merge the gate would refuse.

**Strictly serial.** `post-merge-verify.sh` is a **hard barrier** between merges: the next
autonomous merge does not begin until it returns 0 on the last one. Autonomous mode **may not**
combine with bounded parallelism (step 4) or the self-draining queue (step 5) — one merge,
verify `main` is green, then the next.

**Team-repo honesty.** In a `team` repo skills still never approve, so "autonomous" there means
only *arm the head and run the post-merge test without pausing* — the server-side second human
still gates **every** merge.

Report the autonomous lane with `autonomous-merge-report.sh`, reconstructed from the
append-only gate ledger and the git log — never narrated from memory.

## Failure handling

- An issue whose cycle fails twice (red tests it can't fix, blocked plan) is **parked**:
  comment the state on the issue, label `ready-for-human`, continue with the next.
- **Stop the whole run** when the stop budget is hit, when `main` breaks, or when two parked
  issues point to the same root cause (a systemic problem, not an issue problem).
- **In autonomous mode, a red or UNKNOWN `post-merge-verify.sh` (exit ≠ 0) STOPS the whole run
  immediately** — that is `main` breaking under an autonomous merge. Follow the exit code, not
  a remembered rule: revert the offending merge or flag it, then hand back with the
  autonomous-merge report. Do not start the next merge.
- Never force progress by weakening the gate — a skipped check or an unreviewed merge is a
  protocol violation, not a workaround.

## Output format — team report

```
## Team run: [issue set · date]

**Mandate:** [issue set · decision handling · budget · integration mode]
**Run started:** [UTC timestamp]
**Result:** [N merged · M on the decision list · K parked/failed]

### Autonomously merged   (autonomous mode only — from autonomous-merge-report.sh)
- #N [title] → PR #P · merged [ts] · post-merge-verify green · [1 line what shipped]

### Merged
- #N [title] → PR #P (auto-merged | auto-merge armed, awaiting a human approval | queue-merged) · [1 line what shipped]

### Verified — nothing to fix
- #N [title] — measured: [what was run · what it showed] · claimed defect no longer exists · [hardened so it keeps holding | closed as-is]

### ▶ Your decision list
- #N / PR #P — [Blocker/Major finding or excluded-domain merge] · [recommendation]

### Withheld from autonomy — held for you
- #N / PR #P — [why: path not in AUTONOMY_SAFE_PATHS · excluded domain · Blocker/Major · UNKNOWN]

### Blocked — waiting on an approval (team mode)
- #N — depends on #X, whose PR #P is armed but not yet approved · not started

### Skipped — claimed by someone else
- #N — [assignee/branch owner] · not built, to avoid duplicate work

### Parked / failed
- #N — [why · what was left on the issue · label set]

### Cross-issue notes (since start)
- #N — referenced by … · depends-on / blocked-by … · [genuine finding filed as #F]

### Issues filed
- [follow-ups/minors filed during the run, per issues-protocol]

Learning: one representative gap offered (opt-in)   ← only when the clean-run hand-off fired
```

**`### Verified — nothing to fix` is a third outcome, not a variant of the other two:** without
its own name it lands under "merged" or "parked", hiding what actually happened. The
**measurement is mandatory in the line** — what was run, what it showed — so nobody closes an
issue with "looks fine". Field case: issue #252 claimed a guard had gone blind; measured, the
thresholds had been tightened since filing, and the counterproof fired on both tick rates.

## Principles

- **Propose, don't self-mandate** — with no set named, the skill scans and proposes; the human
  confirms the mandate before anything is claimed.
- **Autonomy is allowlist-gated, opt-in, serial and fail-closed** — the excluded-domain set and
  the merge gate are never lowered, an unrecognized path is **held, not merged**, `main`
  breaking stops the run, and autonomy **never** combines with parallelism.
- **No cross-issue note evaporates** — findings surfaced on other issues during the run are
  consolidated and filed, never dropped.
- **Same gate, applied serially** — merging is `wai-pr-review`'s policy in queue mode; this
  skill never merges on its own authority.
- **Disjoint or sequential** — parallelism is earned by the disjointness check, never assumed;
  excluded domains and migrations are always serial.
- **Mandate-bound** — the issue set, decision handling and budget come from the human; collected
  decisions are presented, never absorbed.
- **One branch, one PR per issue — one per PACKAGE where the mandate packages** — a package
  shares one branch and one PR because its issues share a root cause, while every issue inside
  keeps its own claim, its own counterproof and its own `Closes #N`.
- **Honest report** — parked and failed issues appear with the same prominence as merged ones.

## Related Skills

- **wai-requirements-planning / wai-implementation / wai-testing / wai-pr-review** — the
  per-issue cycle this skill orchestrates; pr-review's **merge-queue mode** does the serial
  integration.
- **wai-learning-gap** — the clean-run, interactive hand-off (step 8) routes here through
  **Flow D**, which owns the ledger gate, the PR ranking, the one-open-gap check and the
  `agent/learn-*` branch.
- **wai** — the router; points here when several issues should be worked as a batch.
- Protocols (in the `wai` skill): `references/issues-protocol.md` (decision points, labels,
  formats), `references/agent-git-protocol.md` (branches, gate, and the canonical **Excluded
  domains** section this skill cites for the serial-lane and autonomy floor — it keeps **no**
  copy of the set), `references/contract-protocol.md` (why contract work is serial).
- This skill's mechanics live in `scripts/`: `backlog-scan.sh` (the proposal),
  `cross-issue-digest.sh` (step 6), `post-merge-verify.sh` (the serial barrier) and
  `autonomous-merge-report.sh` (the audit trail); excluded-domain classification is the shared
  `.claude/skills/wai/scripts/excluded-domains.sh`, obeyed by its exit code — never re-derived
  here. Worked call, from this skill's directory:
  `sh ../wai/scripts/excluded-domains.sh --files <file-with-paths> --diff <file-with-diff>` —
  **both flags take a FILE CONTAINING the path list / the diff**, not the paths or the diff
  themselves; passing paths positionally cost the first field run a round trip
  (`unknown argument 'test/…'`).
