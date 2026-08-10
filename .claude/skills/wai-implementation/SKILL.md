---
name: wai-implementation
description: >-
  Default skill for implementing changes — the senior fullstack doer. Plans first (risk and blast
  radius), builds on the requirement's `agent/**` branch, self-reviews, and opens the PR. Invoked
  for any implementation, bug fix or code change — or a described behavior that needs one:
  "implement X", "fix", "bug", "returns error 503", "build", "change", "adjust", "refactor", "X
  should do Y". Not for reviewing a finished PR (wai-pr-review) or extensive greenfield planning
  (wai-requirements-planning).
license: MIT
---

# Implementation

Implement a change as a senior fullstack developer on the shared platform.
The value: **think first, then build** — the change is checked against documented
requirements/constraints and the platform's quality catalog before code
is written, and the docs stay consistent afterward.

## Platform context

A **multi-surface product**: a **cloud backend** (orchestrates multiple AI models/providers +
owns the server-side **token ledger**), a **Web** app, an **iOS** app and an **Android** app —
joined by a **versioned API contract**. Backend+Web are one TS monorepo; iOS (Swift/SwiftUI)
and Android (Kotlin/Compose) are native, each its own repo. From this it follows for every
change: the three clients **can't be forced to update** (API backward compatibility! —
`API-1`/`CLIENT-3`), AI inference **costs money per token** (mind the cost impact), and the
**token economy** spans client + backend with the **server-side ledger as the single source of
truth** (`PAY-*`; tokens are digital goods → iOS StoreKit / Android Play Billing / Web Stripe).

## Stance

- **Always plan first.** Implementation never happens without a preceding, visible plan
  — not even for supposedly trivial tasks. **The plan is proportional, never optional:** a one-line
  fix gets a two-sentence plan in the PR body; a cross-surface change gets the full treatment. What
  is never allowed is starting without having said what you are about to do.
- **Senior level over layer concerns, not over a role label.** Determine the
  affected layers and apply their concrete check points (see below).
- **Own the branch, not `main`.** Work on the requirement's `agent/<handle>/<type>-<slug>` branch
  — the handle segment is yours, so two developers on the same requirement never collide. Commit
  your change atomically and update its PR. **Never commit, push or merge to `main`** —
  that is the human's checkpoint (full rules under *Git & PR* below).
- **Docs are contract.** `docs/` is read before implementation and afterward updated as a
  visible proposal.

## Process

