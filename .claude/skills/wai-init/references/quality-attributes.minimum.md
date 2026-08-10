# Quality Catalog — minimum variant (Seed)

> ⚙️ **This is a seed/template, NOT the live catalog — and a GENERATED file.** It is derived
> from the master `quality-attributes.baseline.md` by `catalog-variant.sh`; edit the master
> and regenerate, never this file (tests/run.sh re-derives it and fails on drift). `wai-init`
> copies the variant that fits the repo to `docs/architecture/quality-attributes.md` and adapts
> it there. The other skills read exclusively the live file under `docs/architecture/`.
>
> **Section numbers and IDs match the platform master.** A gap in the numbering means "not in
> this variant", never "missing" — and an ID cited here means the same dimension in every
> variant. Prose may still reference an ID that only the platform master carries; such a
> reference points at the master, not at a hole in this file.
>
> Variant scope: the core of software engineering — clean architecture and
> maintainability (`MAINT-*`), security (`SEC-*`), privacy (`GDPR-*`), and
> correctness under repetition (`RES-3`). Everything surface- or platform-specific
> lives in the web and platform variants.

> **Status:** binding (after tailoring) · **Owner:** Platform Architecture · **As of:** 2026-07-11 · **Version:** 3.0
>
> **Repo mode:** solo · **Tier:** full · **Docs language:** en
> <!-- Set by wai-init.
> Repo mode: solo | team. `team` = more than one human commits here: the agent never merges
>   directly (it arms `gh pr merge --auto`; the PR waits for one approving review from another
>   human), and CODEOWNERS lists the team's contract owners. A MISSING LINE MEANS `solo`.
>   See `agent-git-protocol.md` §Identity & repo mode.
> Tier: minimal | compact | standard | full — how much prose each ID carries. Nine skills read this
>   file at runtime, so the tier is the suite's main token cost.
> Docs language: prose language of this file. IDs (`SEC-3`) and section names stay English and
>   stable in every language — the skills cite them. -->
>
> Single Source of Truth (once copied by `wai-init` to `docs/architecture/`).
> The skills `wai-pr-review`, `wai-requirements-planning` and
> `wai-implementation` reference the live file. Each dimension carries a
> **stable ID** (e.g. `AI-3`); reviews and plans cite this ID to justify a finding
> unambiguously. IDs are stable — when revising, change the content but
> do not reassign IDs that have already been issued. Tech-stack-specific additions get new IDs
> in the appropriate namespace series (e.g. `MAINT-10`).

Table of contents (master numbering — gaps are sections not in this variant):
2. Resilience & Operations (`RES-*`)
4. Security (`SEC-*`)
5. GDPR & Compliance (`GDPR-*`)
7. Maintainability & Quality (`MAINT-*`)

Each item names: what it means, how you recognize it *well*, and typical *Red Flags*.

---

## 2. Resilience & Operations

- **RES-3 · Idempotency, Retry Safety & Explicit Guarantees** — correctness under **repetition,
  concurrency and disorder**: the same operation twice, out of order, or while still running must
  not act twice. This never holds by accident, so the guarantee is **stated, not assumed** — every
  mutating endpoint and queue consumer declares what it promises (default: *at-least-once delivery
  + idempotent processing*; an "exactly-once" claim without dedupe is to be distrusted). *Good:*
  `f(f(x)) = f(x)` — replays, retries and crash recovery converge on the same state, and side
  effects (logs, metrics, notifications) can't corrupt it. *Red Flag:* an endpoint that bills twice
  on retry; no dedupe on an at-least-once queue; nobody can say what happens on redelivery;
  **two services assuming different consistency models across one boundary** — the root of most
  distributed data corruption.

## 4. Security

- **SEC-1 · AuthN/AuthZ of the Clients** — OAuth2/OIDC or JWT per user. *Red Flag:*
  **static API key in the app binary** (trivially extractable).
- **SEC-3 · Secrets Management & Key Rotation** — provider keys in a vault or similar, never in
  the code/repo. *Red Flag:* keys/tokens in source code, in configs or logs.
