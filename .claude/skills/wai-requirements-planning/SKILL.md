---
name: wai-requirements-planning
description: >-
  Plans and shapes a new requirement before implementation — architecture, DevOps and the
  cross-cutting concerns (cost, GDPR, API compatibility, resilience, token economy) surfaced early,
  with a "grill me" interview mode and alternatives when the ask is imprecise. Takes a GitHub issue
  at invocation ("plan #42"), a set of issues that form ONE requirement ("#42 #43 #44"), or a plain
  description — plus directives like "grill me", "backend only", "no ADR". Use it to prepare any new
  feature, requirement or idea: "plan this requirement", "how should we build X", "concept for",
  "break this down into tasks", "do we need an ADR". Not for an already-clarified task
  (wai-implementation), a finished PR (wai-pr-review), or a backlog of INDEPENDENT issues
  (wai-team).
license: MIT
---

# Requirements Planning

Prepare a new requirement as a Senior Software Architect and DevOps expert
ready for implementation. The goal is to **make the non-obvious cross-cutting concerns visible
early** — before implementing — and to bring the requirement into a clear,
workable form. That is exactly the value: scaling, GDPR,
costs, API compatibility and resilience are thought through on the drawing board, not
retrofitted afterwards.

## Platform context

*(The suite's home platform — the worked example these skills grew against, kept concrete on purpose. `wai-init` scopes the quality catalog to what **your** repo actually is; where your product has none of this — no token economy, no mobile clients, no AI orchestration — read the matching rules as not-applicable, not as findings.)*

The platform is a **multi-surface product**: a **cloud backend** (orchestrates multiple AI
models/providers + owns the server-side **token ledger**), a **Web** app, an **iOS** app and an
**Android** app — four first-class surfaces joined by a **versioned API contract**. Backend+Web
are one TS monorepo; iOS (Swift/SwiftUI) and Android (Kotlin/Compose) are native, each its own
repo. Every new requirement is therefore first a platform question: **which surface(s)** does it
touch (backend, web, iOS, Android, or several)? Does it force an **API/contract** change the
three non-updatable clients see (`API-1`/`CLIENT-3`)? Does it touch the **token economy**
(purchase or consumption — `PAY-*`)? Does it create additional **AI costs**?

## What you can be given

Three things, in any combination. Resolve them **before** step 1 — what you were handed decides how
you start.

**A GitHub issue, or a set of them** — `plan #42`, or `#42 #43 #44`.
- Pull each with `gh issue view <N> --comments`; title, body and discussion are the source.
- **Claim them first** (`references/issues-protocol.md` §*Claiming*). Planning **is** the start of
  the work when it runs first, and two people planning the same issue for an hour is the exact cost
  of not claiming. Assigned to someone else → **do not start**: report the collision.
- **A set means ONE requirement, planned as one.** That is the whole point of passing several: they
  are one feature cut into tasks, they share a contract, a blast radius, a branch.
  **But verify it.** If they turn out to be *independent* — different capabilities, no shared
  contract, no shared blast radius — **say so and hand them to `wai-team`**, which runs each
  through its own lifecycle on its own branch. Do **not** quietly fuse unrelated work into one plan:
  a plan spanning two unrelated changes cannot be reviewed as one unit, and neither can the PR that
  follows it.
- An issue is a starting point, **never a complete spec**. Interview anyway (step 1).

**A plain description** — *"add a rate limiter to the upload endpoint"*. Same flow; nothing to claim.
If it turns out to deserve tracking, file it (§*Where a finding lands*).

**Directives** — constraints on the plan itself:
- *Scope:* "backend only", "no mobile", "just the contract".
- *Depth:* "no ADR", "just the task list", "short plan".
- *Mode:* "grill me" → `references/grilling-protocol.md`.

**A directive is a request, not an override — and you say which you honoured and which you did not.**
"Skip the interview" on a **contract-domain** or **token-economy** change is precisely the case the
interview exists for: ask anyway, and say that you did and why. The human can overrule you a second
time. They cannot overrule a question you never asked.

If `gh` is unavailable or the issue does not resolve, don't invent it: say so, work from what the
human gave you in chat, and note the gap in the plan.

## Process

1. **Interview the requirement (first-class step)** — you have resolved what you were given
   (above); now interrogate it, so that what gets built is genuinely what's needed. Ask the
   human as many clarifying questions as the requirement warrants — grouped and concrete, using
   the question UI — across these dimensions, **skipping any already answered** in the issue or
   context:
   - **Goal & users** — what outcome, for whom, which problem; what does success look like?
   - **Scope & boundaries** — explicitly in-scope vs. out-of-scope; the smallest valuable version.
   - **Acceptance criteria** — how will we know it is done and correct?
   - **Edge cases & failure modes** — empty/large inputs, concurrency, provider outage, retries.
   - **Non-functional** — expected load/latency, AI token cost, data sensitivity, deadlines.
   - **Affected apps & constraints** — one app, several or the shared core? Any documented
     constraint in `docs/` it must respect?
   Don't dwell on questions whose answer is already in the context, and don't block on
   nice-to-know details — but for a genuinely fuzzy requirement, prefer one more round of
   questions over guessing. The answers are the basis of the plan.

   **Grill-me mode** — when the human asks for it ("grill me"), or the
   requirement is high-stakes/fuzzy (contract domain, token economy, new architecture), switch
   to the interrogation protocol in `references/grilling-protocol.md` (in the `wai` skill):
   **one question at a time** in dependency order, each with a **recommended answer**,
   facts looked up in the repo instead of asked, no question cap, and a **hard gate** — no plan
   until the human confirms shared understanding.

   **Offer alternatives when the requirement is imprecise** (both modes): don't just refine
   the stated path — propose **2–3 alternative solution options** with one-line trade-offs,
   including a smaller/simpler variant, and let the human pick or combine before planning.

2. **Determine affected surfaces & platform layer** — Which **surface(s)** does it touch —
   backend, web, iOS, Android, or several? One app, several, or the shared core? New
   app-specific function or platform capability that benefits everyone? In the hybrid topology
   each client is its own repo, so a cross-surface feature becomes coordinated work in several
   repos under one plan. This classification decides tenant isolation, reuse, versioning and
   which repos get a branch.

3. **Decompose functionally & contract-first** — Decompose into components and concrete tasks
   per surface (backend, data model, AI orchestration; the **API/contract** change;
   web/iOS/Android client effects). When clients need new data, **define the contract change
   first** (`references/contract-protocol.md` (in the `wai` skill)) so the clients can be built against it. Make
   dependencies and a sensible order visible — typically the backward-compatible contract +
   backend land before the clients adopt.
   The backend is the **initiator**: run its first version of the contract change through the
   **Contract-Completeness Checklist** in `references/contract-protocol.md` (in the `wai`   skill) *before* handing it to the client repos, so avoidable cross-repo round-trips are removed
   on the drawing board instead of mid-implementation. One round-trip stays **irreducible** — a
   **cross-domain security binding** (client token storage/attestation vs. server verification) is a
   deliberate joint review, not a spec gap — and **contract-domain hand-offs stay human-gated** for
   merge on both sides. The mechanics of crossing the repo boundary (the gitignored mailboxes, the
   pointer-not-payload message) are `references/cross-repo-handoff.md` (in the `wai` skill).

4. **Go through cross-cutting concerns** — Check the requirement against the dimensions from
   `docs/architecture/quality-attributes.md` and record **which of them apply and what
   they concretely require** — each with **catalog ID** (e.g. `AI-9`, `GDPR-1`). Read the
   reference for the details. If the file does not exist in the current repo, point that out
   once briefly (run `wai-init` first if needed, which creates the catalog) and
   work with the cross-cutting concerns directly below it.
   Particularly vigilant about:
   - **API/contract compatibility** — does it need a new endpoint / a new contract version,
     because the three non-updatable clients keep using the old one (`API-1`/`CLIENT-3`)? Does
     Remote-Config suffice (`MAINT-5`)?
   - **Token economy** (`PAY-*`) — does it touch purchase or consumption? Server-side
     verification + idempotent credit/debit, restore, refund clawback, reconciliation. And the
     **digital-goods rule**: tokens must be sold via StoreKit (iOS) / Play Billing (Android);
     Stripe only on web (`PAY-8`).
   - **Cost/FinOps** (`AI-9`/`AI-4`) — do new AI costs arise? Which budgets/quotas/caches are
     needed so that the unit economics hold up?
   - **GDPR** (`GDPR-1`–`GDPR-4`) — is new personal data processed? Does content go to
     external providers (third-country transfer, redaction)? Does it concern minors/
     student data? Do deletion obligations/retention apply?
   - **AI orchestration** (`AI-3`/`AI-5`) — which model/routing, which output validation
     (JSON schema), which fallback on provider outage?
   - **Resilience** (`RES-1`/`RES-3`) — is the operation long-running → asynchronous/queue?
     Does it need idempotency (retry safety)?
   - **Client concerns** (`CLIENT-*`) — for client-facing work: no secrets in the binary,
     attestation, offline/error states, accessibility, safe rendering of model output.
   - **Security** (`SEC-8`/`SEC-3`/`SEC-4`) — new AuthZ rules, new secrets, new attack
     surface (e.g. prompt injection on new uploads)?
   - **Observability** (`OBS-*`) — what must be measured/logged to see success?
   - **Testability** (`MAINT-2`) — how is the non-deterministic AI component made
     deterministically testable, and how are the stores/billing faked?

5. **Architecture decisions & risks** — Where there is a real decision with
   trade-offs (e.g. new service vs. extension, model choice, sync vs. async),
   record it as a short ADR (see below). List open questions and risks
   explicitly, instead of hiding them.

6. **Output the plan, then on approval open the branch** — Output the planning document
   (format below) including the **▶ Recommended next** hand-off, and get the human's approval.
   **Plan proportionally — docs over documents:** a **small, clearly-scoped change** needs no
   planning document at all — clarify it in chat and capture it as a GitHub issue
   (`issues-protocol.md`), then hand straight to `wai-implementation`. A **deep or novel
   requirement** gets the full treatment — and prefer **updating the existing `docs/`**
   (architecture docs, ADRs, contract) over piling up new planning files; write
   `docs/planning/<slug>/plan.md` only for what has no durable home yet. For **architecture
   approaches and changes, lead with a visual diagram** (Mermaid — component/sequence/flow,
   rendered in the output) and keep the prose short; a picture of the data flow beats a page
   of text.
   **Once approved**, write the document to `docs/planning/<slug>/plan.md` (when one is
   warranted) and, per the git protocol, create the requirement branch `agent/<handle>/<type>-<slug>`
   off the latest `main`, commit the plan, and **push it to remote** (`git push -u`) so the
   branch exists locally and remotely. Do **not** open the PR yet — `wai-implementation` opens it once there is an
   implementation diff. **If the requirement came from an issue** (or the human wants one),
   post a short plan summary + the `docs/planning/<slug>/plan.md` path back to the issue
   (`gh issue comment <N>`) and carry the issue number forward so implementation can wire
   `Closes #N` into the PR. Optional — skip cleanly if there is no issue or `gh` is unavailable.

## Delta-update mode (invoked mid-implementation)

When `wai-implementation`'s plan-delta check finds a **material change** (scope or
acceptance criteria moved, a new surface, a contract domain newly touched, the DoD shifted),
it invokes this skill for a **scoped re-plan** — not a fresh full plan:

