---
name: wai-init
description: >-
  Bootstrap and re-runnable updater for the wAI suite: deep-scans a repo, then writes its
  surface-scoped quality catalog (`docs/architecture/quality-attributes.md`) and testing strategy,
  sized to the project. Asks the setup questions — solo or team, protect `main`, docs language,
  catalog tier, learning mode — BEFORE writing what they configure, and keeps existing docs unless
  you ask for a reset. Use it to set the suite up, or to reconcile it later: "set up the skills",
  "initialize the project", "onboard this repo", "create/update the quality catalog", "bootstrap",
  "tune the skills". Not for planning, implementation or PR review — it only lays the foundation.
license: MIT
---

# Init (bootstrap & update)

Set up the wAI skill suite in a repo — and **reconcile it later without destroying anything**.
The value: a deep scan of the real project, and from it a **quality catalog tailored to the repo and
its tech stack** under `docs/architecture/quality-attributes.md` — the shared source of truth that
`wai-pr-review`, `wai-requirements-planning` and `wai-implementation` read at runtime.
Re-running is normal (new baseline, evolved stack, updated suite): existing files are **live
documents** — changes arrive as a diff proposal that preserves local tailoring, custom IDs and the
human's edits, never a silent rewrite.

## What this skill produces

- `docs/architecture/quality-attributes.md` — the **live catalog**, copied from the **variant
  seed** that fits the repo — `references/quality-attributes.platform.md` (full multi-surface
  build) · `.web.md` (backend + web frontend) · `.minimum.md` (core software engineering) — then
  adapted to the project and **sized** to it (scope fine-tuning + tier —
  `references/catalog-sizing.md`). The variants are **generated** from the master
  `references/quality-attributes.baseline.md` by `scripts/catalog-variant.sh` (ADR-0004): edit
  the master, regenerate, never a variant. Obey its exit code: `exit 0` = the variant was
  generated · `exit 2` = **UNKNOWN** — it could not be generated (bad variant name, unreadable or
  structurally unexpected master); it fails closed, so never work from partial output. It has no
  exit 1 — it renders no verdicts.
- `docs/architecture/testing-strategy.md` — the testing strategy, at the same tier.
- A **connection check** (read-only): git repo? which **forge**? is `gh` installed/authenticated, are
  Issues reachable? Reports state + one-time setup steps; never logs in or mutates the remote.
- An **AI-readiness check**: the repo properties that decide whether *any* agent can work here
  (build/test commands discoverable, generated dirs ignored, no secrets in the tree, a `CLAUDE.md`
  naming the stack). A proposal list — never applied silently.
- The **setup decisions**, asked once (step 4, before anything is written) and recorded so a re-run
  doesn't re-ask: solo/team · protect `main` · docs language · artifact tier · learning mode.
- A **linted** catalog: `scripts/catalog-lint.sh` runs after every write.
- `docs/architecture/merge-gate.conf` — the merge gate's only repo-specific input (which paths are a
  contract domain, where migrations live). Without it, nothing is agent-merged.
- `docs/architecture/coordination.conf` — **only when the setup calls for it** (team / multi-repo):
  the autonomy + cross-repo-comms config. A **proposal**, **contract-domain and self-protecting** —
  like `merge-gate.conf`, a later change is a PR the human merges deliberately.
- **Mined catalog candidates** — recurring concerns read from the repo's **issue/PR history**
  (read-only, numbers only) as a proposal to sharpen a Red Flag or mint a local dimension. Never
  auto-added.
- A **setup report** (format below).

This skill is **allowed to be heavy** — it runs once per repo, or rarely. The catalog it writes is
read at runtime by **every other skill**, so its size is the single biggest lever on the suite's
token cost (see *Sizing*). Spend the tokens here; save them everywhere else.

## Stance

- **Idempotent & re-runnable.** If an artifact already exists, **don't overwrite silently** — treat
  it as the live document, scan again and deliver a **diff proposal that preserves local tailoring and
  custom IDs**, then wait for "go". A **reset** (regenerate from the baseline) happens **only** on
  explicit request — the default is always *keep*.
- **Scan before writing.** Understand the project first — the catalog is a contract document.
- **Detect, don't interrogate.** Anything determinable from the repo (greenfield vs grown, forge,
  stack, commits since setup) you **determine**, state, and let the human correct. Only genuine
  decisions become questions.
