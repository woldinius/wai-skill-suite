# Audit Playbook — tooling, rubrics & methods

> Reference for `wai-architecture-audit` (structural health). The SKILL describes *what* to
> audit and the output format; this file gives the *how* — concrete commands per stack, the
> semantic-redundancy / dead-end method, the modularity & decoupling rubric, the container
> checklist, the drift-detection method, and the mutation pass. Adapt to the repo you are actually in; run tools
> ad-hoc (you do **not** need them wired into CI to use them once).
>
> **Security is a separate skill.** Secrets, injection, authZ/IDOR, SSRF, CVEs, crypto/TLS and
> token-economy fraud belong to `wai-security-audit` and its
> `references/security-audit-playbook.md`. This playbook stays structural.

---

## 1. Metrics pass — tooling per stack

Capture numbers, not impressions. Prefer read-only/ad-hoc invocation (`npx` — or the runner that
matches the repo's lockfile — `uvx`, `go run`) so the audit adds nothing permanent to the repo.

**First, look at the repo you are actually in.** The commands below are written for the common
layouts; substitute the real package manager, workspace layout and source roots before running
them (`<pkg-root>` = the workspace/module you are auditing, e.g. the backend package). A command
that fits a different repo's tree is not a measurement.

**Check the lint/dead-code gate itself.** Before trusting a clean metric, confirm the repo's CI
actually runs one — a lint job that is a stub (`echo "no lint"`), or a workspace excluded from
the lint glob, means "no findings" says nothing. A missing gate is itself a `MAINT-*` finding and
a follow-up for `wai-cicd`.

### TypeScript / JavaScript (npm/pnpm/yarn; single package or monorepo)

**Read the lockfile first.** `npx` below is the neutral runner — it ships with Node and works in
every JS repo. If the lockfile is `pnpm-lock.yaml`, `pnpm dlx` is the faster equivalent; for
`yarn.lock`, `yarn dlx`. Do **not** reach for `pnpm` in an npm repo: it isn't installed, every tool
then fails, and the honest-degradation rule below turns the whole metrics pass into "not measured
this run" — run after run, while the codebase drifts unmeasured.

| Goal | Tool | Ad-hoc command |
| --- | --- | --- |
| Unused files / exports / deps | `knip` | `npx knip --no-exit-code` (per workspace if needed) |
| Unused exports (narrow) | `ts-prune` | `npx ts-prune -p <pkg-root>/tsconfig.json` |
| Unused dependencies | `depcheck` | `npx depcheck <pkg-root>` |
| Import cycles / module graph | `madge` | `npx madge --circular --extensions ts <pkg-root>/src` |
| Copy-paste duplication | `jscpd` | `npx jscpd <pkg-root>/src --min-tokens 60` |
| Type-safety erosion | `type-coverage` | `npx type-coverage --detail` |
| Why is a dep here | the package manager | `npm why <pkg>` · `pnpm why` · `yarn why` |
| Bundle weight (web clients) | the framework's build | read the route/bundle table it prints |
| File-size scan | shell | list largest source files by line count |

### Python

| Goal | Tool | Command |
| --- | --- | --- |
| Dead code | `vulture` | `uvx vulture src/` |
| Unused/undeclared deps | `deptry` | `uvx deptry .` |
| Lint / unused imports | `ruff` | `uvx ruff check .` |
| Complexity | `radon` | `uvx radon cc -s -a src/` |
| Layering/boundaries | `import-linter` | `uvx lint-imports` |

### Go

| Goal | Tool | Command |
| --- | --- | --- |
| Dead code | `deadcode` | `go run golang.org/x/tools/cmd/deadcode@latest ./...` |
| Static analysis | `staticcheck` | `go run honnef.co/go/tools/cmd/staticcheck@latest ./...` |
| Suspicious constructs | `go vet` | `go vet ./...` |

### Swift / iOS

| Goal | Tool | Command |
| --- | --- | --- |
| Lint / style | SwiftLint | `swiftlint` (or `swiftlint --strict`) |
| Dead code | Periphery | `periphery scan` |
| Formatting | swift-format | `swift-format lint -r Sources` |
| Build / test | xcodebuild | `xcodebuild test -scheme <scheme> -destination '...'` |

### Kotlin / Android

| Goal | Tool | Command |
| --- | --- | --- |
| Lint / style | detekt | `./gradlew detekt` |
| Android lint | Android Lint | `./gradlew lint` |
| Dependencies | Gradle | `./gradlew :app:dependencies` (+ IDE unused-code inspections) |
| Build / test | Gradle | `./gradlew testDebugUnitTest` |

### Stack-agnostic

- **Hotspot map** — churn × complexity: files that change often *and* are large/complex are
  the real risk. Approximate churn with `git log --format= --name-only` counts over the
  audit window; cross with file size.
- **`cloc`** — language/size breakdown to frame the report.
- **God-file scan** — list source files over the size thresholds in §3.

### When a tool doesn't run

Ad-hoc tools are downloaded on demand, so a sandbox without network, a registry hiccup or a
missing toolchain will take one out mid-run. That is normal — what matters is what you report.

**Degrade honestly. Never reuse the previous audit's number as if you had measured it.** A stale
value presented as fresh is worse than a gap: it makes a trend line that is fiction, and the next
audit diffs against it. So:

- Mark the metric **`not measured this run`** in the report, with the reason (tool unavailable),
  and carry the last known value **only** as an explicitly dated reference — never as this run's
  number, and never as a trend point.
- Try the cheap substitute before giving up: `git grep`/shell for the crude version of the same
  signal (file sizes, obvious duplicate blocks, imports of a suspect module).
- If a metric goes unmeasured across several runs, that is itself a finding — the audit has a
  blind spot, and the fix (pin the tool, cache it, wire it into CI) belongs in the report.

## 2. Semantic redundancy, consistency & cross-surface dead-ends

The layer the tools in §1 **cannot** reach — and the reason the audit earns its keep. §1 finds
unreferenced exports (`knip`/`ts-prune`) and copy-paste (`jscpd`); it does **not** find two
implementations of one idea, a redundant abstraction, an endpoint no client calls, or a
divergent pattern. Those need reading and reasoning.

**Method — capability map, then diff:**
1. **Build/refresh a capability map.** For a large codebase, fan out parallel readers (Explore
   agents), each taking a module/area, each returning: what capability it provides, its public
   surface, its key dependencies. Assemble the map (persist it as the architecture baseline —
   see §6). This is the same map the modularity rubric (§3) and drift method (§6) reuse.
2. **Diff capabilities against each other** for the non-obvious:
   - **Semantic redundancy** — two entries that provide the *same* capability differently
     (two HTTP clients, two date/money utils, two repositories over one table, two services that
     both "generate the thing"). Name both locations and why they're the same intent.
   - **Redundant abstraction** — a wrapper/layer that only forwards, or two abstractions that
     should be one; apply the **deletion test**: would deleting it concentrate complexity, or
     just move it around?
   - **Inconsistency** — one concept implemented divergently across modules/surfaces: two error
     formats, two validation styles, two naming conventions for one idea. Divergence raises the
     cost of every future change even when nothing is "dead".
3. **Cross-surface dead-ends** — the multi-repo blind spot. Cross the **API contract** with all
   three clients (`references/contract-protocol.md` (in the `wai` skill)): a backend endpoint/field **no client
   consumes** is dead *across repos* — invisible to any single-repo tool. Also: always-off
   feature flags, code paths gated unreachable, orphaned handlers.

Each finding cites concrete locations and the reason — evidence, not suspicion. Consolidation
proposals carry behavioral risk, so they go to `wai-implementation`, never auto-applied.

## 3. Modularity & decoupling rubric (`MAINT-1`)

The question: **can a capability be understood and changed by loading one module + its
contract, not the whole tree?** This is what makes a codebase decoupled, and workable for an AI
coding agent (bounded context window) and for a human alike. Score against concrete signals:

- **Module = capability.** One bounded module per capability (a backend feature module, a client
  route group), with a clear public surface. Working on it should mean reading *it* plus its
  contract, not ten neighbours.
- **File-size smell caps (services/files):** `>400 lines` = watch, `>800 lines` = god-file →
  flag. **The size is the smell, not the finding** — open the file and name *which*
  responsibilities it fused before you call it a `MAINT-1`. The classic shape in an AI backend:
  one service that dispatches to several model providers *and* parses their output *and*
  persists the result — the fix is per-provider adapters behind the existing interface, not a
  line-count diet. A long file with one job is not a god-file.
- **Cohesion / single responsibility.** Provider dispatch → per-provider adapters; split
  large read (query) paths from write (mutation) paths; one reason to change per unit.
- **Stable per-module contracts.** Shared types/DTOs (a shared package, or whatever the repo uses
  as its seam) define the boundaries so a change stays local and an agent can rely on the
  contract without reading the implementation.
- **Navigability / capability map.** A `CLAUDE.md` or module README index that lets an
  agent jump to the right capability by name instead of grepping the whole tree. Its absence
  for a large app is itself a `MAINT-1` finding.
- **Colocation over reach-in.** Logic for a capability lives with it; cross-module reach-in
  (importing another module's internals) erodes the boundary — flag it (overlaps `MAINT-8`).
- **Metrics that make it objective:** fan-out (efferent coupling) per module, fan-in / LCOM
  (cohesion), files touched per typical change, module cycles = 0. A rising fan-out or a growing
  files-per-change is drift even while every single PR looked fine.

A good outcome reads: "an agent asked to change one capability loads that capability's module and
the contracts it depends on — not the whole backend tree."

---

## 4. Determinism, idempotency & data integrity review (`RES-3`, `MAINT-9`)

The catalog states **what must hold** (`RES-3`: correctness under repetition, concurrency and
disorder, with the guarantee stated rather than assumed; `MAINT-9`: one authoritative home per
fact). This is **how you look for violations**. It lives here, not in the catalog, because it is
detection knowledge — and because prescribing a mechanism (CRDTs, immutability, eventual
consistency) would turn a contract into an architecture decision that belongs in an ADR.

**Ask of every mutating endpoint and every queue consumer: what happens if this runs twice?**

- **Stated guarantee.** Can anyone name the delivery and consistency guarantee of this path? If
  not, that alone is the finding — an unstated guarantee is an assumed one, and two components
  will assume differently. Look especially at boundaries between services, and between a client
  and the API.
- **"Exactly-once" claims.** Treat as a smell until shown a dedupe key. At-least-once delivery +
  idempotent processing is the honest, achievable pair; exactly-once is usually a claim about the
  broker that the *application* then violates.
- **Idempotency keys** on POST/mutating calls that cost money or tokens; the key is persisted and
  the second call returns the first result rather than re-doing the work.
- **Optimistic locking** (`ETag`/`If-Match`, version columns) wherever two writers can race — its
  absence is the classic lost update.
- **DELETE is idempotent** by nature: the second delete finds nothing and must not error into a
  broken state.
- **Deterministic error paths.** A failure halfway through must leave no half-state: either the
  transaction rolls back, or a compensating action exists, or the state machine can resume. Error
  paths are usually the *least* tested and the most non-deterministic part of a system.
- **Side-effect isolation.** Logging, metrics, notifications and analytics must not be able to
  corrupt or block the main state transition — a retry that re-sends an email is a bug, a retry
  that re-charges a card is a disaster.
- **Ordering.** Does the code assume messages arrive in order? Most brokers do not promise it.
  Out-of-order redelivery is the test.
- **Replay / crash recovery.** Can the system be replayed from its log/queue onto the same end
  state? If not, `f(f(x)) = f(x)` does not hold somewhere.

**Data integrity (`MAINT-9`) — trace the facts, not the code:**

- **One authoritative home per fact.** Find values stored in two places (a column *and* a cache, a
  client-side copy, a denormalized projection). For each: which one wins, who invalidates the
  other, and can it be rebuilt? A copy that cannot be rebuilt from its source is not a copy — it
  *is* the source, and probably by accident.
- **Constraints in the schema, not only in code.** Foreign keys, uniqueness, check constraints.
  Rules enforced only in application code are rules that a second writer (a migration, a script,
  another service) will silently break.
- **Traceable flow.** Pick two or three business-critical values and follow them end to end: where
  they originate, who may change them, what they invalidate. Where the trail goes cold, that is
  the finding.
- **Contradiction hunting.** Two tables/fields that can disagree with no reconciliation job, a
  "temporary" denormalization that became load-bearing, a status field derivable from other state
  yet independently written.

---

## 5. Performance, container distribution & DB-topology checklist

### Architecture efficiency (`PERF-1..4`, `RES-1`)
- No AI call on the synchronous request thread — long/expensive generation is enqueued on the
  repo's job queue, with status polling/notification (`RES-1`). Flag any in-request generation.
- Caching where identical expensive requests recur (`AI-4`/`PERF-1`).
- No unnecessary materialization of large payloads — stream PDFs/images rather than loading
  fully into memory (`PERF-4`).
- Query efficiency — N+1 patterns, missing indexes on hot lookups.

### Container right-sizing, image hygiene & topology (`PERF-5`, `RES-5`)
- **Multi-stage + prod-only.** Build deps stay in the builder stage; runtime image ships only
  what it needs — recognize a prod-only install/prune step as a positive rather than hunting for
  something to fix.
- **One concern per container.** The API and the background worker should run as **separate
  processes/images** (separate entrypoints); when they already do, say so as a positive. Flag any
  drift back toward one fat container running unrelated processes.
- **Resource limits** per service (CPU/memory) so one service can't starve the box.
- **Readiness vs. liveness** (`RES-5`) — `GET /health` that is liveness-only (no DB/dep check)
  is a readiness gap; flag it as a good, cheap target.
- **Scale-to-zero candidates** — spiky workers that idle most of the time are cost levers.
- **Image weight** — watch image size trend; large jumps usually mean leaked build deps.

### Database topology (`PERF-2`) — structural side only
- **Pool sizing** bounded per service **× replica count** (total connections must fit Postgres
  `max_connections`); separate pools for the API and the worker.
- **Migration safety** — forward *and* backward compatible, whatever the migration tool; no
  destructive migration without a compatibility window for store clients.
- *(TLS to the DB, least-privilege roles, no-creds-in-logs are `SEC-6`/`SEC-3` — the security
  audit's DB-connection posture, not here.)*

### Client & mobile structural health (`CLIENT-*`/`IOS-*`/`AND-*`/`WEB-*`)
- **Token purchase correctness (structure)** (`PAY-*`) — verified server-side, idempotent
  crediting, restore + refund handling present; no Stripe-for-tokens on mobile (`PAY-8`). (The
  *fraud/replay attack* view is the security audit's `SEC-13`.)
- **SDK / target currency** — Play target-API level meets the current requirement (`AND-4`); no
  deprecated StoreKit/Play-Billing APIs where a current version is required.
- **State & accessibility debt** (`CLIENT-4`/`CLIENT-5`) — screens cover
  loading/empty/error/offline; Dynamic Type/VoiceOver, TalkBack, WCAG.
- **Dead screens/flows** — client-side counterpart to the dead-end pass (§2).
- *(Binary secrets `CLIENT-1` and attestation `CLIENT-2` are the security audit's.)*

---

## 6. Architecture baseline & drift-detection method (`MAINT-8`) & trend

Drift is the gap between **documented intent** and **current code**. The **architecture
baseline** — the capability map (§2) + the allowed-dependency rules — is the intent; make the
gap measurable:

1. **Derive fitness functions** from the baseline + catalog + ADRs — small, checkable
   invariants. Typical ones for a multi-surface AI platform:
   - No model-provider SDK imported **outside** the AI module → grep the import graph; hits are
     `AI-1`/`MAINT-8` drift.
   - **Zero** module import cycles (`madge --circular`).
   - No app-specific (per-product) special-casing in the shared core → `MAINT-1`/`MAINT-8`.
   - Every billable AI call records usage idempotently (`AI-9`/`RES-3`).
   - Every token credit is verified server-side and idempotent; no client-trusted balance
     (`PAY-1`/`PAY-2`/`PAY-3`).
   - Clients build against a **current contract version**; none pinned to a deprecated one
     (`API-1`/`MAINT-8`, see `references/contract-protocol.md` (in the `wai` skill)).
2. **Check for violations** with grep/the import graph; each violation is a finding with its
   ID.
3. **Compute the trend** — diff against the most recent `docs/architecture/audits/*.md`:
   count of dead exports, cycle count, god-file count, fitness-function violations. Report each
   as `new` / `worsening` / `stable` / `improving`. The persisted history is what makes
   "are we drifting?" answerable rather than guessed.

When a fitness function is wrong (the rule, not the code, is outdated), that belongs in the
report's **Architecture baseline, design-principle & catalog proposals** section — propose the
baseline/catalog/ADR change with a new ID, don't silently bend the code to a stale rule.

---

## 7. Mutation pass — kill rate as a trend, survivors verified (`MAINT-2`)

Coverage numbers and enumeration guards measure what the tests *touch*; a mutation pass measures
what they *check*. An enumeration guard finds **forgotten** cases (a new store missing from the
erasure list breaks the build); it cannot find **untested present** ones — code that is listed,
covered, and would pass green with its logic inverted. In the field, a budget of **28 one-line
mutations found four real gaps** (24 killed = 86%) that no enumeration guard could have seen.

**Method — a small budget, not a campaign:**

1. **Budget.** Pick a small, fixed number of one-line mutations per audit (the field run used
   ~25–30) on high-value logic: guards, money/quota math, validation branches, error paths.
   One mutation at a time: flip a comparison, negate a condition, off-by-one a boundary, drop a
   guard clause. Restore between mutations via the **snapshot pattern** — `cp` the file aside
   before mutating, copy it back after; **never** `git checkout`/`git restore` for the undo
   (`references/agent-git-protocol.md` §*The snapshot pattern*, in the `wai` skill).
2. **Run** the test suite per mutation. Suite red = **killed**; suite green = **survivor**.
3. **Verify every survivor before reporting it — the hard rule.** A surviving mutation may be
   reported as a test gap **only after verifying the mutation hit executable code** — not a
   comment, not a dead line, not a string the runtime never evaluates. Re-read the mutated line
   in context; if in doubt, prove execution (a temporary trace, a type error, the debugger). The
   field tool's first version replaced the first *text* occurrence — **three times a comment** —
   and nearly reported **three false survivors**; only the second pass (did it hit executable
   code?) separated real gaps from no-ops. **An instrument that finds test gaps must not produce
   false ones**: one fabricated gap and every future survivor is doubted, which kills the pass.
4. **Record the kill rate as a trend, never a lone snapshot.** A single kill rate has no
   baseline — 86% is neither good nor bad in isolation. Log it in the audit report next to the
   previous audit's rate and mark it `new` / `worsening` / `stable` / `improving`, exactly like
   the §6 trend metrics; note the mutation budget and which areas were mutated so the next audit
   can compare like with like. Each **verified** survivor becomes a finding (`MAINT-2`) naming
   the mutated line and the assertion that should have killed it — the fix belongs to
   `wai-testing`, not to this audit.