- Re-plan **only the affected sections** (scope, tasks, cross-cutting IDs, DoD); leave the
  rest of the approved plan untouched.
- Append the result as a **dated delta** to the existing plan document (`## Delta <date>:
  what changed and why`) — or, if the change belongs in the durable docs (contract, ADR),
  update those instead.
- The delta passes the **same approval gate** as the original plan: output it, get the
  human's go, then commit it on the same `agent/**` branch. If the delta pulls the requirement
  into a contract domain, say so explicitly — that changes the merge path (human-gated).
- Stay lean: a delta update is typically a fraction of a page, not a new document.

## Git & PR

**The authority is `references/agent-git-protocol.md` (in the `wai` skill).** What is specific
to *this* skill:

- Once the plan is approved: **create the `agent/<handle>/<type>-<slug>` branch, commit the plan,
  push it.** The **PR is opened later by `wai-implementation`**, not here.
- Cross-surface work uses the **same `<slug>`** in every affected repo, sequenced per
  `references/contract-protocol.md` (contract + backend first, clients adopt).
- **Never commit, push or merge to `main`.**
- **Issues** (`issues-protocol.md`): an issue can be the requirement source — **claim it** if the
  work starts here, so nobody plans it twice — and the plan goes back to it.
- **Where a plan's findings land** (§*Where a finding lands*): the *Risks & open questions*, the
  out-of-scope items, the "we should also fix X" from the interview. Each ends **in the plan**,
  **deliberately rejected** with a reason, or **filed** — there is no fourth outcome. A risk that
  lives only in a document nobody reopens is a risk nobody acts on.