- **Tailoring, not blind copying.** The baseline is the starting point, not the result.
- **Never commit or push.** Created files are a visible proposal; the human commits.

## Sizing — the catalog is the suite's token budget

The bundled baseline is the **full** tier: **91 IDs, ~530 lines** (checkable with `grep -c`/`wc -l`;
no token count is stated because a figure nobody re-measures becomes a false claim). Every skill reads
the catalog at runtime — routinely larger than the skill reading it — so its size is the biggest
lever. **The coarse cut comes first — the variant** (ADR-0004): **platform** (the full build —
the only variant carrying `IOS-*`/`AND-*`/`PAY-*`/`AI-*`, so every mobile or token-selling repo
starts here) · **web** (backend + frontend — no AI integration, no token economy, no store
surfaces) · **minimum** (core software engineering — `MAINT`/`SEC`/`GDPR` + `RES-3`). Pick the
smallest variant whose concerns the repo actually has — but **"not yet" is not "not
applicable"**: a project that *plans* to sell tokens starts from `platform` with `PAY-*` softened
to a target, not from `web`. **Then two independent dials, and confusing them breaks the suite:**
**scope** fine-tunes *which* IDs survive within the variant (an iOS repo drops `AND-*`/`WEB-*`);
**tier** decides *how much prose* each surviving ID carries — **shorter entries, never fewer
guarantees**. **The Red Flag survives every tier.** **Read `references/catalog-sizing.md` before step
4** for the tier table, the surviving core, the honest arithmetic (~40 core IDs) and the tailoring
rules.

## Process

1. **Deep repo scan** — get a solid picture (see scan checklist) from manifests, configs and the
   directory tree, not assumptions.

   **Determine greenfield vs grown yourself — never ask.** `git rev-list --count HEAD` plus the
   tracked-file count settles it. It changes *how you write*, not *whether you scan*:
   - **Greenfield** → the catalog is a **target**; no existing Red Flags, the testing strategy is a
     plan.
   - **Grown** → the catalog must be **honest about the present**: note which dimensions the code
     **already violates** and carry them into the report as existing Red Flags. A catalog that
     describes an ideal the repo isn't teaches every review to ignore it.

   State your conclusion ("340 commits, a TS monorepo — treating this as grown") and let the human
   correct it. A statement, not a question.

2. **Identify the surface & pick the variant seed** — detect which surface(s) this repo is, then
   start from the matching **variant** (see *Sizing*): a token-selling or AI-integrating product,
   and every mobile repo, starts from `platform` (the only variant carrying
   `IOS-*`/`AND-*`/`PAY-*`/`AI-*`); a backend+web product without those starts from `web`; a
   library, CLI or plain service starts from `minimum`. Then **scope within the variant**: from
   `platform`, an iOS repo keeps `IOS-*` + `CLIENT-*` + core and drops `AND-*`/`WEB-*`, an Android
   repo the mirror; backend+web keeps `AI`/`RES`/`OBS`/`PERF`/`WEB` **+ `CLIENT-*`** — the web app
   *is* a client: no provider key in its bundle, and it can be stuck on an old contract too.
   `CLIENT-*` drops only for a repo shipping **no** client. Then check fit: fits a surface → adopt
   + tailor; fits **partially** (no token sales yet, no multi-tenant) → adapt/soften and **justify
   in the report**; a concern the repo genuinely does not have → the smaller variant already
   omitted it, say so in the report.