- **SEC-5 · Supply Chain & Dependency Vulnerabilities** — SBOM, pinned versions, and **actual CVE
  scanning in CI** (osv-scanner / npm audit / trivy): an SBOM nobody scans is inventory, not
  defense. Known-vulnerable deps fail the gate or are tracked with a deadline. *Red Flag:* no CVE
  scan, so criticals sit unnoticed; a lockfile-free build installing a different tree than tested.
- **SEC-6 · Encryption** — in transit (TLS) and at rest. *Red Flag:* TLS terminates at the load
  balancer and the hop to the database is plaintext; sensitive data sits unencrypted at rest; or
  crypto is home-grown.
- **SEC-7 · Input Validation** — all external inputs are validated. *Red Flag:* an external input
  reaches a handler without validation at the boundary — the type system is trusted for data that
  came off the wire.
- **SEC-8 · Object-Level Authorization (IDOR) & Tenant Isolation** — every object access verifies
  the caller may see it, enforced **in the query** (WHERE user/tenant), not only at the route
  guard. *Red Flag:* an ID from the request is trusted and fetched without an ownership/tenant
  predicate — reachable cross-tenant data.
- **SEC-9 · Rate Limiting & Abuse Defense (both directions)** — **inbound:** per-user/per-IP
  throttling on auth and expensive/AI endpoints, cost caps tied to attestation,
  brute-force/credential-stuffing protection. **Outbound:** your own calls stay within provider
  limits, so one burst can't get the whole platform throttled. (An AI-assisted attacker doesn't
  change the defense — only its speed and scale, which is what a limiter answers.) *Red Flag:* an
  unauthenticated or per-token-costly endpoint with no limiter → cost-drain / enumeration;
  unbounded fan-out to a rate-limited provider.
- **SEC-10 · Session & Token Lifecycle** — short-lived access tokens + rotating refresh,
  server-side revocation, logout/compromise invalidation, sane expiry. *Red Flag:* long-lived,
  non-revocable bearer tokens; no way to kill a stolen session.
- **SEC-11 · SSRF & Outbound-Request Safety** — server-side fetches of user-influenced
  URLs/uploads are constrained (allow-list, no internal-network/metadata reachability,
  size/type/timeout). *Red Flag:* the server fetches a user-supplied URL unrestricted.

## 5. GDPR & Compliance

- **GDPR-1 · DPA with every model provider** and **data location/third-country transfer** clarified
  (US provider → SCC + Transfer Impact Assessment). *Red Flag:* personal
  content goes to a US provider without a legal basis.
- **GDPR-2 · Data minimization, purpose limitation, Privacy by Design/Default.** *Red Flag:* a
  field is collected or retained because it might be useful later, with no stated purpose and no
  retention limit.
- **GDPR-3 · Data subject rights technically implementable** — deletion, access, portability;
  incl. deletion/retention concept (also for logs and caches). *Red Flag:* deletion removes the
  primary rows but not the blob store, the payload archive, the caches or the logs — the data is
  gone from the query, not from the system.
- **GDPR-4 · Minors'/students' data** — apps that handle children's/students' data need
  heightened protection, possibly the consent of guardians. *Red Flag:* children's or students'
  data is processed on the same defaults as adults' — no guardian-consent path, no heightened
  retention limit.
- **GDPR-5 · Logging without plaintext PII and without user content.** *Red Flag:* a log line, a
  trace attribute or an error payload carries user content, an email address or a prompt/response
  body.

## 7. Maintainability & Quality

- **MAINT-1 · Modularity, Cohesion & Context-Window Fit** — the load-bearing structural dimension:
  separation of concerns, loose coupling, high cohesion and simplicity are **one property seen
  from four sides**, not four attributes. A capability is understood and changed by loading **one
  module plus its contract**, not the whole tree — which serves human readers and AI agents alike
  and keeps the blast radius small. *Good:* modules with one reason to change; stable contracts
  (shared types/DTOs); a capability map (`CLAUDE.md`, module READMEs); few layers, no hidden
  magic; a new app/feature attaches without core changes. *Red Flag:* god-services (a 900+-line
  service mixing provider dispatch, parsing and persistence) forcing huge context for a small
  change; app- or tenant-specific logic in the shared core; abstractions that hide rather than
  explain.
