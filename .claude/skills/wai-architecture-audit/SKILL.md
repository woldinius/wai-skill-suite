---
name: wai-architecture-audit
description: >-
  Periodic, whole-codebase structural-health audit: architectural drift, coupling, god-services,
  dead code — and the subtle part, semantic redundancy, inconsistency and cross-surface dead-ends —
  measured as a trend against a persisted architecture baseline. Use it to check the whole app, not
  one change: "audit the codebase", "is it decoupled/modular", "find drift/dead code/redundancy",
  "did we accumulate tech debt", "run the periodic audit". Not for the security sweep
  (wai-security-audit), a single PR (wai-pr-review), a fix (wai-implementation) or setup (wai-init).
license: MIT
---

# Architecture & Structural-Health Audit

Step back from individual changes and audit the **whole codebase** as a Senior Software
Architect. After a few features and refactorings, drift, coupling, dead code and — the subtle
part — **semantic redundancy and inconsistency** accumulate **silently**: no single PR fails, but
the structure slowly decays. This skill catches that early, measures it as a **trend over time**,
and keeps the code workable for humans and AI coding agents. Where the architecture baseline or
the rules themselves have gone stale, it proposes changes to them.

**Cyber-security is a separate skill.** The adversarial attack-surface sweep belongs to
**`wai-security-audit`**. Where structure and security overlap — tenant isolation, DB-connection
posture — this skill judges the **structural** side (is the boundary clean) and defers the
**exploitability** side to the security audit. Run both periodically.

## Platform context