3. **Existing artifacts: keep by default, reset only on request.** Before writing, check whether the
   catalog and testing strategy exist.

   **First: real catalog or untailored seed?** A file that exists is not a *decision*. Compare against
   `references/quality-attributes.baseline.md`: if it is substantially the baseline (same IDs, no
   surface scoping, no local edits) then **nobody tailored it** — treat it as **new** and run the full
   flow. A pre-filled header (`Repo mode`/`Tier`/`Docs language`) does **not** count as an answer if
   the file was never tailored.

   If it *is* a real, tailored catalog:
   - **Default: keep.** Deliver only a **diff proposal** that preserves local tailoring, custom IDs and
     edits. Do **not** re-ask tier or attributes — decided at creation.
   - **Offer a reset explicitly**, *keep* pre-selected: "The catalog exists (91 IDs, ~530 lines) — keep
     and propose updates, or reset and regenerate?" **A reset discards the human's tailoring** — name
     that cost. Only a clear yes resets.
   - Only on **new or reset** does step 4 ask scope and tier.

   **On every reconcile, run `scripts/catalog-lint.sh` first and act on it.** Red Flags it calls
   *recoverable* → copy from the baseline (no authoring). Local dimensions inside the baseline's number
   space → declare under `## Local IDs`; renumbering breaks existing citations.

   **Then the judgment no script can make.** For every ID in **both** this catalog and the baseline,
   ask: *do they mean the same thing?* A number meaning one thing here and another upstream is a
   **semantic misbinding** — the reference resolves, nothing fails, no checker sees it. **You are the
   only control.** Where they diverge, report both meanings and let the human choose (both permanent);
   write the choice into **`## Reused Baseline IDs`** — a different debt from `## Local IDs`: that one is
   fixable, this one is a translation table forever. → `references/catalog-sizing.md`, *ID provenance*.