- No git / no `gh` → propose the commit, and list the would-be issues with their commands.
## Output format — planning document

Use exactly this structure:

```
## Requirement: [Title]

### Goal & context
[What is achieved, for whom, which problem. 2–4 sentences.]

### Scope
**Affected surfaces:** [backend / web / iOS / Android — which, and the repos they live in]
**Affected apps:** [one / several / shared core]
**In Scope:** [...]
**Out of Scope:** [...]

### Architecture approach
[Lead with a Mermaid diagram (component/sequence/flow) for anything architectural; then the
chosen solution path in short prose. Components, data flow, model/provider choice. If the
requirement was imprecise: the considered alternatives and why this one won.]

### Testing decisions (seams)
[The seams the feature will be tested at — as high as possible, ideally one (the API contract
is the natural highest seam). Confirmed with the human; wai-testing consumes these
instead of choosing coverage ad hoc.]

### Task decomposition
[Group by surface/repo; lead with the contract + backend tasks the clients depend on.]
1. [Task] — [surface/repo · dependency/order]
2. ...

### Cross-cutting requirements
[Only the applicable dimensions, each with catalog ID and concrete consequence —
e.g. "API-1: new v2 endpoint, v1 remains in place",
"PAY-2/PAY-3: verify receipt server-side + idempotent credit; PAY-8: StoreKit/Play, not Stripe, on mobile",
"GDPR-4: upload may contain student data → check consent + EU processing",
"AI-9/AI-4: ~N tokens/request → budget per user + prompt cache".]

### Architecture decisions (ADR, if relevant)
[See ADR template below — only for real trade-off decisions.]

### Risks & open questions
- [...]

### Definition of Done
- [Verifiable criteria incl. tests, observability, docs, migration.]

### ▶ Recommended next
- [Which skill to run next and on what — typically **wai-implementation** on the tasks
  above (name the first / lowest-risk ones), on branch `agent/<handle>/<type>-<slug>`. Flag any task
  that needs a human decision first (contract domain / high blast radius / open question).]
```