- **MAINT-2 · Testability** — incl. **deterministic mocks for the non-deterministic
  models** and contract tests client↔API. *Red Flag:* tests call real models
  and are therefore flaky/expensive.
- **MAINT-3 · CI/CD & IaC** — reproducible builds and infrastructure, and gates that actually
  gate. *Red Flag:* the build or the infrastructure exists only on someone's machine or in a
  console — it cannot be reproduced from the repo; **or a gate scores green without running
  anything** (`"lint": "echo ok"`), so "CI is green" carries no information — which is the one
  fact the whole merge gate rests on.
- **MAINT-5 · Feature Flags, A/B & Remote Config** — behavior and parameters (prompts, models,
  features, SKUs, limits) change **without an app release** — the lever that makes a forced update
  (`API-2`) the exception rather than the routine. On a shared platform this is also where
  **per-tenant/app configuration** lives, so a tenant's settings are data, not a code branch in
  the core (`MAINT-1`). *Red Flag:* a prompt or price change requires shipping a new client
  version; tenant differences expressed as `if (tenant === 'x')` in the shared core.
- **MAINT-7 · Dead-Code & Dependency Hygiene** — no unused exports/files/dependencies, no
  orphaned feature-flag branches or commented-out blocks. *Good:* dead-code/dependency
  detection (`knip`/`ts-prune`/`depcheck`, or stack equivalents) runs and is green. *Red
  Flag:* unused dependencies inflating image size and attack surface; dead code that
  misleads readers and agents about what is actually live.
- **MAINT-8 · Architectural Drift Control** — the code still matches the documented
  architecture (this catalog, ADRs, design principles); deviations are either fixed or the
  docs are deliberately updated. *Good:* enforced fitness functions (e.g. no provider SDK
  import outside the AI module, zero module cycles, no app-specific logic in the shared
  core). *Red Flag:* silent erosion — provider SDK calls leaking into business logic,
  tenant isolation bypassed, modularity decaying release over release.
- **MAINT-9 · Data-Model Integrity & Single Source of Truth** — information is the product; data
  that contradicts itself cannot be reasoned about, reported on or complied with. Every fact has
  **exactly one authoritative home**; everything else is a derived, marked copy (cache,
  projection) rebuildable from it. Relations are meaningful and enforced, and a value's flow is
  traceable: where it came from, who may change it, what it invalidates. Generalizes `PAY-1` from
  money to all state, and applies on **every surface** — a client's local store is a cache, not a
  second truth. *Good:* one owner per entity; invariants enforced where the data lives (schema
  constraints server-side, a single store/reducer client-side), not only in whatever code path
  happens to write; caches and projections are derivable and invalidated, never authoritative.
  *Red Flag:* the same fact in two places that can disagree, with no rule which wins; a "temporary"
  denormalized copy that became the real source; a client that mutates its local state without the
  server ever confirming; nobody can say where a value originates.

---

## Prioritization

When not everything can be addressed at once, the following dominate: **object-level
authorization and tenant isolation** (`SEC-8`), **secrets out of the code** (`SEC-3`),
**input validation at the boundary** (`SEC-7`), **correctness under repetition** (`RES-3`),
and the two GDPR dimensions that cannot be retrofitted — **third-country transfer** (`GDPR-1`)
and **implementable deletion** (`GDPR-3`).

The structural dimensions `MAINT-1` (modularity & context-window fit), `MAINT-7` (dead-code
hygiene), `MAINT-8` (drift control) and `MAINT-9` (data-model integrity) erode **silently over
many changes** rather than failing a single PR. They are tracked periodically over the whole
codebase by `wai-architecture-audit` — which measures their **trend** rather than a one-time
pass/fail.

## Retired IDs

Merged into a sharper dimension. **Never reuse these numbers** — old findings, ADRs and PR
comments must stay resolvable. `MAINT-4` → `SEC-8` + `MAINT-1` · `MAINT-6` → `MAINT-1` ·
`RES-4` → `SEC-9` · `SEC-12` → `SEC-5` · `API-3` → `MAINT-5` · `PAY-10` → `SEC-13`.
