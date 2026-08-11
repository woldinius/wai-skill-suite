---
name: wai-testing
description: >-
  Writes deterministic tests and owns the testing strategy. Mandatory targets are security, billing,
  GDPR and idempotency; tests never call a real model or real billing. Runs after wai-implementation
  on the same branch, so the PR ships with its tests. Use it to write tests, raise coverage, or set
  the strategy: "write tests for X", "add coverage", "is this covered", "cover the billing path",
  "mock the AI models", "make these deterministic". Not for implementing the feature
  (wai-implementation) or wiring the CI gate (wai-cicd).
license: MIT
---

# Testing

Write the tests that make a change trustworthy, and keep the testing strategy current.
The value: `wai-implementation` builds features and only **notes** the test needs;
this skill turns those notes into real, **deterministic** tests — so the PR ships covered and
the merge gate (`wai-cicd`) goes green on something that actually means something.
Anchored to catalog **MAINT-2** (Testability, incl. *deterministic mocks for the
non-deterministic models* and contract tests).

## Platform context

*(The suite's home platform — the worked example these skills grew against, kept concrete on purpose. `wai-init` scopes the quality catalog to what **your** repo actually is; where your product has none of this — no token economy, no mobile clients, no AI orchestration — read the matching rules as not-applicable, not as findings.)*

A **multi-surface product** — cloud backend (AI orchestration + token ledger) with **Web, iOS
and Android** clients joined by a **versioned API contract** (back-compat across the three
clients is sacred), where **AI inference costs money per token** and each client **sells
tokens**. Consequences for tests: the **client↔API contract and back-compat** must be covered
(`API-1`/`API-4`/`CLIENT-3`), the **token economy** is a mandatory target (verification,
idempotent credit/debit, restore — `PAY-*`), and **tests must never call real models or real
billing** — both are flaky/expensive; mock the model behind its abstraction and the stores in
sandbox/fakes.

## Stance

- **Strategy-led.** Follow the dated policy in `docs/architecture/testing-strategy.md` —
  what is mandatory *now*, the test pyramid, coverage targets. If it's missing, propose a lean
  one first (default below). This skill **writes the strategy and the tests**; `wai-cicd`
  turns the gate into **required checks** and enforces it (branch protection / CODEOWNERS).
- **Deterministic above all.** No real model calls, no real billing, no wall-clock/random
  flakiness, no network. Stub the provider abstraction (`AI-1`) with schema-valid canned
  responses and stub billing the same way — store SDKs in sandbox, webhooks as signed fakes;
  freeze time/seed randomness. A flaky test is worse than no test — it erodes the gate it feeds.
- **Proportional, mandatory where it counts.** Build functions end-to-end testable; **no
  speculative unit tests**. But **security, billing, GDPR and idempotency paths are mandatory
  targets** (`SEC-*`, `RES-3`, `GDPR-*`, `AI-3`) — never skipped **where the repo has them**:
  mandatory binds to every such path that exists, it does not invent one for a repo whose
  catalog carries no billing or GDPR surface.
- **Git on the branch, never `main`.** Tests for a change land on its `agent/**` branch and
  update the PR. Merging stays gated (see *Git & PR*).

## Process

1. **Load context** — read `docs/architecture/testing-strategy.md`, the plan
   (`docs/planning/<slug>/`) — especially its **Testing decisions (seams)** section: the seams
   agreed there at planning time are the contract for *where* to test; don't re-derive coverage
   ad hoc when they exist — and `wai-implementation`'s **test-needs** notes, plus the
   catalog (`MAINT-2` and the mandatory-target IDs). Inspect existing tests/fixtures to match
   conventions and reuse harnesses. If the strategy doc is missing, draft a lean one (default
   below) and get a quick ok.

   **Mid-implementation invocation:** when `wai-implementation` calls this skill for a
   **foundational seam** (a contract endpoint, ledger/money logic, an auth boundary that later
   phases build on), scope strictly to that seam — lock it with a few high-value tests on the
   same branch and hand straight back; the full coverage pass still happens after
   implementation completes.

2. **Scope & level** — decide *what* to test and at *which* level, proportional to risk, **per
   surface** (use the surface's native tooling: backend/web TS — Vitest/Jest + Playwright; iOS —
   XCTest/Swift Testing; Android — JUnit + Compose/Espresso):
   - **Unit** — pure logic, parsers, guards, money/quota/ledger math.
   - **Integration** — the contract surfaces (API endpoints ↔ DB), with a real ephemeral DB.
   - **Contract** — both sides per `references/contract-protocol.md` (in the `wai` skill): **provider** (backend
     honours the published contract) and **consumer** (each client against its generated client)
     (`API-4`).
   - **e2e** — critical user flows incl. the **purchase flow** in store sandbox (`PAY-*`).
   List the **mandatory targets** the change touches (security/token/billing/GDPR/idempotency).

3. **Make non-determinism testable** — stub model calls behind the provider abstraction with
   **schema-valid canned responses**; add cases for **bad/invalid model output** so output
   validation (`AI-3`) and **fallback** (`AI-5`) are exercised; seed fixtures; use an ephemeral
   database + applied migrations for integration. Write the fakes the tests need (the CI
   infrastructure that *runs* them — test DB service, required jobs — is `wai-cicd`'s).

   **When you introduce a heavy test tier, cap its parallelism in the same PR.** A tier whose
   *per-file* setup is expensive — a real database booted per file, a container, a WASM runtime,
   migrations applied — is fine at three files and starts timing out around ten, when the runner
   boots them all at once. Check the runner's worker cap **when you add the tier**, not after the
   first flake, and fix it in the runner config — **never** by raising the timeout, which only
   hides the contention until the CI box is busier and then returns as a flake in an unrelated PR.
   Shapes and pseudocode: `references/test-patterns.md`.

4. **Write the tests** — following repo conventions; deterministic and fast; cover the
   mandatory targets first. Prefer a few high-value e2e/integration tests over many brittle
   unit tests. Assert behavior and contracts, not implementation detail.

5. **Run locally & confirm green** — run the new tests (and the suite they belong to). If a
   test needs to become a **required merge check** that isn't wired yet, note it for
   `wai-cicd` (see hand-off) — don't wire branch protection here.

   **A 🧩 `LEARN #` marker is not a bug — never "fix" it.** If red traces back to a line marked
   `LEARN #`, that is another human's open learning exercise (`wai-learning-gap`), deliberately left
   red in the working tree and never committed. Do **not** restore it, do not work around it, and
   do not report the phase as failed: stop, say a learning gap is open, and let the human close it
   (or ask `wai-learning-gap` to resolve it) before testing continues. Silently solving it steals the
   exercise and the human never learns the concept.

6. **Update the strategy** — if the policy evolved (new mandatory target, a level promoted to
   the gate), update `docs/architecture/testing-strategy.md` as a visible change.

7. **Commit on the branch, update the PR, hand off** — verify the branch (`git branch
   --show-current`, never `main`), commit the tests (and any fakes/fixtures) atomically; update
   the PR's test plan. **File coverage gaps you can't close now as GitHub issues** (a mandatory
   target that needs infrastructure that doesn't exist yet, a flaky area that needs a harness) —
   format, labels and `**Skill:**` source per `issues-protocol.md` in the `wai` skill. That
   is the landing rule (§*Where a finding lands*): a gap you neither closed nor deliberately
   accepted is **filed**, not mentioned in passing — an uncovered mandatory target that lives only
   in a chat log is an uncovered mandatory target nobody will remember. Close with **▶ Recommended next**.

## Mandatory test targets (never skipped)

Mark these clearly so they survive into later test phases:

- **Security** (`SEC-*`) — authz on protected/contract endpoints, input validation, no secret
  in logs, prompt-injection on user-supplied content.
- **Token economy** (`PAY-*`/`RES-3`) — purchase verified server-side (`PAY-2`); a retry or a
  duplicate webhook credits exactly once (`PAY-3`); consumption is atomic and can't double-spend
  (`PAY-4`); refund/revocation claws back the ledger (`PAY-6`); restore works (`PAY-5`). Never
  call real billing — use the store sandbox / signed fake webhooks.
- **AI output handling** (`AI-3`/`AI-5`) — invalid model output is rejected/retried; fallback fires.
- **GDPR** (`GDPR-*`) — deletion/retention actually removes the data **from every store that can
  hold it**, not just from the primary rows. The bug is never "delete didn't run"; it is "delete
  ran and missed the blob bucket / the payload archive / the search index / the cache". So the
  test **enumerates the stores** and asserts each is empty — and a newly added store that isn't
  in the enumeration must break the build, not survive until the next audit. Also: no plaintext
  PII in logs. Pattern: `references/test-patterns.md` §*Erasure*.

## Testing strategy doc (default if missing)

A lean `docs/architecture/testing-strategy.md`: build functions end-to-end testable; the
**gate set** (which checks block a merge — defined here, enforced by `wai-cicd`); the
**mandatory targets** above; deterministic-model-mock rule; a note on the current project phase
(so the policy can tighten as the product matures). Keep it dated and short.

## Git & PR

**The authority is `references/agent-git-protocol.md` (in the `wai` skill).** Specific to
*this* skill: tests land on the **same** `agent/<handle>/<type>-<slug>` branch the change is on,
and update **its** PR — reuse what planning pushed and implementation opened; never a branch of
your own. **Never commit, push or merge to `main`.** No git or no `gh` → propose the commit and
say so.
## Output format

Use this structure:

```
## Tests: [short description of the change/area]

**Levels:** [unit · integration · e2e/contract — what was added/strengthened]
**Mandatory targets covered:** [SEC-… / RES-3 / GDPR-… / AI-3 — each with the case]
**Determinism:** [how model calls / time / randomness were made deterministic]
**Local result:** [green — N tests; or what remains]

### Gate impact
- [Any test that should become a required merge check → hand to wai-cicd]

### ▶ Recommended next
- [Typically wai-pr-review on the PR. If a new required check is needed →
  wai-cicd to wire/enforce it. If coverage exposed a missing behavior →
  wai-implementation.]
```

Omit sections that don't apply.

## Principles

- **Deterministic or it doesn't ship** — no real models, no clock/random/network flakiness.
- **Cover the irreversible** — security, billing, GDPR, idempotency: mandatory for every such
  path the repo has, with no exceptions for the ones it has.
- **Proportional** — value per test; a few strong e2e/contract tests beat many brittle units.
- **Testing writes, cicd enforces** — this skill defines the policy and the tests; the gate and
  branch protection are `wai-cicd`'s.
- **Branch, never `main`** — tests ride the requirement PR; merging stays gated.

## Related Skills

This skill is the **test** companion to implement → review:
- **wai-implementation** — builds the feature and hands over its **test-needs** notes;
  run this skill right after, on the same branch.
- **wai-cicd** — owns the **merge gate**: turns the mandatory tests into required checks,
  provides the CI test infrastructure (ephemeral DB, integration/e2e jobs), and enforces
  branch protection / CODEOWNERS.
- **wai-pr-review** — checks that the change is adequately tested before it merges.
- **wai-init** — writes the initial `docs/architecture/testing-strategy.md` and sets its
  **tier** (the `**Tier:**` field in the catalog header). When you update the strategy, stay at
  that tier — don't quietly grow a compact strategy into a full one; if it genuinely needs more,
  say so and let the human raise the tier via init.
- **wai** — the suite router/overview, if you are unsure what to run next.
- Own reference: `references/test-patterns.md` — reusable shapes for the mandatory targets
  (erasure across all stores, real-infrastructure vs. mocks, heavy-tier parallelism, concurrent
  idempotency/replay).
- Shared source of truth: `docs/architecture/quality-attributes.md` (`MAINT-2`); policy:
  `docs/architecture/testing-strategy.md`; contract rules: `references/contract-protocol.md` (in the `wai` skill).