4. **Setup questions — ask BEFORE you write anything** (once each; skip what's decided). These are the
   human's genuine decisions and **inputs to the catalog, not a postscript**: the step-6 header carries
   repo mode, tier and docs language. Guess them and you either rewrite a document you presented as
   final, or silently keep the guess — and a guessed `Repo mode: solo` disables the team merge gate for
   this repo's life. Ask first, then write.

   **Question economy.** The UI takes at most 4 questions/round. **Never ask what you detected**
   (greenfield/grown, forge, stack, surface — those are statements), skip anything in the catalog
   header, and **skip variant, tier and scope when an existing catalog is kept** (step 3). A first
   run's **Round
   1** asks: **variant + scope · tier · solo/team · docs language** (with `main` protection folded
   in). Learning
   mode is asked last (step 11). A typical re-run asks nothing.

   **Round 2 — only when the repo needs it.** A solo prototype is done after Round 1: **autonomy off,
   comms none** recorded silently, never asked. A **team / multi-repo / real-merge-gate** repo gets one
   short round *before writing*, at most two questions — **autonomy on/off** (default no) and the
   **coordination tool**. That machinery only earns its keep where more than one agent or human
   coordinates.

   - **Docs language?** — **Default: English.** Two non-negotiables: **the skills themselves stay
     English** (shared source, read by other sessions), and **IDs and section names stay English and
     stable** (`SEC-3`, `PAY-2`, `Red Flag`) even if prose is translated — a translated key breaks every
     review that cites it. English is the default because the catalog is a contract document quoted by
     English skills; a translated copy drifts on every re-run. If the team will actually use it in their
     language, take that for the prose and say so. **The repo's `README.md` stays untouched** — offer
     only to *append* a pointer, as a proposal.
   - **Solo or team?** — becomes the **`Repo mode:`** line (`solo`|`team`) the git protocol reads for
     the merge gate and branch naming. Detect a default (`git shortlog -sne --since='6 months'`) and
     offer it; the human decides. **Missing = `solo`.** In **`team`**: `wai-pr-review` never merges
     directly — it arms auto-merge and waits for **one approving review from another human**; propose a
     `CODEOWNERS` with the team's contract owners, never the PR author alone.
   - **Protect `main`?** — **Recommended: yes.** On yes, propose a branch-protection ruleset (require a
     PR, block direct/force pushes; in `team` mode also **require 1 approval** + dismiss stale; via repo
     settings or `gh api`, approval-gated). **If the plan forbids rulesets** (403 on free-plan private
     repos), say so and fall back to the **advisory gate** — the git protocol is then the only wall;
     record it so green checks aren't mistaken for enforced ones. In `team` without a ruleset, "second
     human approves" is a convention, not a wall.
   - **Variant, scope and tier** (see *Sizing*). Ask at a level a human can judge: **the variant,
     with your detection as the recommendation** ("backend+web, no AI provider, no payments in the
     manifests → the `web` variant; if token sales are planned, `platform` with `PAY-*` as a
     target"); **scope** only where the variant leaves a real choice (drop `AND-*` in an iOS repo);
     **tier** — recommend one from the tier table with the reason, never Minimal for a repo
     touching money, auth or personal data. The variant decides *which sections*, scope *which
     IDs* within them, tier *how much prose*. **Skip all three when a catalog is kept.**
   - **Autonomy? (Round 2 only)** — "Should this repo ever let the suite *integrate* merged,
     gate-passed work without pausing for you?" **Default: no** (fail-closed; missing/empty config =
     off). On **yes**, the six always-excluded **policy domains are pre-selected and non-removable** —
     payment/token/billing · auth/login · API/contract · security · destructive migration ·
     **GDPR-erasure / data-deletion** — the human may only **WIDEN**. **Anchor by DOMAIN NAME, not a
     bare catalog ID** (a copied number misbinds across the template→repo boundary); resolve a wanted ID
     anchor against *this* repo's catalog by name at write time. Goes into `coordination.conf` (8a).
   - **Coordination tool? (Round 2 only)** — "When agents or repos hand off, which channel carries the
     *notification*?" Record **tool-agnostically**: `none` (safe default — file-based `temp/` handoff)
     or a named chat/webhook transport. Store only the **channel** and the secret's **environment-
     variable NAME** — **never a literal token** (`SEC-3`): the channel only notifies, the spec stays in
     the repo. Detect a default by grepping CI workflows for an existing webhook reference (the name).

5. **Tailor the catalog** (tailoring rules below) — keep applicable dimensions, remove/soften
   unsuitable ones, add missing tech-stack attributes with **new IDs**, adjust prioritization. Generate
   at the agreed scope and tier: a smaller tier means **shorter entries, not fewer guarantees**. IDs are
   never invented to fill a tier nor dropped to hit one.

5a. **Mine issues & PRs for catalog candidates** (setup *and* re-run). For each signal from
   `scripts/mine-issues.sh` that is a **real recurring concern**, make the call no script can — one of
   four: **extend** an existing dimension (sharpen its **Red Flag**; never renumber) · **mint a new
   local dimension at ID ≥ 100** under `## Local IDs` · **propose upstream** if cross-surface (mint
   locally at ≥ 100 as a stopgap, say so) · **drop**. **The ID boundary is the trap** (*ID provenance*):
   an issue/PR is **local space** — never copy a baseline two-digit ID onto a mined concern, and read
   any ID *inside* an issue as resolving against **this** repo's catalog. Deliver an **additive diff
   proposal** (nothing committed); **dedupe** on re-run. The ≥ 100 rule and template rebind already ride
   `catalog-lint.sh` (checks 7 and 6), so **add no mining lint**.

6. **Write** — create `docs/architecture/quality-attributes.md` (or propose a diff). Set state,
   version, **repo mode, tier and docs language** in the header.

   **A kept catalog from before these fields existed:** don't invent answers, don't re-ask. Infer what
   is safely inferable; a **missing field keeps its documented default** (`Repo mode` absent = `solo`).
   Read the tier off the file itself; if it matches none cleanly, omit the field rather than force one.

   **Then lint what you wrote:** `sh .claude/skills/wai-init/scripts/catalog-lint.sh` — every
   dimension has a **Red Flag** (without one it isn't decidable), no **retired ID** reused, no skill
   cites a missing ID. Obey the exit code: `exit 0` = internally consistent · `exit 1` = a check
   failed and the reasons are printed — a **stop**, fix them before anything reads the catalog ·
   `exit 2` = the catalog could not be read at all (**UNKNOWN**) — nothing was verified, so find the
   file rather than proceed as if it passed. This is the check that would have caught 55 undecidable
   dimensions on day one.

7. **Testing strategy** — write `docs/architecture/testing-strategy.md` at the **same tier** (default:
   build e2e-testable, security/billing as mandatory targets). If it exists, step 3 applies. Get it
   approved.

8. **Merge-gate config** — write `docs/architecture/merge-gate.conf` from the template in
   `wai-pr-review/scripts/merge-gate.conf.template` (read it — format + fail-closed contract). It
   holds the **only** repo-specific gate input: which paths are a **contract domain**, and where
   **migrations** live.

   **Derive the globs from the scan** — where auth, billing, user management, DTOs and migrations live;
   **this repo's own rule-defining documents** (release-status doc, invariants file, ADRs, threat
   model); and **the gate's enforcement chain where it leaves the beaten track** (follow one gate
   command down — `pnpm lint` → `package.json` → `eslint.config.mjs` → a custom rule). Ask once: *which
   file here, if an agent quietly edited it, would make a bad change look acceptable — or a broken gate
   look green?* — **present as a proposal**. **Start conservative**: too wide costs one click, too
   narrow auto-merges a billing change.

   Without this file the gate returns UNKNOWN and **nothing is agent-merged** — the intended failure
   mode, so it's not optional for a repo that wants the gate. It protects itself: `merge-gate.conf` is
   in the gate's hardcoded guardrail floor, so a later change is a **contract-domain PR the human merges
   deliberately** — the config deciding what an agent may merge must not be one an agent can quietly
   merge.

