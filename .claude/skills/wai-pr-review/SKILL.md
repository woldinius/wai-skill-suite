---
name: wai-pr-review
description: >-
  Senior architecture/DevOps review of a pull request or diff against the quality catalog and the
  originating spec, ordered by severity — and owner of the gated auto-merge. A review lens may be
  named at invocation ("review this adversarially", "null-hypothesis", "breadth"); otherwise it
  follows from the change type. Use it to evaluate any PR/diff before merge: "review this PR", "can
  this be merged", "check this diff", "code review", "does this fit architecturally". Not for
  implementing a change (wai-implementation) or planning one (wai-requirements-planning).
license: MIT
---

# PR Review

Evaluate a Pull Request as a Senior Software Architect and DevOps expert against the quality
catalog: a precise, actionable review that finds real risks and orders them by severity — not a
generic checklist comparison.

## Platform context

*(The suite's home platform — the worked example these skills grew against, kept concrete on purpose. `wai-init` scopes the quality catalog to what **your** repo actually is; where your product has none of this — no token economy, no mobile clients, no AI orchestration — read the matching rules as not-applicable, not as findings.)*

The platform is a **multi-surface product**: a **cloud backend** (orchestrates multiple AI
models/providers + owns the server-side **token ledger**) with **Web, iOS and Android** clients,
joined by a **versioned API contract**. Three consequences every review must keep in mind:
- **The three clients cannot be forced to update** → API backward compatibility is critical
  (`API-1`/`API-2`/`CLIENT-3`).
- **AI inference costs money per token** → the cost impact of every change is relevant.
- **The token economy spans client + backend** → purchase verification, idempotent credit/debit,
  refund clawback and digital-goods billing compliance are high-stakes (`PAY-*`); Token/Billing is
  a human-gated contract domain.

## Process

Work through these steps in order. Evaluate what the diff actually touches, and name missing but
necessary aspects as findings.

1. **Understand the change** — What does the PR do, functionally and technically? Which components,
   endpoints, data flows, contracts are affected? If the diff/context is unclear or key files are
   missing, say so and ask specifically, instead of guessing.
   **Locate the spec** — the plan (`docs/planning/<slug>/`), the driving issue, or the PR body —
   and review against it as its own axis: are stated requirements missing, is there scope creep,
   was the right thing built? A diff can pass every standard and still implement the wrong thing;
   if no spec exists, say "no spec available" rather than inventing one.

   **First, check the PR's state — ordering is a thing no artefact watches.** If the PR is already
   **merged** (`gh pr view <PR> --json state`), say so *loudly and up front*: this is a
   **post-merge review** — the gate is **moot**, the strongest outcome is follow-up issues, and if
   you authored the code it is a self-review of your own just-merged work. Name the situation; do
   not run the review as though it could still stop the merge. The merge gate reports the same
   MOOT verdict mechanically — obey it, don't paper over it with a GO/NO-GO.

2. **Classify the change type & surface** — note which **surface(s)/repo** the diff is in
   (backend, web, iOS, Android), then the type(s) that control which dimensions weigh heavily:
   - *API/contract change* → backward compatibility across the three clients, versioning,
     OpenAPI, contract tests (`API-*`/`CLIENT-3`).
   - *Token/billing change* → server-side verification, idempotent credit/debit, refund
     clawback, reconciliation, digital-goods rule (`PAY-*`) — **always a contract domain**.
   - *AI/prompt/model change* → output validation (`AI-3`), prompt/model versioning (`AI-6`),
     cost impact (`AI-9`), PII redaction (`AI-8`), fallback (`AI-5`).
   - *Persistence/data model change* → GDPR (`GDPR-2`/`GDPR-3`), migration, retention,
     idempotency (`RES-3`).
   - *Auth/security change* → AuthN/AuthZ (`SEC-1`), secrets (`SEC-3`), attestation
     (`CLIENT-2`), injection (`SEC-4`).
   - *Client change (web/iOS/Android)* → no secrets in binary/bundle (`CLIENT-1`), attestation
     (`CLIENT-2`), state coverage, accessibility, safe output rendering, and **store-policy
     conformance** (`IOS-3`/`AND-3`) — could it get rejected?
   - *Infra/deploy change* → zero-downtime, rollback, health, observability.
   - *Pure refactoring* → leaner review, focus on clean code, tests.

3. **Choose the review lens** — the stance this review takes (see §*Review lens* below). If the
   human named a lens at invocation, use it. Otherwise derive it from the step-2 classification
   and name the rule that fired. The lens directs *extra* scrutiny; it never replaces the
   dimension walk and never touches the merge gate.

4. **Check the relevant dimensions** — Go through the points from
   `docs/architecture/quality-attributes.md` that match the change type. Read the reference when
   you need the "Red Flags" per dimension, and **cite the affected catalog ID** (e.g. `AI-3`,
   `API-1`) in every finding. If the file does not exist in the current repo, point that out once
   briefly (run `wai-init` first if needed) and work with the platform-critical core points
   directly below it. Pay particular attention to:
   - Does the change break an existing endpoint without a new version? (Three non-updatable
     clients — `API-1`/`CLIENT-3`!)
   - Token/billing: is a purchase trusted from the client instead of verified server-side
     (`PAY-2`)? Can a duplicate webhook or a retry double-credit/double-spend (`PAY-3`/`PAY-4`)?
     Is a refund/revocation not clawed back (`PAY-6`)? Stripe used for tokens on mobile (`PAY-8`)?
   - Client: a secret/provider key in the binary or bundle (`CLIENT-1`)? Attestation missing on a
     protected call (`CLIENT-2`)? A change that risks store rejection (`IOS-3`/`AND-3`)?
   - Is model output passed through unchecked (without schema validation — `AI-3`)?
   - Is there a key/token somewhere in code, config or log (`SEC-3`)?
   - Does personal content go to an external provider without a legal basis/redaction
     (`GDPR-1`/`AI-8`)?
   - Is a mutating or expensive endpoint missing idempotency protection (`RES-3`)?
   - Is asynchronous processing missing for a long-running AI call (`RES-1`)?
   - Does the change noticeably increase token/inference cost without a cache or a budget
     (`AI-9`/`AI-4`)?

   **If the diff touches the quality catalog, lint it**:
   `sh ../wai-init/scripts/catalog-lint.sh` (from this skill's directory — the skills install
   side by side, in a repo and in the plugin cache alike). A new dimension without a Red Flag is
   not reviewable, and a reused retired ID silently rewrites the meaning of every past finding
   that cited it. A red lint is a **Blocker**, not a nit.

5. **Order findings by severity** and output the review in the format below.

6. **Post the review, then merge or hand off.**

   **FIRST, AND ON EVERY PATH: THE REVIEW GOES ON THE PR.** Before the gate, before any merge
   decision, before the hand-off:

   ```
   gh pr comment <PR> --body-file <the review from the format below>
   ```

   Not only in `team` mode, not only when merging, not only when the gate is green — **always**:
   GO, NO-GO, UNKNOWN, Blocker/Major, contract domain, merge denied. **The chat output is a copy
   for the human in this session; the PR comment is the artefact** — a review that lives only in a
   session is invisible to any later reader or approver, and this has happened: the full review
   was produced in chat and posted nowhere, and *the human noticed, not the skill*. The order is
   not negotiable: **post the review → add the gate result → then merge or hand off.** If `gh` is
   unavailable, say so plainly and hand the human the exact command; never silently downgrade to
   "it's in the chat".

   Then the gate. It is a **conjunction of two verdicts**, and you own exactly one of them:

   **Yours — judgment.** Only *Merge* (no Blocker/Major; Minor/Nit or clean) counts as green.
   No script can decide whether a finding is a Blocker; that is why this half stays with you.

   **The script's — mechanics.** Run it and **obey the exit code**:

   ```
   sh scripts/merge-gate.sh <PR>      # from this skill's directory
   ```

   It checks, deterministically: the quality catalog exists · the repo mode · required checks
   exist **and** are green (zero checks is not green) · in `team` mode, that an approval rule is
   **actually enforced** on the base branch · and — by delegating to the shared classifier
   `excluded-domains.sh` (resolved internally as a `../../wai/scripts/` sibling, so the delegation
   works wherever the suite is installed) — that the diff touches **no excluded domain**. The
   excluded domains are defined canonically in `agent-git-protocol.md` §*Excluded domains* (the
   suite guardrail floor, the repo's contract domain, destructive migrations, and **GDPR-erasure /
   hard-delete**) — this skill keeps no copy of the set; it obeys the classifier's exit code. The
   repo-specific half (which paths *are* the contract domain, where migrations and erasure modules
   live) comes from `docs/architecture/merge-gate.conf`, written by `wai-init`.

   The script **appends every verdict** to `docs/architecture/gate-ledger.md` — do not log it
   yourself, and never backfill or edit a past row; a verdict with no ledger row means it was never
   run. The human tags each row's outcome (`ok`/`fp`/`fn`) later; the file explains how. Read the
   numbers with `scripts/gate-stats.sh`.

   - `exit 0` **GO** → and your review is clean → merge (see *How* below).
   - `exit 1` **NO-GO** → a precondition failed. **The human merges.** Append the reasons **to the
     review comment on the PR** — that is where the decision is made.
   - `exit 2` **UNKNOWN** → something could not be verified (no `gh`, no catalog, no config, an
     unresolvable repo or PR). **The human merges.** There is no path from "I could not check" to
     "go" — and note that UNKNOWN is a bug report about the *gate*, not a finding about the code:
     say which of the two it is when you report it.

   **Do not re-derive the script's answer in prose, and never overrule it.** The whole point is
   that "the model checked" becomes an artefact you can audit. If the script is unavailable
   entirely (no shell, foreign checkout), say so plainly and hand the PR to the human — do not
   fall back to checking from memory.

   **How** it merges, once both verdicts are green — by **repo mode** (from the catalog header;
   missing = `solo`):
   - **`solo`** → **merge the PR to `main`** (`gh pr merge`) and delete the branch.
   - **`team`** → **never merge it yourself.** The verdict is already on the PR; arm GitHub's
     native auto-merge (`gh pr merge --auto`, branch deletion on). The PR then merges *by
     itself* once branch protection is satisfied — which in team mode includes **one approving
     review from another human**. The script has already verified that this wall exists; without
     it, `--auto` would merge *immediately* while your report claimed to be waiting for a human.

   **Once per run, before relying on `Closes #N` or reporting any merge as done:** check that the
   merge target is the repository's **default branch** (`gh repo view --json defaultBranchRef`).
   If it is not, warn loudly — a merge into anything else looks identical to success while every
   `Closes #N` silently fails to fire — and **never change the repo setting**: the default branch
   is the human's, however wrong it looks.

   **After any merge this skill performed, "merged" in the report means ARRIVED — verify it.** Run
   `sh ../wai/scripts/verify-arrival.sh <mergeCommit>` (from this skill's directory — a sibling
   path, like the classifier's) and obey the exit code. **Exit 0 — ARRIVED:** the merge commit is
   reachable from the freshly fetched `origin/<default>`; only now may the report say "merged".
   **Exit 1 — LOST:** the forge says MERGED but the default branch never received the commit — a
   stacked PR merged into a dead base looks exactly like success — so say so loudly, up front, and
   hand it to the human together with the branches the script names as containing the commit.
   **Exit 2 — could not verify:** fail closed — report "merged, arrival unverified", never "done",
   and hand it to the human. After arrival, verify each issue the PR claims to close is actually
   **CLOSED** (`gh issue view <N> --json state`) instead of assuming: `Closes #N` fires only on a
   merge into the default branch, and an issue that stayed open is a signal, not a formality.

   **Never approve a pull request — not your own, and not a colleague's.** Never run
   `gh pr review --approve` on any PR, in any mode. Your verdict is a **comment**; the approving
   review is a human's. An agent that could approve *someone else's* PR would satisfy the
   "1 approving review" gate mechanically and merge work no second human ever read. (GitHub
   ignores an author's own review anyway, so a your-own-PR-only rule would protect nothing.)

   In either case, apply the **landing rule** (`issues-protocol.md` §*Where a finding lands*):
   every finding ends **fixed in this PR**, **deliberately rejected** with a stated reason in
   the output, or **filed as a GitHub issue** — there is no fourth outcome. So file the
   outstanding Minor/Nit findings as issues (format, labels, `**Skill:**` source and dedupe per
   the protocol) rather than only listing them.
   **Blocker/Major findings are the human's decision point**: present them with your
   recommendation and wait — do not silently fix them. The decision routes each one into
   fixed / rejected / filed ("collect as issues and show me at the end", "fix directly" →
   `wai-implementation` on the same branch, then re-review). Filing is what happens to whatever
   is left when the run ends, so that no finding dies with the session.
   **If the environment denies the merge** (permission gate/classifier refuses `gh pr merge`,
   typically for a same-session PR): don't fight it — the verdict is already on the PR, so label
   the PR `ready-to-merge`, list it in a short merge queue for the human, and move on. If `gh`
   is unavailable entirely, fall back to the proposed merge + the findings listed in the review.

   **Last: check that it landed.** `gh pr view <PR> --comments` — is the review actually visible
   on the PR? "I posted it" is a memory; the comment is the evidence. If it is not there, post it
   again before you report the run as done.
   (The run-log row for this skill is written by `merge-gate.sh` itself — do not log it again.)
   **Then derive the closing state:** run `sh ../wai/scripts/open-items.sh` (from this skill's
   directory — a sibling path, like the classifier's), paste its output verbatim beneath the
   ▶ Recommended next block, then give your recommendation — in that order: the script derives
   (exit 0 = emitted; exit 2 = nothing derivable — then say `not checked` yourself), the model
   recommends.

## Review lens

A lens is the **stance** the review takes — what it goes hunting for first and what it refuses to
take on trust. Three exist:

- **`null-hypothesis`** — assume the change *does nothing*. The diff must prove its own effect:
  which line makes the claimed behavior happen, and which test would go red without it?
- **`adversarial`** — assume someone wants to *abuse* it. Every input attacker-controlled, every
  trust boundary the diff crosses an invitation. (This diff's attack surface — the whole-codebase
  sweep is `wai-security-audit`.)
- **`breadth`** — assume the important part *isn't in the diff*. Call sites, the other clients,
  contract artifacts, migrations, config, rollback — and the omission.

**Selection.** If the human names one at invocation (`wai-pr-review adversarial`, "review this
adversarially", "breadth"), that wins; several may be named and are then run in sequence. Otherwise
derive it from the step-2 classification, first match wins:

| Classification | Lens |
|---|---|
| The API contract or a client-facing schema changed | `breadth` **+** `adversarial` |
| Contract domain (see the canonical list in step 6), security, or AI/prompt change | `adversarial` |
| Bug fix — the PR claims to repair a defect | `null-hypothesis` |
| Anything else — feature, client change, refactor, migration, infra/deploy | `breadth` |

The first row exists because `adversarial` alone would fire on a contract change and hunt abuse —
while the question that actually matters (*do the three clients that cannot be force-updated still
parse this?*) lives in `breadth`. So run both.

`wai-team` batches and the merge-queue delta re-review have no human invocation per PR, so
they take the derived default; a queue entry keeps the lens of its first review.

**The lens is additive.** It never narrows the dimension walk and **never changes the merge
gate** — the contract-domain gate, the Blocker/Major decision point, the green-checks condition
and the absolute rule that skills never approve a PR hold under every lens. A lens can make a
review sharper, never laxer. **Declare it** in the output (`**Lens:**`), with the rule that
selected it: a review whose stance cannot be reconstructed afterwards is not reproducible.

Read `references/review-lenses.md` for the active lens's hunt list before step 4 — only the
section for that lens.

## Merge-queue mode (serial integration)

When several ready PRs wait for integration — typically handed over by `wai-team`, or because
reviews piled up — process them as a **queue, one at a time**: each PR was reviewed against a
`main` that stops existing the moment its siblings merge; two individually green PRs can be wrong
together. Per PR:

1. **Rebase** onto the fresh `main`. If it doesn't apply cleanly, don't guess a resolution —
   park the PR for the human and continue with the next.
2. **Re-run the required checks** on the rebased state.
3. **Re-review the delta** — light, focused on what the rebase changed and on interactions
   with the just-merged siblings (same modules, same contract, same migrations); not a full
   re-review when nothing overlaps.
4. **Apply the normal merge policy** (above — including the Blocker/Major decision point and
   the contract-domain gate). This mode adds **no new merge authority**; it is the same gate
   applied serially.

Never merge two queue entries without re-running checks in between, and never parallelize
contract or migration PRs through the queue.

**In `team` mode the queue does not merge inside your run — so don't pretend it does.** Queue
entries are PRs whose interaction you are serializing; `gh pr merge --auto` fires whenever *its*
PR turns green and approved, in whatever order humans approve, which would defeat exactly that. So
arm **only the head**, and don't arm the next until the head has actually merged. Since the head
waits on a human approval that may not come during this session, the normal outcome is: **arm the
head, hand the rest to the human as a `ready-to-merge` list** (in queue order, with the rebase
state noted), and end the run honestly. Enabling *Require branches to be up to date before
merging* in the ruleset gives you a server-side backstop.

## Severity levels

- **Blocker** — must not be merged: security vulnerability, GDPR violation, an ad-hoc
  data-erasure path that is not human-gated (the EX-GDPR patterns — defined once in
  `agent-git-protocol.md` §*Excluded domains* and detected by `excluded-domains.sh`; this skill
  keeps no copy), breaking change without versioning, data loss risk, missing idempotency on a
  payment-related mutation (`RES-3`).
- **Major** — should be fixed before merge: missing output validation, missing error/timeout
  handling of external calls, missing tests at a risky spot, a material uncapped cost impact.
- **Minor** — can be addressed soon: observability gap, unclear modularization, missing docs.
- **Nit** — style/cosmetics, optional.

Assign severity levels honestly. If a PR is clean, say so clearly and do not block artificially.
Justify every finding with the concrete risk (why), not just with the rule, and anchor it to the
catalog ID (e.g. `SEC-3`), so it remains verifiable.

## Output format

**Destination: a PR comment (`gh pr comment`), plus a copy in the chat — in that order.** The PR
comment is the artefact; the chat is the copy.

Use exactly this structure:

```
## PR Review: [Short description of the change]

**Classification:** [change type(s) · surface(s)/repo · affected components]
**Lens:** [null-hypothesis | adversarial | breadth (| several)] — [requested, or the rule that selected it]
**Recommendation:** [Merge | Changes required | Blocked]

### Blocker
- [File/spot] · [Catalog ID] — [What is the problem] → [Concrete risk] → [Recommended fix]

### Major
- ...

### Minor
- ...

### Nits
- ...

### Positives
- [What the change solves well — briefly, but name it]

### Open questions
- [What you could not judge from the diff and would have the author clarify]

### ▶ Recommended next
- [**Outstanding Minors/Nits filed as issues** (link them) — this happens on *every* path, merged
  or not: a finding that only lives in this review dies with the session.
  Then: Only Minor/Nit (or clean) & non-contract-domain with green checks and a catalog → in
  **`solo`**: **merged to `main`**, branch deleted; in **`team`**: **auto-merge armed — the PR
  merges itself as soon as another human approves it** (I don't merge and I don't approve; armed
  only because an approval rule is actually enforced on `main`).
  Blocker/Major → **your decision point**: fix now (wai-implementation on the same branch,
  then re-review), file as issues, or block — with my recommendation first.
  Contract-domain / flagged / no enforced approval rule / merge denied by the environment →
  **left for your merge** (labelled `ready-to-merge`) with the risk note and what was missing.]
```

Omit empty sections. If no blockers/majors exist, make that clear in the recommendation.

## Principles

- **Review proportionally** — a 10-line refactoring does not need a GDPR assessment. Scale the
  depth to the risk and scope of the diff.
- **Concrete instead of general** — point to the spot and name the fix, instead of just "mind
  security".
- **Platform thinking** — does the change pull app-specific special logic into the core or
  violate tenant isolation?
- **Do not guess** — when context is missing (schema, calling sites, configuration) name the
  assumption or ask, instead of inventing a finding.
- **Merge policy — auto for clean & safe, human for risky** (full rules in Process step 6).
  Merging `main` ships a release, so when in doubt it waits.
- **A lens sharpens, it never loosens.** Whatever stance the review takes, it ends at the same
  gate: no finding is downgraded and no dimension skipped because a lens was chosen.
- **Every finding lands somewhere** — fixed, deliberately rejected with a reason, or filed as an
  issue (`issues-protocol.md` §*Where a finding lands*). A finding that only exists in this chat
  is lost work.
- **Skills never approve a PR — not their own, not a colleague's** (`agent-git-protocol.md`,
  the authority for the branch/merge rules this skill applies). A verdict is a comment.
- **In a `team` repo the agent is never the only reviewer** — it arms `gh pr merge --auto` and
  lets branch protection hold the PR until another human approves: tempo without a babysitter,
  while "no human ever looked at it" stays impossible.

## Related Skills

This skill is the **review** stage in the lifecycle plan → implement → review:
- **wai-requirements-planning** — when a requirement should first be planned/shaped before code
  exists.
- **wai-implementation** — when a finding should be implemented directly.
- **wai** — the suite router/overview, if you are unsure what to run next.
- Own reference: `references/review-lenses.md` — the hunt list per review lens (read only the
  section for the active lens).
- Shared source of truth: `docs/architecture/quality-attributes.md` (its header carries the
  **`Repo mode:`** line this skill's merge decision depends on). Branch/merge authority:
  `references/agent-git-protocol.md` — identity & repo mode, the gated merge, the canonical
  §*Excluded domains* set that `merge-gate.sh` delegates to via `excluded-domains.sh`, and the
  absolute rule that **skills never approve a PR**. Contract rules:
  `references/contract-protocol.md`, issue rules: `references/issues-protocol.md`, interrogation:
  `references/grilling-protocol.md` (all in the `wai` skill).