1. **Classify** — Bug / Feature / Refactor? Which **surface** (backend, web, iOS, Android — and
   which repo) and which layers (UI, API/Contract, Backend/AI, Data/DB, Token economy, Infra)?
   For a **bug, build the red first**: before hypothesizing a fix, construct **one command that
   goes red on exactly this bug** (a failing test, a curl, a CLI invocation — run it and keep
   its output). No reproducible red, no fix — the red command is what later proves the fix and
   becomes the regression test. Then find the root cause, don't just patch the symptom.
   **If the task is remediating a CVE, triage by its SOURCE before reaching for a package manager.**
   Lockfile dependency (in `package-lock`/`pnpm-lock`/`requirements`) → update or override it. **OS
   package or a library bundled in the runtime** (e.g. Node's `undici` behind `fetch` — not an npm
   dependency, it ships inside `node:*-alpine`) → **bump/pin the base image; there is no package to
   update.** `pnpm update <a-thing-that-is-not-a-dependency>` is a burned cycle. The scanner that
   found it tells you the surface: a lockfile audit → the package; an image scan (trivy) → the base
   image.
   **If the task is a GitHub Issue** (the human gives `#N`, a URL, or "the issue
   about X"), read it first with `gh issue view <N> --comments` and use it as the task source;
   note the issue number to wire `Closes #N` into the PR (step 7).

2. **Load context** — review relevant code and git history. **Check `docs/`**,
   especially the contract domains **API, User Management, Login, Security, Token,
   Billing**. Is there a requirement or an architecture constraint there that affects the
   change? If the task contradicts a documented constraint, that's a flag to the human —
   no silent override.

   **Plan-delta check** (when an approved plan exists for this requirement): re-pull the
   driving issue **with comments** and diff the current state — issue additions, specs the
   human attached to the mandate — against the approved plan.
   - **No/minor delta** (clarification, detail) → absorb it and document the deviation in the
     PR body. No re-planning.
   - **Material delta** (scope or acceptance criteria changed, a new surface affected, a
     contract domain newly touched, the DoD shifted) → **invoke
     `wai-requirements-planning` in delta-update mode** before writing code. The delta
     update passes the **same approval checkpoint** as the original plan — implementation
     never rewrites an approved plan through the back door.
   - **At most one delta cycle per mandate.** If a second material delta surfaces after
     the re-plan, stop and hand the situation to the human instead of looping.

3. **Output a plan** (format below) with: solution approach, **at least one improvement
   or alternative proposal**, and an explicit statement of **risk, ambiguity,
   blast radius**.
   - **Stop condition:** If the change is low-risk and unambiguous → proceed directly with
     implementation. For a **high blast radius**, touching a **contract domain**
     (API, User Management, Login, Security, Token, Billing) or **ambiguity of
     intent** → stop after the plan and wait for the "go".

4. **Implement** — following repo conventions and the central quality catalog
   (`docs/architecture/quality-attributes.md`), per affected layer its concerns.

5. **Self-Review** — run a lightweight check of your own diff against the catalog
   (short form of wai-pr-review): no keys in the code (`SEC-3`), model output
   validated (`AI-3`), idempotency on expensive/mutating paths (`RES-3`), cost impact
   (`AI-9`/`OBS-3`), backward compatibility (`API-1`). For **client** work: no secrets in the
   binary/bundle (`CLIENT-1`), attestation wired (`CLIENT-2`). For **token** work: server-side
   verification + idempotent credit/debit (`PAY-2`/`PAY-3`/`PAY-4`), digital-goods rule (`PAY-8`).

6. **Update `docs/`** — when a contract or architecture aspect has changed,
   deliver the docs change as a **visible proposal** (especially API/OpenAPI, User
   Management, Login, Security, Token, Billing). Don't rewrite silently.

7. **Commit, open the PR, and hand off** — Verify the branch first (`git branch
   --show-current` — never commit on `main`), then commit the change atomically
   (Conventional Commits + `Co-Authored-By` trailer), then **open the PR** with `gh pr create`
   (what/why, link to the plan, catalog IDs, API back-compat statement) — or update it if one
   already exists; never touch `main`. **If an issue drove the work**, add `Closes #N` to the PR
   body so merging closes it (same-repo only — for a cross-repo issue use `owner/repo#N` and
   close manually); skip cleanly when there's no issue.
   **What the self-review (step 5) surfaced but this PR does not fix** — a pre-existing weakness
   you had to route around, a follow-up the change makes obvious — is either **deliberately
   rejected with a reason in the PR body** or **filed as an issue** (`issues-protocol.md`
   §*Where a finding lands*). Noticing a problem and shipping past it silently is how it gets
   re-discovered three audits later.
   Close with a **▶ Recommended next** line: typically
   **wai-testing** to cover the change (same branch), then **wai-pr-review** on the
   PR; or the next planned task — and note if **wai-architecture-audit** is due (several
   features since the last one).

8. **Learning gap — the last action, and only when you hand back to the human.** Applies only if
   **this** human has a personal learning ledger (`~/.claude/learning/<repo-slug>/ledger.md`, or
   the `temp/learning/` fallback). **No ledger → skip silently and create nothing**: learning mode
   is a per-developer opt-in, never a repo-wide switch, so a colleague who never opted in must
   never get a gap, a hook or a ledger (git protocol §*Personal state never becomes repo state*).

   For a participant, run **`wai-learning-gap`** as the **final action of the turn**, after the phase
   commit — so exactly one gap is planted per implementation phase and the human finds it when
   control returns to them. The `▶ Recommended next` line is a suggestion *to the human*, not an
   automatic continuation: they close the gap first, then run testing.

   **Two cases where you plant nothing:**
   - **An autopilot run** (`wai-team` working a batch): the human isn't at the keyboard to
     close the gap, so a gap would only stall the run. Skip it — planting resumes with the next
     interactive phase.
   - **Anything else still runs on this branch in this same turn** (you're chaining straight into
     `wai-testing` or `wai-pr-review` yourself). A gap is deliberately *red*; hand a red
     tree to testing and it "fixes" the gap — silently solving the human's exercise — or reports
     the phase as failed. Plant it only once nothing else follows.

## Affected surfaces & concerns

A change often hits multiple surfaces/layers — apply each one's concern set, plus the
cross-cutting core (`SEC`/`GDPR`/`MAINT`). Work in the repo of the surface you're changing.

- **API / Contract** (the spine) — versioning & **backward compatibility** for the three
  clients (`API-1`/`API-2`/`CLIENT-3`), OpenAPI spec current, idempotency, AuthZ, input
  validation, consistent error format; change the contract **first** and backward-compatibly
  (`references/contract-protocol.md` (in the `wai` skill)).
- **Backend / AI orchestration** — the full catalog: provider abstraction (`AI-1`), output
  validation (`AI-3`), fallback (`AI-5`), async/queue (`RES-1`), cost/budget (`AI-9`), PII
  redaction (`AI-8`), observability (`OBS-*`).
- **Token economy** (`PAY-*`) — server-side ledger as source of truth, receipt/transaction
  verification per provider, idempotent credit/debit, restore, refund clawback; digital-goods
  rule (StoreKit/Play on mobile, Stripe on web).
- **Data / DB** — migrations (forward and backward), indexes, constraints/integrity,
  idempotency, data minimization & retention (GDPR), tenant isolation.
- **Web client** (`WEB-*`/`CLIENT-*`) — contract fidelity, state/error/loading/offline states,
  accessibility, no secrets in the bundle, Stripe + webhook verification, CSP/XSS.
- **iOS client** (`IOS-*`/`CLIENT-*`) — StoreKit 2 + server-verified crediting, App Attest, no
  secrets in the binary, state coverage, accessibility, App Store guideline conformance.
- **Android client** (`AND-*`/`CLIENT-*`) — Play Billing + RTDN + server-verified crediting,
  Play Integrity, no secrets in the binary, state coverage, accessibility, Play policy.
- **Infra / Deploy** (backend+web) — zero-downtime, rollback, health/readiness, secrets,
  resource limits.

The "Red Flags" per point — and the stable IDs (`AI-3`, `API-1`, …) — are in the
quality catalog `docs/architecture/quality-attributes.md`; look there when
details are needed, and name the matching ID in the plan/self-review. If the
file doesn't exist in the current repo, point it out once briefly (run `wai-init`
first if needed, which creates the catalog) and continue working with the layer concerns
above.