Omit non-applicable sections.

## ADR template (for real architecture decisions)

```
**Decision:** [What is decided]
**Context:** [Why the decision is due]
**Options:** [A, B, (C) — each with trade-off]
**Chosen:** [Option] — because [justification]
**Consequences:** [What this entails, including downsides]
```

Do not write an ADR for trivial decisions — only where a choice with lasting
consequences is made.

## Principles

- **Cross-cutting first** — the main value is to make costs, GDPR, API compatibility and
  resilience visible *before* implementation. Better an uncomfortable question early
  than an expensive rebuild later.
- **Plan proportionally** — a small requirement does not need a 5-page document: chat + a
  GitHub issue suffice. Deep requirements get the full plan — preferring updates to the
  existing `docs/` over new planning files, and diagrams over text walls. Scale depth and ADR
  effort to the significance and irreversibility.
- **Platform thinking** — always check whether the requirement makes sense as a reusable
  platform capability (for future apps) instead of a one-off, app-specific solution —
  without polluting the core with app-specific special logic.
- **Honest about the unknown** — mark assumptions and open questions clearly, instead of
  feigning certainty.

## Related Skills

This skill is the **planning** stage in the lifecycle plan → implement → review:
- **wai-implementation** — takes over the concrete code implementation of the task
  decomposition planned here (each task is an implementation order there); calls back into
  this skill's **delta-update mode** when its plan-delta check finds a material change.
- **wai-pr-review** — later evaluates the resulting PR against the same catalog.
- **wai** — the suite router/overview, if you are unsure where to start or what to run next.
- Shared source of truth for all three: `docs/architecture/quality-attributes.md`. Shared
  protocols (in the `wai` skill): `references/grilling-protocol.md` (in the `wai` skill),
  `references/issues-protocol.md` (in the `wai` skill), `references/contract-protocol.md` (in the `wai` skill),
  `references/cross-repo-handoff.md` (in the `wai` skill),
  `references/agent-git-protocol.md` (in the `wai` skill).
