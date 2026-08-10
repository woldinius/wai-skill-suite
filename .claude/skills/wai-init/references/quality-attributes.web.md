# Quality Catalog — web variant (Seed)

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
> Variant scope: a backend + web-frontend product. No AI-model integration, no token
> economy, no mobile store surfaces — the sections and dimensions that exist only for
> those live in the platform variant.

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
3. Observability & Cost (`OBS-*`)
4. Security (`SEC-*`)
5. GDPR & Compliance (`GDPR-*`)
6. API & Client Compatibility (`API-*`)
7. Maintainability & Quality (`MAINT-*`)
8. Performance & Efficiency (`PERF-*`)
10. Client Common (`CLIENT-*`)
13. Web (`WEB-*`)

Each item names: what it means, how you recognize it *well*, and typical *Red Flags*.

---

## 2. Resilience & Operations

- **RES-1 · Asynchronous Processing with Queue + Backpressure** — AI calls are slow and
  expensive; synchronous request/response does not scale. *Good:* job-based with status
  polling or webhook. *Red Flag:* a long-running generation blocks the request
  thread.
- **RES-2 · Retries with Backoff, Circuit Breaker, Timeouts, Bulkheads** — against transient
  errors and cascading failures. *Red Flag:* retry without backoff, no timeout
  on external calls.
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
- **RES-5 · Health/Readiness Probes, Zero-Downtime Deploys, Rollback** — operation without outage
  windows, fast rollback capability. *Red Flag:* a `/health` endpoint returns 200 without
  checking its dependencies and is used as the readiness probe — traffic is routed to an instance
  that cannot serve. Or: no tagged previous image, so there is no way back.
- **RES-6 · Backup/Restore & a Rehearsed DR Scenario** — recovery is tested, not just configured.
  *Red Flag:* backups are configured but a restore has never been executed. An unrehearsed
  restore is a hope, not a backup.

## 3. Observability & Cost

- **OBS-1 · Structured Logging** — machine-readable and **correlatable**: a single request can be
  followed across services by a correlation/trace id. (What must *not* be in the log is
  `GDPR-5`'s rule, which applies on every surface — this ID is about the shape, not the
  content.). *Red Flag:* logs are unstructured text, or one request cannot be followed across
  services because no correlation/trace id is propagated.
- **OBS-2 · Metrics & Distributed Tracing** — traceable across the entire model-call chain. *Red
  Flag:* the model-call chain carries no spans — a slow or failing request cannot be attributed
  to the provider, the queue or the DB.
- **OBS-4 · SLOs & Alerting** — defined targets instead of gut feeling. *Red Flag:* no SLO is
  defined, so nothing can page: an outage is discovered by a user, not by an alert.

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

## 6. API & Client Compatibility

- **API-1 · API Versioning & Backward Compatibility** — old app versions continue to be
  served. *Red Flag:* breaking change to an existing endpoint without a new version.
- **API-2 · Min-Version/Force-Update Mechanism** — the server can deliberately force outdated
  clients to update. *Red Flag:* there is no server-side way to tell an old client to update — a
  breaking fix cannot be rolled out, because the clients that need it cannot be retired.
- **API-4 · OpenAPI Spec as a Binding Contract** — client and server share a verified contract;
  contract tests. *Red Flag:* the spec is hand-written after the fact and nothing verifies it
  against the running server — the contract the clients generate from is fiction.

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

## 8. Performance & Efficiency

- **PERF-1 · Asynchronous Processing & Caching Layers** (see above) as the primary levers. *Red
  Flag:* an expensive or long-running AI call runs inside the request thread; identical expensive
  requests are recomputed every time.