8a. **Coordination & autonomy config** — **only when Round 2 was asked** (team / multi-repo /
   real-gate). Write `docs/architecture/coordination.conf` from `scripts/coordination.conf.template`
   (read it — **parsed, never sourced**, fail-closed). Like `merge-gate.conf` it is a **proposal the
   human commits**, **contract-domain**, and self-protecting.

   It records `AUTONOMY_ENABLED` (default **no**); `AUTONOMY_EXCLUDED` — the policy floor anchored **by
   domain name** (never a bare catalog ID); **`AUTONOMY_SAFE_PATHS`** — the *allowlist* a diff must fall
   entirely inside to be autonomy-eligible; **`AUTONOMY_AFFIRMED`** — the human-affirmation date/hash;
   and `COMMS_TOOL` / `COMMS_CHANNEL` / `COMMS_WEBHOOK_ENV` (env-var **name** only). **Path-based
   exclusions are inherited from `merge-gate.conf`** (`CONTRACT_PATHS` / `MIGRATION_PATHS` /
   `ERASURE_PATHS`), never duplicated.

   **The allowlist is fail-closed, and that is the whole safety of the feature.** If
   `AUTONOMY_ENABLED=yes`, then `CONTRACT_PATHS`, `ERASURE_PATHS` **and** `AUTONOMY_SAFE_PATHS` must be
   **non-empty** *and* `AUTONOMY_AFFIRMED` present — else **autonomy stays off**. An empty exclusion
   surface is not "nothing to exclude", it is "we don't yet know what's safe", and the safe reading of
   not-knowing is *don't*. Run `scripts/coordination-lint.sh` and obey it: `exit 0` = consistent —
   or the file is simply **absent**, which is the safe default (autonomy off, comms none) ·
   `exit 1` = a check failed, printed without ever echoing a secret value — a **stop**, autonomy
   stays off until it is green · `exit 2` = **UNKNOWN**: the conf/catalog is unreadable or the
   policy-domain floor could not be sourced — a config that cannot be verified must never be
   trusted to arm autonomy, so fail closed and leave it off. Write the
   **`## Autonomy exclusions`** catalog anchor section **only when autonomy is enabled** (proportional).

