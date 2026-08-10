---
name: wai
description: >-
  Front door and router for the wAI skill suite. Use it to orchestrate — when you are unsure which
  skill to start with, want a lifecycle overview, or a recommendation on what to run next: "which
  skill do I use", "where do I start", "what's next", "give me an overview", "help me orchestrate".
  It only recommends the right skill and shows the hand-offs; it does not plan, implement or review
  itself — the human stays the orchestrator.
license: MIT
---

# wai (suite router)

The front door to the wAI skill suite. You — the human — stay the **orchestrator and
checkpoint**: you decide what runs and you review between stages. This skill's job is to
make that easy: given where you are or what you want, it **recommends the right skill(s)**
to run next and shows how the suite hands off. It routes; it does not plan, implement or
review itself.

## Operating model

- **Human-orchestrated, skill-guided.** You invoke each stage. Every lifecycle skill ends
  its run with a **▶ Recommended next** block — a situational hand-off based on what it
  found (which skill, on what, why, and any decision you must make first). This router gives
  you the same recommendation as a *starting* point.
- **Skills own the branch; `main` is gated.** Planning opens the `agent/<handle>/…` branch (local
  + remote — the handle segment keeps two developers off each other's branch), implementation
  commits and opens the PR. `wai-pr-review` then **auto-merges**
  a clean, non-contract-domain PR with green checks to `main` (and deletes the branch, ready
  for the next requirement); any contract-domain (API, Auth/Login, Token, Billing, Security)
  or destructive-migration change is **left for your merge**. In a **`team`** repo (the
  `**Repo mode:**` line in the quality catalog) the agent never merges by itself: it arms
  GitHub auto-merge, and the PR waits for **another human's approval** — same tempo, but nothing
  lands unseen. **Blocker/Major findings are
  your decision point** — presented with a recommendation, handled differently only on your
  explicit mandate ("collect as issues", "fix directly"). Merging ships a release. Full rules:
  `references/agent-git-protocol.md` — the only authority; a repo copy under `docs/architecture/`
  is read-only and never overrides it. Issue handling: `references/issues-protocol.md`.
- **The contract is the spine.** The backend and the three clients live in separate repos but
  share one **versioned API contract**; a cross-surface feature changes it **first and
  backward-compatibly**, then the clients adopt. Full rules: `references/contract-protocol.md`.
- **Setup skills stay proposal-only.** `wai-init` and `wai-cicd` create high-stakes
  artifacts (quality catalog, CI, secrets, deploy) — they propose; you commit those.

## The lifecycle map

```
SETUP (one-time, supervised, proposal-only · per repo)
  wai-init            → creates docs/architecture/quality-attributes.md + testing-strategy.md
                             (surface-scoped, stable IDs, sized to the project; repo mode + tier + language in the header)
  wai-cicd            → backend+web: CI/CD + Docker/Compose + the merge gate (required checks, branch protection, CODEOWNERS, PR template)
  wai-mobile-release  → iOS/Android: build, signing, TestFlight/Play tracks + the mobile merge gate

PER REQUIREMENT (you orchestrate; skills work on one agent/<handle>/<type>-<slug> branch + PR)
  wai-requirements-planning  → interviews you (or grills you: references/grilling-protocol.md);
                                    on approval opens the branch (local + remote)
  wai-implementation         → implements on that branch, commits, opens the PR
                                    (+ plants a learning gap if YOU opted into learning mode)
  wai-testing                → writes deterministic tests for the change (same branch)
  wai-pr-review              → reviews the PR against the catalog → merge to main

BATCH (mandated — several issues at once)
  wai-team                   → works an issue set through the per-requirement cycle,
                                    one branch+PR per issue, integrated via the merge queue;
                                    Blocker/Major & contract merges collect in your decision list

PERIODIC (after a few features/refactors, or on security triggers)
  wai-architecture-audit     → whole-codebase STRUCTURAL health: decoupling/modularity, drift,
                                    dead code + semantic redundancy/inconsistency/dead-ends (on a branch)
  wai-security-audit         → whole-codebase ADVERSARIAL sweep: authZ/IDOR, secrets, injection,
                                    SSRF, CVEs, token fraud — attack surface + posture trend (on a branch)
```

## How to route

1. **Read the situation.** What does the human want, and where are they in the lifecycle?
   **Which surface(s) does it touch — backend, web, iOS, Android?** In the hybrid topology each
   client is its own repo with its own surface-scoped catalog, while backend+web share the TS
   monorepo; route to the skill *in the right repo*. If a repo is involved, glance at it: does
   `docs/architecture/quality-attributes.md` exist (else → setup first)? Is there an open
   `agent/**` branch / PR for this requirement already?
2. **Recommend a starting skill** using the decision guide below — name the skill, what to
   run it on, and why. If two paths are reasonable, give the primary and the alternative.
3. **Hand off.** Tell the human the exact next step; do **not** start doing the stage's work
   here. From then on, each skill's own **▶ Recommended next** block carries the chain.

## Decision guide

- **Repo not set up yet** (no `docs/architecture/quality-attributes.md`) → `wai-init`
  first, then `wai-cicd` if there's no pipeline/branch protection.
- **A new feature/idea/requirement, even vague** → `wai-requirements-planning`. Hand it an
  issue (`plan #42`), a set that forms **one** requirement (`#42 #43 #44`), or just a sentence —
  plus directives like `grill me` or `backend only`. It interviews you, then plans and pushes the
  branch with the plan on it. The **PR comes later**, from `wai-implementation`, once there is
  an actual diff to review.
- **A backlog of *independent* issues**, each needing its own full lifecycle → `wai-team`.
  (One requirement split across several issues is still **planning's** job, not the team's.)
- **A clear, already-scoped change / bug / refactor** → `wai-implementation` directly
  (it still plans first and stops to ask on risky/contract-domain changes).
- **Tests needed for a change, or "is this covered"** → `wai-testing` (typically right
  after implementation, on the same branch).
- **An existing PR/branch/diff to evaluate** → `wai-pr-review`.
- **Several issues to work as a batch** ("work the backlog", "process #12–#18") →
  `wai-team` — needs your mandate (issue set, decision handling, budget); a single issue
  goes through the lifecycle skills directly.
- **"Is the app still healthy / decoupled / any drift, dead code or redundancy?"** →
  `wai-architecture-audit` (structure).
- **"Are we secure / any vulnerabilities / check the attack surface / dependency CVEs?"** →
  `wai-security-audit` (adversarial). Run it periodically and on triggers (new
  auth/upload/outbound-fetch code, dependency bumps, before a release).
- **Setting up CI/CD or deployment for backend+web, or that merge gate / branch protection** →
  `wai-cicd`.
- **Setting up the iOS/Android build, signing or store release (TestFlight/Play)** →
  `wai-mobile-release`.
- **The quality catalog is missing or the stack changed fundamentally** → `wai-init`.
- **Did a suite update leave this repo out of step — is the gate actually configured, did anything
  silently switch off?** → run `sh .claude/skills/wai/scripts/doctor.sh`. `install.sh` runs it
  automatically after every update; run it anytime to check for **drift** (a missing
  `merge-gate.conf` → the gate returns UNKNOWN on every PR; a legacy learning ledger). Obey the
  exit code: `exit 0` = no drift that disables a feature (soft advisories may still print) ·
  `exit 1` = **DRIFT**, a fact about the *repo* — a feature is silently off, so repair it before
  you trust the gate · `exit 2` = **UNKNOWN**, a fact about the *doctor* — it could not run a check
  at all, so read nothing as clean. Both at once exits 1, and both summary lines print. It reports
  presence now; staleness of an already-generated artifact (an old `ci.yml`) still needs a
  `wai-cicd` re-run.
- **Did a script and the prompt that invokes it drift apart** — after changing a script's exit
  codes, renaming a skill, or before a release? → run
  `sh .claude/skills/wai/scripts/contract-lint.sh`. It reads both sides of the joint and fails
  on three mechanical facts: a script no prompt names, a documented path that does not resolve from
  the repo root, and an exit code a script returns that no prompt naming it documents. `exit 0` =
  the two sides still describe each other · `exit 1` = a check failed; every finding names its file
  and its repair — **fix the prompt, never the check** · `exit 2` = the tree could not be read, so
  nothing was verified (fail closed: "I could not look" is not "it is fine"). **What it does not
  check:** whether a documented invocation's *arguments* are accepted — that needs running the
  script, and this one only reads. Green means every documented command points at a file that
  exists and returns codes the prompt has heard of; it does *not* mean every command works.

## Output format

Keep it short — this is a signpost, not a deliverable:

```
## Where you are
[1–2 sentences: the situation and lifecycle position.]

## ▶ Start with
**[skill-name]** — on [target] — because [reason].
[If relevant: alternative path, or a setup prerequisite to run first.]

## Then, typically
[The likely chain afterward, e.g. planning → implementation → pr-review → merge to main
(auto for a clean, non-contract-domain PR; left for your merge if risky). The invoked skill's
own ▶ Recommended next will confirm/adjust this as it learns more.]
```

## Principles

- **Artefacts check the work, not the question.** The gate, the lints, the tests verify whether the
  *work* is right. **None can verify whether the *question* was right** — a finding can pass every
  check and still answer the wrong thing, and a review that ran *after* the merge, or a metric whose
  tool never ran, passes exactly the same. So you are not the approver of a green diff; the checks
  already approved it. You are the **owner of the *why*** — the one and only check on whether the
  right thing was asked. A suite that treats you as a rubber stamp on green output wastes the one
  thing it cannot replace. (This is why the two errors a full field run's artefacts *missed* were
  both caught by the human: an invented denominator, and a rule the agent talked itself out of.)
- **Route, don't do.** Hand off to the specialist skill; never absorb its job here.
- **You orchestrate, skills guide.** The recommendation informs your decision — it does not
  replace it.
- **One branch, one PR per requirement.** Point planning/implementation/review at the same
  `agent/**` branch so the work reads as one reviewable PR you merge.
- **`main` is gated, not free.** Only `wai-pr-review` merges, and only a clean,
  non-contract-domain PR with green checks; risky changes wait for your merge. That gate is the
  point of the whole flow.

## Related Skills

All skills and their hand-offs are in the lifecycle map and decision guide above. Beyond the
lifecycle: **wai-team** (mandated batch orchestrator) and **wai-learning-gap** (personal
cloze-coding tutor — **per developer, opt-in**: implementation triggers it only for a human who
has their own learning ledger, and does nothing for everyone else).

Shared references: catalog `docs/architecture/quality-attributes.md`; git
`references/agent-git-protocol.md`; contract `references/contract-protocol.md`; issues
`references/issues-protocol.md`; grilling `references/grilling-protocol.md`.