- **PERF-2 · Connection Pooling & Resource Limits** — defined limits per container/service. *Red
  Flag:* no connection pool bound per service × replica count (total connections can exceed the
  DB's `max_connections`), or a container with no CPU/memory limit that can starve the box.
- **PERF-3 · Scalability / Auto-Scaling** — horizontally scalable; possibly scale-to-zero to
  lower cost under low load. *Red Flag:* state is held in the process, so a second replica breaks
  correctness — the service cannot be scaled horizontally at all.
- **PERF-4 · Efficient Data Handling** — no unnecessary materialization of large payloads (stream
  PDFs/images instead of loading them fully into memory). *Red Flag:* a large payload (a PDF, an
  image, an export) is loaded fully into memory instead of streamed.
- **PERF-5 · Container Right-Sizing, Image Hygiene & Service Topology** — images are
  multi-stage and ship prod-only artifacts; one concern per container; right-sized with
  resource limits; the service split matches the scaling profile. *Good:* small images,
  separate API/worker processes, scale-to-zero for spiky workers. *Red Flag:* fat images
  shipping build dependencies, multiple unrelated processes in one container, no resource
  limits per service.

## 10. Client Common

- **CLIENT-1 · No Secrets in the Client** — no provider/API keys in the binary or bundle;
  per-user token auth only (client side of `SEC-1`/`SEC-3`). *Red Flag:* an AI-provider key
  shipped in the app.
- **CLIENT-3 · Backward-Compat & Force-Update Handling** — the client tolerates additive contract
  changes and handles the server's min-version/force-update signal gracefully. Consumes
  `API-1`/`API-2`. *Red Flag:* the client breaks on an unknown field in a response — an additive,
  backward-compatible contract change takes it down.
- **CLIENT-4 · State Coverage per Screen** — loading / empty / error / offline / poor-connection
  states are designed, not afterthoughts. *Red Flag:* a screen has only a happy path: an empty
  list, a failed request or no connection leaves a spinner running forever.
- **CLIENT-5 · Accessibility** — Dynamic Type & VoiceOver (iOS), TalkBack & scaling (Android),
  WCAG (Web). *Red Flag:* interactive elements carry no accessible label, or text does not scale
  with the OS font-size setting — the app is unusable with a screen reader.
- **CLIENT-6 · Crash Reporting & Telemetry** — crash + client telemetry without PII/user content,
  correlatable to backend traces (client side of `OBS-1`/`OBS-2`). *Red Flag:* crash reports or
  client telemetry carry user content or PII, or cannot be correlated to a backend trace.
- **CLIENT-7 · Secure Local Storage** — tokens/session in Keychain / Keystore / secure http-only
  cookie; never plaintext. *Red Flag:* a session token is stored in plaintext (`localStorage`,
  `SharedPreferences`, `UserDefaults`, a plain file) instead of Keychain / Keystore / an
  http-only cookie.
- **CLIENT-8 · Deep Links & State Restoration** — links and app/state restoration work and
  respect auth. *Red Flag:* a deep link opens a protected screen without re-checking auth.
- **CLIENT-10 · Localization** — user-facing strings localizable; locale-correct
  numbers/dates/currency (ties `PAY-9`). *Red Flag:* user-facing strings are hardcoded, or
  currency/date formatting ignores the locale — a price renders wrong in the user's region.

- **CLIENT-11 · Client-side Media Preprocessing before Upload** — images/video/audio are downscaled,
  re-encoded and stripped of metadata **on the device**, before upload; the client does not push raw
  capture at the backend. Ties `PERF-4` and `AI-9` (upload size drives inference cost) and `GDPR-2`
  (EXIF location is personal data nobody asked for). *Red Flag:* the client uploads the raw capture —
  a 12-megapixel original carrying GPS EXIF — and the backend downscales it *after* paying to
  receive, store and process it.
- **CLIENT-12 · Offline Queue & Deterministic Reconcile** — work created offline is queued and, on
  reconnect, reconciled by a **stated rule** (server wins · client wins · merge by version), not by
  whichever request happens to arrive last. Ties `RES-3`: the replay must be idempotent. *Red Flag:*
  reconnect replays the queue with no idempotency key and no stated conflict rule — two devices
  coming back online produce a different result depending on order, and nobody can say which one is
  correct.

## 13. Web

- **WEB-2 · Web App Security** — CSP, XSS/CSRF protection, secure/SameSite cookies; no token in
  `localStorage` where an http-only cookie is safer. *Red Flag:* no CSP; a session token in
  `localStorage` where an http-only cookie would do; no CSRF protection on a state-changing
  route.
- **WEB-3 · Consent & Client Analytics** — cookie/consent handling; no PII/user content in client
  analytics (`GDPR-5`). *Red Flag:* analytics fire before consent, or client analytics carry user
  content (`GDPR-5`).
- **WEB-4 · Bundle Weight & Core Web Vitals** — bundle/route weight watched; acceptable
  LCP/CLS/INP. *Red Flag:* a provider SDK or another heavy dependency ships in the client bundle;
  route weight is unwatched and grows unbounded.
- **WEB-5 · SSR Auth & Session** — server-rendered routes enforce auth; no session/secret leaks
  into the client bundle. *Red Flag:* a server-rendered route renders protected data without
  checking auth, or a secret leaks into the client bundle through a serialized prop.

---

---

## Prioritization

When not everything can be addressed at once, the following dominate for this system class:
**asynchronous resilience** (`RES-1`, `RES-3`), **protection of credentials and sessions**
(`SEC-3`, `SEC-1`, `SEC-10`), **object-level authorization** (`SEC-8`), **API backward
compatibility** (`API-1`, `API-2`, `CLIENT-3`) and the **GDPR third-country transfer**
(`GDPR-1`). Scalability, modularity and clean code are important, but table stakes — not what
such projects typically fail on.

The structural dimensions `MAINT-1` (modularity & context-window fit), `MAINT-7` (dead-code
hygiene), `MAINT-8` (drift control), `MAINT-9` (data-model integrity) and `PERF-5` (container
topology) are table stakes too, but they erode **silently over many changes** rather than failing
a single PR. They are tracked periodically over the whole codebase by
`wai-architecture-audit` — which measures their **trend** rather than a one-time pass/fail.

## Retired IDs

Merged into a sharper dimension. **Never reuse these numbers** — old findings, ADRs and PR
comments must stay resolvable. `MAINT-4` → `SEC-8` + `MAINT-1` · `MAINT-6` → `MAINT-1` ·
`RES-4` → `SEC-9` · `SEC-12` → `SEC-5` · `API-3` → `MAINT-5` · `PAY-10` → `SEC-13`.