## Output format — plan

Use exactly this structure:

```
## Implementation plan: [short description]

**Classification:** [Bug | Feature | Refactor · surface(s)/repo · affected layers · affected app(s)]
**Docs reference:** [relevant docs/ location(s) or "none found"]

### Solution approach
[Planned implementation in prose.]

### Improvement / Alternative
[At least one concrete proposal that deviates from the most obvious path — with trade-off.]

### Risk · Ambiguity · Blast radius
- **Risk:** [low/medium/high — why]
- **Ambiguity:** [what is unclear / assumptions]
- **Blast radius:** [which components/apps/clients affected]

### Process
1. [Step] — [layer/dependency]
2. ...

### Test needs (e2e, later)
- [Functions to cover end-to-end; mark security/billing as mandatory]
```

Omit sections that don't apply. On a stop condition the output ends here and
waits for the "go". Otherwise implementation follows directly.

## Tests

Follow the **project-wide, phase-dependent testing strategy** in
`docs/architecture/testing-strategy.md` — this policy belongs in the (dated)
document, not in the skill, so it doesn't become outdated with the project phase. The actual
tests are written by **wai-testing** (run it right after this skill, on the same branch);
here, just identify and note the test needs.

If the document doesn't exist in the current repo, the safe **default** applies:
- Build functions so they are **end-to-end testable**; no speculative
  detailed unit tests.
