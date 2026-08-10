# Testing Strategy

> **Status:** reference copy · **Owner:** Platform Architecture · **As of:** 2026-07-12 · **Phase:** —
>
> This is the **shape** `wai-init` writes into a product repo and `wai-testing` reads on
> every run — kept here as the suite's master copy, next to the quality catalog. It is *not* the
> testing strategy of any particular product: a real one names its project's phase, its gate set
> and its mandatory targets, and is re-dated whenever the policy changes.
>
> The policy is **phase-dependent by design**, which is exactly why it lives in this document and
> not inside a skill. When the phase changes, **this document** changes — the skills do not.

## How to use this file

`wai-init` writes `docs/architecture/testing-strategy.md` into the target repo at the same
tier as the quality catalog, filling the sections below from the project's actual phase and stack.
`wai-testing` then follows it, and updates it when the policy evolves (a new mandatory
target, a level promoted into the merge gate). Everything below is the skeleton plus the parts
that are **not** negotiable.

## Levels and what each is for

| Level | Purpose | Runs |
|---|---|---|
| Unit | pure logic, branch coverage of the tricky bits | every push |
| Integration | the seams — real DB/queue/storage, real SQL semantics | every push |
| Contract | the API surface the clients depend on (`API-*`/`CLIENT-3`) | every push |
| End-to-end | the user-visible happy paths and the money paths | per the project's phase |

A project in an early phase may deliberately keep the unit level thin and lean on integration +
contract instead — that is a legitimate strategy, and it is recorded **here** with its reasoning
and its exit condition, not improvised per PR.

## The gate set (what blocks a merge)

Name the checks that must be green before a PR can merge. `wai-cicd` wires exactly this set
as GitHub required checks, and `wai-pr-review` treats it as the "green checks" condition.
A check that is not in this list does not gate; a check in this list is never made advisory to
get a PR through.

## Mandatory targets (never skipped, in any phase)

These are the four areas where an untested path is a liability rather than a gap. They hold
regardless of the project's phase — an early-stage product may skip speculative unit tests, but
it does not skip these:

- **Security** (`SEC-*`) — authN/authZ on every protected route, ownership checks (no IDOR),
  input validation at the boundary.
- **Billing / token economy** (`PAY-*`) — server-side purchase verification, idempotent
  credit/debit, replayed webhook credits exactly once, refund claws back.
- **GDPR** (`GDPR-*`) — deletion actually removes the data **across every store that can hold it**
  (see the erasure pattern in `wai-testing`'s `references/test-patterns.md`), no plaintext
  PII in logs.
- **Idempotency** (`RES-3`) — a retried mutation does not double-apply.

## Determinism (not negotiable)

- **No real model calls, no real billing.** Models are mocked deterministically; store/payment
  webhooks are signed fakes against a sandbox. A test that spends money or tokens is not a test.
- **No wall-clock, no unseeded randomness.** Freeze time, seed the RNG.
- **Bound the parallelism of heavy tiers.** A test tier with an expensive per-file setup (a real
  database per file, a container, a WASM runtime) will start timing out once enough files use it —
  and the fix belongs in the runner's worker cap, never in raised timeouts. See the same section
  of `wai-testing`.
- A flaky test is worse than no test: it erodes the very gate it is supposed to feed.

## Current phase

*(A real strategy states the project's phase here, what it implies for the levels above, and the
exit condition that ends it — e.g. "until v1 is manually accepted, no speculative unit tests;
after that, a binding e2e suite, contract tests and prompt-regression tests." Keep it dated.)*