*(The suite's home platform — the worked example these skills grew against, kept concrete on purpose. `wai-init` scopes the quality catalog to what **your** repo actually is; where your product has none of this — no token economy, no mobile clients, no AI orchestration — read the matching rules as not-applicable, not as findings.)*

A **multi-surface product** — cloud backend (AI orchestration + token ledger) with **Web, iOS
and Android** clients, joined by a **versioned API contract**; in the hybrid topology each
client is its own repo. Three consequences shape every audit:
- **The three clients cannot be forced to update** → API backward compatibility is a standing
  invariant, and drift away from it is a high-severity finding; watch for clients stuck on an
  old contract version.
- **AI inference costs money per token** → efficiency and cost are first-class quality
  attributes, not nice-to-haves.
- **The token economy spans client + backend** → ledger reconciliation, idempotency coverage
  and refund/clawback handling are audit targets (`PAY-*`).

## Stance

- **Periodic & whole-codebase.** This is not a per-diff review (that's `wai-pr-review`).
  Run it after several features/refactors to take the temperature of the entire app.
- **Report + proposals first.** The default deliverable is a prioritized report and concrete
  proposals (dead-code removals are listed as an exact diff/checklist). **Edit nothing** in
  this mode.
- **Safe cleanups only on explicit approval.** When the human approves, apply **mechanical,
  low-risk** cleanups (unused-export/file/dependency removal). Anything with behavioral risk
  stays a proposal. Commit the report and any approved cleanups on an `agent/<handle>/chore-audit-<date>`
  branch and open a PR; **never commit, push or merge to `main`** (full rules under *Git & PR*).
- **Evidence over opinion.** Back findings with tool output and metrics (counts, line sizes,
  cycle counts), not vibes. A finding without evidence is a question, not a finding.
- **Proportional.** Flag what is **trending the wrong way**; do not rewrite a healthy app or
  invent work. A clean codebase gets a short, honest "healthy" report.
- **Allowed to challenge the rules.** When a finding reveals that the catalog/ADRs/design
  principles are outdated, propose changes to *them* (new IDs, revised wording) — clearly
  separated from code findings.

## Process

Work through these steps in order. Scale depth to the size of the change surface since the
last audit — don't re-derive a full report when nothing meaningful changed.

1. **Scope & architecture baseline** — Find the previous audit under `docs/architecture/audits/`
   (most recent dated file). Determine what changed since (git log since that date, or the last N
   merges). Establish the **intended architecture** you measure drift against: the live catalog
   `docs/architecture/quality-attributes.md`, any ADRs, and — the concrete part — an
   **architecture baseline**: a **module/capability map** (what modules exist, their public
   surface) plus **allowed-dependency rules** (which module may depend on which; the shared core
   depends on nothing app-specific). If that baseline doesn't exist yet, **derive and propose
   one** (persist it under `docs/architecture/`) so drift is measured against something concrete
   and the next audit can diff against it. If the catalog is missing, note it once (suggest
   `wai-init`) and proceed with the dimensions below as the default standard.

2. **Metrics pass** — Run stack-appropriate dead-code / dependency / complexity / coupling /
   duplication tooling and **capture the numbers** (exact commands per stack in
   `references/audit-playbook.md`; in a TypeScript repo e.g. `knip`, `ts-prune`, `depcheck`,
   `madge`, `jscpd`) — run them ad-hoc; they need not be wired into CI. If a tool won't run,
   report the metric as **not measured this run** — never carry the previous audit's number
   forward as if it were fresh. Record file/module sizes and import-cycle counts. **Tools find
   the syntactic layer** (unreferenced exports, copy-paste) — the semantic layer is step 3.

3. **Semantic redundancy, consistency & dead-ends pass** — the part tools miss and the reason
   the audit exists. Read the code and **reason** (for a large codebase, fan out parallel readers
   to build/refresh the capability map, then diff capabilities against each other). Hunt the
   **non-obvious**:
   - **Semantic redundancy** — two functions/modules doing the *same thing differently* (not
     copy-paste, so `jscpd` misses it); redundant abstractions that should be one (two HTTP
     clients, two date utils, two repositories over the same table).
   - **Cross-surface dead-ends** — a backend endpoint **no client calls anymore** (dead across
     repos — only visible against the contract + all three clients, `references/contract-protocol.md` (in the `wai` skill));
     a feature flag that is always off; a code path no longer reachable.
   - **Inconsistency** — the same concept implemented divergently: two error formats, two
     validation styles, two naming/patterns for one idea — the drift that makes the codebase
     harder to reason about even when nothing is strictly "dead".
   Each finding names the concrete locations and why they're the same/dead/divergent — evidence,
   not a hunch.

4. **Audit the structural & health dimensions** — Go through the lenses below; each is anchored
   to a catalog ID. Cite the **ID** in every finding (read the catalog/playbook for the
   per-dimension Red Flags). Evaluate what the codebase actually shows — don't demand
   completeness everywhere.
   - **Decoupling & modularity** (`MAINT-1`) — is each capability one bounded module
     with a clear public surface, changeable by loading **it + its contract**, not the whole
     tree? Low coupling, cohesion, colocation over reach-in; a capability map/index exists.
     Flag god-services and cross-module reach-in.
   - **Dead-code & dependency hygiene** (`MAINT-7`) — unused exports/files/deps, orphaned
     feature-flag branches, commented-out blocks (the syntactic complement to step 3).
     **Except a 🧩 `LEARN #` marker** — that is a human's open learning exercise, not dead code
     (`agent-git-protocol.md` §*Personal state never becomes repo state*). Never list it as a
     cleanup: a "safe cleanup" applied on approval would delete somebody's exercise.
   - **Determinism, idempotency & data integrity** (`RES-3`, `MAINT-9`) — playbook §4. Ask of
     every mutating endpoint and queue consumer: **what happens if this runs twice?** Is the
     delivery/consistency guarantee *stated* anywhere, or only assumed — and do both sides of a
     boundary assume the same one? Then trace the facts: does any value have two homes that can
     disagree, with no rule which wins? Structural, not behavioral — it erodes silently, which is
     why it belongs to the periodic audit and not to a single PR review.
   - **Architectural drift** (`MAINT-8`) — where the code diverged from the **baseline** (step 1),
     catalog or ADRs: provider SDK calls bleeding outside the AI module, an allowed-dependency
     rule violated, tenant-isolation **structure** leaking, new module cycles, app-specific logic
     creeping into the shared core.
   - **Architecture efficiency & performance** (`PERF-1..4`, `RES-1`) — N+1 queries, AI
     calls in the synchronous request path, missing caches, large-payload materialization,
     hot paths.
   - **Scalability & container distribution** (`PERF-3`, `PERF-5`, `RES-5`, `PERF-2`) —
     statelessness, image size/multi-stage, service topology/right-sizing, resource limits,
     scale-to-zero candidates, readiness vs. liveness, **DB pool sizing × replicas**. (TLS to the
     DB, least-privilege roles and secrets are the security audit's `SEC-6`/`SEC-3` — cross-ref,
     don't re-judge here.)
   - **Token economy health** (`PAY-*`) — reconciliation runs and is clean, crediting is
     idempotent (no double-credit on duplicate webhooks), consumption can't double-spend,
     refunds/revocations are clawed back, no client-trusted balances; the digital-goods rule is
     respected per surface (StoreKit/Play on mobile, Stripe on web).
   - **Client health** (`CLIENT-*`/`IOS-*`/`AND-*`/`WEB-*`) — for client repos: dead
     screens/flows, accessibility debt, SDK/target currency (Play target-API level, deprecated
     StoreKit/Play APIs), store-policy drift. (Binary secrets and attestation coverage are the
     security audit's `CLIENT-1`/`CLIENT-2` — cross-ref.)
   - **Contract drift across surfaces** (`API-*`/`MAINT-8`) — backend and clients still agree on
     the contract version; no client stuck on an old/unsupported version; generated clients in
     sync (`references/contract-protocol.md` (in the `wai` skill)).
   - **Modernization opportunities** — outdated dependencies or practices where a current
     best practice would concretely help (security, cost, maintainability). Propose, justify
     the benefit, don't churn for fashion.

5. **Signal vs. noise & prioritize** — Assign each finding a severity **and a trend tag**
   relative to the last audit (`new` / `worsening` / `stable` / `improving`). The trend is
   the point of running periodically — a `stable` minor issue is lower priority than a `new`
   or `worsening` one of the same severity.

6. **Proposals vs. safe cleanups** — Propose everything. For the mechanical, low-risk subset
   (unused exports/files/dependencies the tools agree are dead), list exact removals and
   **offer to apply them** — apply only after explicit approval, and then on the audit branch as a
   PR like any other change (never on `main`, never unapproved). Semantic
   redundancy/consistency findings (step 3) are **proposals only** — merging two implementations
   carries behavioral risk, so they go to `wai-implementation`, never auto-applied.

7. **Design-principle / catalog / baseline evolution** — When a finding shows the **rules** are
   stale or a new pattern should be adopted platform-wide, propose changes to the catalog/ADRs/
   **architecture baseline** (with new IDs in the right series), kept in a separate report
   section from code findings. This is how the architecture and design principles stay current.

8. **Write the dated report, commit on a branch, hand off** — Persist to
   `docs/architecture/audits/<YYYY-MM-DD>.md` (create the folder if needed) using the output
   format below. Per the git protocol, commit the report (and any approved cleanups) on an
   `agent/<handle>/chore-audit-<YYYY-MM-DD>` branch and open a PR; never touch `main`. Then
   summarize the headline findings and the **▶ Recommended next** actions in the chat; the
   persisted file is the trail the next audit diffs against. **Blocker/Major findings are the
   human's decision point** (present with a recommendation and wait). Then apply the **landing
   rule** (`issues-protocol.md` §*Where a finding lands*): every finding ends up **fixed**,
   **deliberately rejected with a reason in the report**, or **filed as a GitHub Issue** —
   format, labels, `**Skill:**` source and dedupe per the protocol; Nits from one area may be
   grouped. An audit that names a problem and files nothing has produced a document, not work.
   **Read existing issues first** (`gh issue list --label audit`) — link or update the open one
   instead of re-filing. The dated report stays the **narrative** source of truth; issues are
   the trackable handles into it. Without `gh`, list the would-be issues with their
   `gh issue create` commands.
   **Log the run before handing back:** `sh ../wai/scripts/run-log.sh "wai-architecture-audit"
   "<subject>" "<half-sentence outcome>"` (from this skill's directory) — an audit that finds
   nothing still writes its row, because that is the run that vanishes today; fail-open: exit 0
   even when the write fails, exit 2 only on misuse (missing arguments).
   **Then derive the closing state:** run `sh ../wai/scripts/open-items.sh` (same directory), paste
   its output verbatim beneath the ▶ Recommended next block, then give your recommendation — in that
   order: the script derives (exit 0 = emitted; exit 2 = nothing derivable — then say `not checked`
   yourself), the model recommends.

## Severity & trend

Keep the suite's severity levels, reframed for **shipped code** (not a diff under review),
and add a trend tag to every finding:

- **Blocker** — actively harmful in production: a broken backward-compatibility contract for
  store clients, a data-loss risk from a destructive migration, an import cycle or god-service
  that makes safe change impossible. (Security-exploitable holes — secrets, injection, IDOR — are
  the security audit's Blockers.)
- **Major** — should be scheduled soon: a god-service that blocks safe change (`MAINT-1`), a
  synchronous AI call in the request path (`RES-1`), an uncapped cost path (`AI-9`/`OBS-3`),
  meaningful dead weight in the production image (`MAINT-7`), a redundant abstraction actively
  diverging (two implementations of one capability drifting apart).
- **Minor** — address opportunistically: moderate duplication, an inconsistency in error/naming
  patterns, a missing readiness probe, observability gaps.
- **Nit** — cosmetic/optional.
- **Trend:** `new` | `worsening` | `stable` | `improving` — versus the previous audit.

Be honest. If the codebase is healthy, say so plainly and keep the report short — do not
manufacture drift to justify the run.

## Output format

Use exactly this structure for `docs/architecture/audits/<YYYY-MM-DD>.md`:

```
## Architecture & Structural-Health Audit: [repo] · [YYYY-MM-DD]

**Scope:** [since <last audit date> / last N merges · components covered]
**Overall:** [Healthy | Minor drift | Significant drift | At risk]
**Trend vs last audit:** [improving | stable | worsening — one line on what moved]

### Metrics snapshot
- Dead code: [N unused exports · M unused files · K unused deps]
- Largest modules: [file — lines] (god-file threshold: >800)
- Import cycles: [N] · Copy-paste duplication: [%/clusters]
- Semantic redundancy / inconsistency / cross-surface dead-ends: [N found in step 3]
- [deltas vs last audit where available]

### Findings
#### Blocker
- [File/area] · [Catalog ID] · [Trend] — [What] → [Concrete risk] → [Recommended fix]
#### Major
- ...
#### Minor
- ...
#### Nits
- ...

### Semantic redundancy, inconsistency & dead-ends (proposals — behavioral risk, not auto-applied)
- [locations] · [Catalog ID] — [same-thing-twice / dead-across-repos / divergent pattern] → [consolidation proposal]

### Dead code & safe cleanups (apply on approval)
- [ ] [exact export/file/dep to remove] · [tool(s) that flagged it]

### Architecture baseline, design-principle & catalog proposals
- [Proposed baseline/catalog/ADR change · new ID · why the current rule is stale / what to adopt]

### Positives — what's holding up well
- [Name the things that are healthy, with the ID they satisfy]

### ▶ Recommended next (ranked actions)
1. [Highest-leverage action — which skill takes it: **wai-implementation** on an
   `agent/**` branch for fixes/cleanups, or **wai-init** if a finding means the catalog
   itself should change.]
2. ...
```

Omit empty sections. If clean, make that clear in `Overall` and keep it brief.

## References

- `references/audit-playbook.md` — per-stack tooling commands for the metrics pass, the
  semantic-redundancy / consistency / cross-surface dead-end method, the modularity rubric
  (size thresholds, cohesion checks), the container/distribution checklist, and the
  drift-detection method (architecture baseline, fitness functions + trend).
- `docs/architecture/quality-attributes.md` — the live catalog; cite its IDs. If absent,
  note it once and use the dimensions above (run `wai-init` to generate it).
- `references/contract-protocol.md` (in the `wai` skill) — the contract spine; basis for
  the cross-surface contract-drift lens.

## Git & PR

**The authority is `references/agent-git-protocol.md` (in the `wai` skill).** Specific to
*this* skill: commit the dated report — and any **approved** safe cleanups — on an
`agent/<handle>/chore-audit-<YYYY-MM-DD>` branch, and open a PR. **Never commit, push or merge to
`main`**: the report PR goes through the same merge gate as any other.

Findings land per `issues-protocol.md` §*Where a finding lands* — fixed, deliberately rejected, or
**filed** (deduped against open `audit`-labelled issues). Filing is not fixing; the Blocker/Major
decision point is untouched. The dated report stays the narrative source of truth. No git or no
`gh` → write the report to the working tree, propose the commit/PR, and list the would-be issues
with their `gh issue create` commands.
(The Stance section above is also this skill's principles list.)

## Related Skills

This skill is the **periodic structural-health stage** that complements the lifecycle
plan → implement → review:
- **wai-security-audit** — the **adversarial** counterpart: this skill judges structure; that one
  judges exploitability. Run both.
- **wai-pr-review** — reviews a single diff *before merge*; this skill audits the *whole codebase
  periodically*.
- **wai-implementation** — takes over fixing the findings.
- **wai-init** — when drift means the **catalog itself** must change, or the catalog is missing,
  (re-)run it to regenerate `docs/architecture/quality-attributes.md`.
- **wai** — the suite router/overview.
- Shared source of truth for all of them: `docs/architecture/quality-attributes.md`.