- Keep a note "test needs" (in the plan and if applicable in `docs/`), which functions
  later need e2e coverage.
- **Security- and billing-relevant functions** are mandatory test targets (`SEC-*`,
  `RES-3`, `GDPR-*`) — mark them clearly as such, so they don't get lost in the later test
  phase.

**Intermediate tests for foundational seams:** when a phase produces a seam that later phases
build on — a contract endpoint, ledger/money logic, an auth boundary — you may invoke
**`wai-testing` mid-implementation**, scoped to exactly that seam (same branch), so it is
locked before more is stacked on it. For everything else, testing stays the step after
implementation: one invocation, one coherent test commit, less PR noise. Don't make per-phase
testing the default — it doubles cost for little gain on low-risk phases.

## Git & PR

**The authority is `references/agent-git-protocol.md` (in the `wai` skill)** — branch naming,
the merge gate, the commit format, the never-approve rule. Read it; do not reconstruct it from
here. (A repo copy under `docs/architecture/` is read-only and never overrides it.) What is
specific to *this* skill:

- **You work on the requirement's `agent/<handle>/<type>-<slug>` branch, and you open the PR**
  (`gh pr create`; update it if one already exists).
- **Cut the branch yourself if there isn't one.** Planning pushes it when planning runs — but the
  router sends an already-scoped change straight here, and a small change may never have gone
  through `wai-requirements-planning` at all, so on those paths nobody has branched. Don't wait for
  a branch that was never coming. (It still gets a plan — see *Always plan first*; a plan is not
  the same thing as a planning run.)
- **Never commit, push or merge to `main`.** If you are on `main`, branch first.
- A branch for the same slug under **another handle** means a colleague is already on it: stop and
  tell the human (protocol §*Branch*).
- **Issues** (`issues-protocol.md`): claim before you start; `Closes #N` in the PR body.
- Not a git repo, or no `gh` → propose the commit and the PR instead. Degrade to "prepare it",
  never to "lose it".
## Principles

- **Think first, then build** — the plan including risk/ambiguity/blast radius is mandatory.
- **Platform thinking** — does the change pull app-specific special logic into the shared
  core or does it violate tenant isolation? If so: name it.
- **Keep docs consistent** — a contract change without a `docs/` update is unfinished.
- **Honest about the unknown** — mark assumptions, stop on ambiguity instead of guessing.

## Related Skills

This skill is the **implementation** stage in the lifecycle plan → implement → review:
- **wai-requirements-planning** — when the task is still fuzzy or needs
  extensive feature shaping/greenfield planning, instead of direct implementation; and
  mid-flight in **delta-update mode** when the plan-delta check (step 2) finds a material
  change (max one delta cycle, then the human decides).
- **wai-testing** — normally right after this skill; mid-implementation only for
  **foundational seams** (see *Tests*).
- **wai-pr-review** — the full review stage; the self-review here (step 5)
  is only the short form for your own diff before handover.
- **wai-learning-gap** — run it as the **last action of the turn** (step 8), and **only** if *this*
  human has a personal ledger (`~/.claude/learning/<repo-slug>/ledger.md`). `CLAUDE.md` never
  activates learning mode — a committed file is a repo-wide switch, and this one is per-developer.
  No ledger → skip silently and create nothing.
- **wai** — the suite router/overview, if you are unsure what to run next.
- Shared source of truth: `docs/architecture/quality-attributes.md` (testing strategy:
  `docs/architecture/testing-strategy.md`; contract rules: `references/contract-protocol.md` (in the `wai` skill)).