9. **Verify the connection (read-only) & offer setup** — the lifecycle skills work on `agent/**`
   branches, open PRs and **file findings as Issues** (`references/issues-protocol.md`), so check the
   plumbing with **read-only** probes: `git remote -v` (origin? which forge?); `gh auth status`
   (installed/authenticated? don't print tokens); `gh repo view --json nameWithOwner,hasIssuesEnabled`
   + a light `gh issue list -L 1`.

   Record the result. **If something is missing, don't fail and don't auto-fix** — surface the exact
   one-time steps and **ask** whether to set up now or proceed catalog-only: no `gh` → install +
   `gh auth login`; no GitHub remote → `git remote add origin <url>`; Issues disabled → enable; and
   **offer to create the labels** the suite files with — approval-gated, but the **whole set** (severity
   `blocker`/`major`/`minor`/`nit`; type `bug`/`feature`/`improvement`/`tech-debt`/`follow-up`/`audit`;
   plus `security` and `in-progress`). Not cosmetic: `gh issue create --label minor` **fails** on a
   missing label, and a skill told never to block then silently drops the finding. Map onto an existing
   scheme if there is one. The suite degrades gracefully without `gh`, so this step is **recommended,
   not blocking** — never run `gh auth login` or change the remote yourself.

   **Not GitHub? Say so plainly — do not rewrite the suite.** **GitHub is a design constraint, not a
   config value**: `gh`, PRs, Issues, Actions, rulesets, `CODEOWNERS` and auto-merge are woven through
   the protocols and skills. Report honestly — **does not work:** gated/auto merge, the Issues
   round-trip, `wai-cicd`/`wai-mobile-release`, `wai-team`'s mandate; **still works:**
   the catalog, `wai-requirements-planning`, `wai-implementation` (the PR becomes a *proposed*
   body), `wai-testing`, both audits, `wai-learning-gap`. Then let the human decide; offer nothing you
   can't deliver.

   **The comms tool always degrades to the file-based default.** When `COMMS_TOOL=none`, `gh` is
   missing, or the forge isn't GitHub, cross-repo handoff and any notification fall back to the
   **file-based `temp/` handoff** (and Issues where they work). **No secret is ever posted to a channel**
   (`SEC-3`): the channel carries a pointer, the spec stays in the repo.

10. **AI-readiness check** — the properties that decide whether *any* agent can work here. Check, then
   **propose** (never apply silently): a **`CLAUDE.md`** naming the stack + build/test commands (the
   single highest-value fix); **generated/vendored dirs gitignored** (`node_modules`, `dist`, `build`,
   `.next`, `Pods`, `DerivedData`, coverage — tracked, they poison every search); **no secrets in the
   tree** (flag loudly, don't print values, don't "fix" by deleting — a committed secret needs
   rotation, the human's call); **a committed lockfile** + pinned toolchain. One line each with the
   reason; the human applies them.

11. **Learning mode — for you, not for the repo.** Asked last, because it configures the human. Ask
    **only about the human running init**: "Are *you* learning this stack and want learning gaps after
    your implementation phases?" On yes, hand off to `wai-learning-gap`, which creates **that person's**
    ledger under `~/.claude/learning/<repo-slug>/` and their local hook. **Never write a name, a
    self-assessment or an activating switch into `CLAUDE.md`, `docs/` or `.gitignore`** — a committed
    switch turns the mode on for everyone (git protocol §*Personal state never becomes repo state*). You
    may propose the **neutral, non-activating** `## Learning mode (per developer, opt-in)` section. On
    no, skip cleanly.

12. **Migrate an existing setup (re-run only)** — if the repo used the suite before agent branches
    carried an owner segment, check the one thing that silently breaks: **`agent/*` globs no longer
    match** `agent/<handle>/<type>-<slug>` (`*` does not cross a `/`). Grep the repo's config —
    `.github/workflows/*.yml`, branch-protection rulesets (`gh api repos/{owner}/{repo}/rulesets`), any
    scripts — and **propose** `agent/**`. If nothing globs on agent branches (the common case — the
    bundled `ci.yml` triggers on `pull_request` with no branch filter), say so. Existing handle-less
    branches keep working.

13. **Tuning pass (re-run only, and only with evidence)** — once the repo has real history under the
    suite (**≳20 commits since setup**), the skills can be adapted to how work here *actually* goes. The
    **only** adaptation path: the skills **never rewrite themselves**, no automatic trigger. You propose;
    the human approves a diff.

    Offer it when the evidence exists ("23 commits and 9 PRs since setup — shall I look at where the
    skills fought this repo?"). On yes, read the trail (commits, PR bodies, review comments, parked
    issues, audit reports) for **recurring friction**: a dimension that **never** produced a finding → a
    candidate to soften/drop; a Red Flag the code trips **repeatedly** → sharpen it; a demanded test
    level nobody writes → fix the strategy, don't leave the lie; repo conventions the skills keep missing
    → into `CLAUDE.md` or the catalog.

    **Off-limits to any tuning — the point of the whole design:** the **merge gate** and `main`
    protection (auto-merge conditions, contract domains, destructive-migration rule, `solo`/`team`); the
    rule that **skills never approve a PR**; the **Blocker/Major decision point**; **personal state never
    becomes repo state**; the **security-audit scope**; and the **autonomy config** — its excluded-domain
    floor, the `AUTONOMY_SAFE_PATHS` allowlist, and the comms→handoff coupling. A guardrail that relaxes
    because the paths "never caused a problem" is the one that costs you the day it does. If a guardrail
    genuinely doesn't fit, that is a **conversation**, not a tuning finding.

14. **Output the setup report** and confirm the readiness of the other skills.

## Scan checklist

Capture at least:

- **Surface detection (first)** — **Backend+Web TS monorepo** (`package.json`, `pnpm-workspace`/`turbo`,
  NestJS/Next), an **iOS** repo (`*.xcodeproj`/`Package.swift`, Swift, StoreKit, App Attest), or an
  **Android** repo (`build.gradle(.kts)`, Kotlin, Play Billing, Play Integrity)? Decides which sections
  to keep.
- **Languages & runtimes** — manifests, versions, mono- vs polyrepo.
- **Frameworks** — Web/API (Express/NestJS/FastAPI/Spring), ORM/DB, worker/queue; or client UI
  (SwiftUI/UIKit, Compose, React/Next).
- **API style & contract** — REST/OpenAPI, GraphQL, gRPC; a **shared/versioned contract** + client
  codegen (`references/contract-protocol.md`)? Versioning scheme?
- **AI/LLM** — which provider SDKs? Centralized behind an abstraction or scattered? Prompts versioned?
- **Token economy / billing** — IAP (StoreKit / Play Billing / Stripe), server-side ledger,
  verification, webhooks/RTDN? (→ `PAY-*`.)
- **Data storage** — DB type, migration tooling, caches.
- **Auth & Security** — AuthN/AuthZ, secrets handling, client attestation, hints of keys in the binary.
- **Clients & distribution** — which clients consume the API; store distribution (→ `API-2`/`CLIENT-3`)?
- **Infra & CI/CD** — containers, IaC, pipeline files, deploy model; mobile: Fastlane/Xcode
  Cloud/Gradle, signing, tracks.
- **GitHub connection (read-only)** — git `origin` on GitHub, `gh` installed/authenticated, Issues
  reachable? (verified in step 9).
- **Issue & PR history (read-only signal)** — run `scripts/mine-issues.sh` for recurring themes: label
  frequency, terms by **document-frequency** (so one noisy thread can't dominate), closed-PR themes.
  **Numbers only** — counts and a few example issue *numbers*, never bodies (`--bodies` opts in,
  email-redacted). Obey the exit code: `exit 0` = signals emitted — an **empty** backlog is a valid
  answer, a new repo simply has no history · `exit 2` = **UNKNOWN**: `gh` missing, unauthenticated,
  or the origin is not a GitHub repo `gh` can resolve — **degrade to code-only mining, record the
  gap**; the scan never blocks on it. **Misuse is also 2** — not a git repo, or an unknown argument:
  the *message* says which, the code says what to do, and it is the same thing either way (do not
  trust the mining). There is deliberately no third code; the suite's other scripts map misuse to 2
  as well, and a per-script dialect is a code every caller has to learn. Feeds step 5a.
- **Observability** — logging/tracing/metrics stack?
- **Compliance signals** — personal/minors' data, data location, third country.
- **Existing docs** — `docs/`, ADRs, README, `CLAUDE.md` (honor existing conventions).

## Tailoring rules

See `references/catalog-sizing.md` §*Tailoring rules* — keep / soften / add / renumber, and the rule
that a dropped dimension is a risk decision, never a sizing choice.

## Output format — setup report

Use the template in `references/setup-report.md` — what was scanned, created, tailored (and why), the
merge-gate config to confirm, the AI-readiness proposals, and the honest limitations.

## Principles

- **Scan beats assumption** — the catalog reflects the real project.
- **Idempotent & non-destructive** — never overwrite existing docs silently.
- **Justify what deviates** — every change relative to the baseline is traceable in the report.
- **Honest about platform fit** — if the baseline doesn't fit, say so.
- **Never commit or push** — everything is a proposal.

## Related Skills

This skill is the **setup** stage (stage 0) before the lifecycle plan → implement → review:
- **wai-requirements-planning / wai-implementation / wai-pr-review** — run afterward
  against the `docs/architecture/quality-attributes.md` produced here.
- Run this skill again when the tech stack changes fundamentally or another skill reports the catalog
  is missing.
