<p align="center">
  <img src=".github/assets/wai-logo.svg" alt="wAI" width="72" height="72">
</p>

# wai-skill-suite

Claude Code skills for **sustainable software product development**: a gated engineering
lifecycle that keeps architecture maintainable and clean and security first-class while agents
write the code. The premise is an observation, not a slogan: **even frontier models lose
context, are confident when they are wrong, and forget rules and guidelines** — so this suite
does not ask the model to remember. Each goal gets a gate, a rule, or a deterministic check.
Skills plan, build, test and review on `agent/**` branches — and **whether a PR may merge is
decided by a script with an exit code and, above it, a human. Not by the model.** In industry
terms: a **deterministic quality gate** for agent-written code, shipped as skills — with the
human in the loop above every risky decision.

> **Tool where it is decidable. Model where it takes judgment. Human where neither suffices —
> and the boundaries between them are drawn, not guessed.**

Not a philosophy the suite started from — [it is what was left standing](docs/history.md). The
asymmetry underneath has a name ([Verifier's Law](REFERENCES.md)): tasks yield to AI to the
degree they are verifiable. The tool layer here *manufactures verifiability* where it is cheap —
an exit code, a lint — and where verifiability collapses, the human is the design, not the
fallback.

## What is different here

Not the gate alone — merge gates with exit codes exist elsewhere. What this suite adds is that
**its own claims are checked the way it checks code**, and the record of being wrong is published:

- **Two scripts were deleted for crossing into judgment.** A collision check failed a repo that
  was right; a title heuristic scored 3 false positives in 10 on the very data it was built for.
  Both are gone, and [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md) keeps
  the line they crossed: mechanics in scripts, judgment in prompts. The boundary is a position
  that has cost features — not packaging.
- **The prose is linted against its measurements.** [`tests/numbers-lint.sh`](tests/numbers-lint.sh)
  fails CI when a count in this README, the open-questions agenda or the plugin manifests stops
  matching what a script can measure — including whether a referenced release tag actually exists.
  [`tests/release-lint.sh`](tests/release-lint.sh) fails it when the tree disagrees with that tag:
  work landing in the skills a user *executes* with nothing declared in the changelog, or a plugin
  version string fallen behind the newest tag. It exists because a fix for a verdict-corrupting
  bug once sat on `main`, unreleased, under install instructions that pinned the release without
  it — and every check in this repo read green.
- **Every unmeasured claim was wrong — 9 of 9.** The
  [July retrospective](docs/retrospective-2026-07.md) counts the author's own error rate, by
  name, from the repo — not from memory.
- **The gate writes its own denominator.** Every verdict lands in an append-only
  [ledger](docs/architecture/gate-ledger.md) that a human tags later (`ok`/`fp`/`fn`) — so
  *"the model checked"* has an artefact, and the false-negative rate has a place to be measured
  instead of asserted.

The merge gate described below is the **proof of that doctrine, not the product**.

## Why it exists — one incident

The suite once kept its merge rules as prose a model was asked to remember. A self-audit found
that **55 of 89 quality dimensions had no check behind them — and nothing had noticed**, because
*"the model checked"* produces identical output whether it happened or not. So the mechanics
moved into scripts ([ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)):
the gate became `merge-gate.sh` — `0 GO · 1 NO-GO · 2 UNKNOWN`, fail-closed, **no path from
"could not check" to "go"**. On its first field run, the gate **stopped the very PR that
introduced it** — the review wanted to merge, the script said NO-GO, the model quoted the exit
code verbatim and handed the decision to the human ([empirics](docs/empirics.md), Run 1;
n = 1, and the file says so).

**Limits, stated up front.** One author so far; evidence from a handful of repos; systematic
per-run logging exists since 2026-07-13. "In daily use" is a usage claim, not an efficacy claim —
the efficacy evidence, including every case where the suite was wrong, is in the linked files,
and it is deliberately not summarized into a slogan. Claude Code + GitHub only, by design
(see *Porting*, below).

## What is deterministic here — and what is not

Three enforcement layers — in guardrail terms: one **design-time** (the server-side rules), two
**runtime** (hooks, and scripts in the agent's own loop) — and only the third depends on the
model cooperating:

| Layer | Examples | Can the model bypass it? |
|---|---|---|
| **Server-side** | branch protection on `main`, required checks, CODEOWNERS | No — the model does not run there |
| **Local hooks** | [`pre-commit`](.githooks/pre-commit) (no commits on the default branch), [`pre-push`](.githooks/pre-push) (no pushes to a branch whose PR is merged) — **wire them once: `git config core.hooksPath .githooks`** | Only visibly, via `--no-verify` |
| **Scripts a skill invokes** | `merge-gate.sh`, `catalog-lint.sh`, the audit and protocol lints — 28 scripts across the suite | In principle yes — which is why this was **measured**, not assumed ([Test 0](docs/empirics.md)) |

The merge policy itself is **policy-as-code**: the guardrail floor is hardcoded in the scripts,
the repo-specific half lives in `docs/architecture/merge-gate.conf` — and config can only ever
*widen* the floor, never lower it.

The judgment stays with the model, and the ceiling stays with the human: *no script can decide
whether a finding is a Blocker* — two scripts that tried crossed into semantics and were deleted
— and no artefact can check whether the **question** was right
([ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md), read the end first).

**Prior art, named.** Related work ships as *quality gates for AI-generated code* (CodeRabbit's
pre-merge checks; Codacy's guidance to keep AI review advisory and let branch protection
recognise only deterministic checks), occasionally under the label *"ACT gate"* — there mostly as
a pre-review filter before a human reads the PR. The difference here is the **level**: not the
flow is deterministic but the **verdict**, and it is computed where the agent decides — in its
own loop, before the merge command — with CI and branch protection as the layers behind it, not
instead of it. Sources, and what each changed here: [REFERENCES.md](REFERENCES.md).

**The pattern is not software-specific.** Every serious AI deployment ends at the same division
of labor: equip the model with tools that make its work *verifiable* where the task is decidable,
leave it the judgment where it is not, and keep a human above both where verifiability collapses.
This suite is that pattern instantiated for one domain — the software lifecycle on GitHub. The
claim beyond software is a position, not a measurement: supervised, well-tooled AI is the
*precondition* for delegating real work at all. (Deliberately no productivity number here — Q5 in
[open-questions](docs/open-questions.md) is still open.)

**The price, honestly:** the deterministic layer took nine repair commits in two days; the gate
once failed *open* under zsh and later could never say GO at all. That is why
[`tests/`](tests/) exists — 383 cases, **founded** on bugs that shipped and grown into the
regression guards around them, run on two shells because shellcheck passed a construct that is a
syntax error in the `/bin/sh` of macOS. (The second shell runs locally on every branch, not in
CI: macOS runners bill at 10× and exhausted the private repo's Actions minutes until no check
could run at all — the dated trade is in [`ci.yml`](.github/workflows/ci.yml) itself.)
*Determinism does not buy safety. It buys testability — and
then you have to actually test.*

(The precise claim matters here: an earlier version of this sentence said *each one* a bug that
shipped. The [retrospective](docs/retrospective-2026-07.md) records that as an overclaim in my own
words — it was 8 of 29 at the time. It was still in this README on publication day.)

## The human stays the orchestrator

Skills work on `agent/<handle>/…` branches and open PRs; `main` is gated. Only `wai-pr-review`
may auto-merge a clean, non-contract-domain PR — everything risky waits for a human merge.
**Blocker/Major findings are always the human's decision point** — the human-in-the-loop is the
design here, not a fallback; Minors/Nits are filed as GitHub issues so nothing deferred is lost.

**Multi-developer safety.** Branches carry an **owner segment** (`agent/<handle>/<type>-<slug>`),
an issue is **claimed** before it is built, and the **repo mode** decides merge authority: in
`solo` (the default) `wai-pr-review` merges a clean PR itself; in `team` it **never merges by
itself** — it arms GitHub auto-merge and the PR waits for another human's approval. Skills never
approve a PR in either mode.

**Personal state never becomes repo state:** the `wai-learning-gap` ledger is per developer and
opt-in — without your own ledger the skill does nothing and creates nothing, so colleagues in a
shared repo are untouched.

## Surfaces & repo topology (hybrid)

The suite is opinionated toward a **multi-surface product platform**: a cloud backend
(orchestrating multiple AI models/providers + owning the server-side token ledger), a Web app, an
iOS app and an Android app — four first-class surfaces joined by a versioned API contract.

- **Backend + Web** live in one TS monorepo; **iOS** (Swift/SwiftUI) and **Android**
  (Kotlin/Compose) are native, each in its own repo.
- The **OpenAPI contract** is the shared spine; clients generate their API client from it and
  must stay backward-compatible (they cannot be force-updated).
- The **token economy** spans client + backend; the **server-side ledger is the single source of
  truth** (verify purchases server-side, idempotent credit/debit, refund clawback). Tokens are
  digital goods → StoreKit/Play Billing on mobile, Stripe only on web.

Smaller repos work too — `wai-init` scopes and sizes everything to what the repo actually is
(one of the field repos is a hobby game server without CI).

## Skills

A **router** points you to the right skill; three one-time **setup** skills prepare the repos;
four skills form the per-requirement **lifecycle** (plan → implement → test → review); one
**batch orchestrator** works several issues at once under your mandate; three run **periodically**
— a structural architecture audit, an adversarial security audit, and an artifact-derived
retrospective of the suite's own record. All are triggered
automatically via their `description` and demarcate themselves against the others to avoid
mis-routing.

**Field exposure** — the author's self-report as of 2026-08: a usage claim, not an efficacy
claim, and nothing in this repo measures it yet (that is Q9 in
[open-questions](docs/open-questions.md)). What *is* checkable: the heavily-used skills are where
most recorded defects were found — and fixed — so most regression tests trace back to them.
**daily** = in daily use across the author's repos since consolidation · **periodic** =
deliberately not daily — run every 5–10 PRs, or after a stretch of major changes · **less
often** = fewer occasions, well-tested · **once per repo** = by nature runs once-to-rarely per
repo — proving status, [field reports](docs/field-reports/TEMPLATE.md) explicitly wanted.

| Skill | Stage | Exposure | What for | Trigger (examples) |
|-------|-------|----------|----------|--------------------|
| [`wai`](.claude/skills/wai/SKILL.md) | Router | less often · well-tested | Front door: recommends which skill to run next and how the suite hands off. Routes by **surface** (backend/web/iOS/Android) and lifecycle position. | "which skill do I use", "where do I start", "what's next" |
| [`wai-init`](.claude/skills/wai-init/SKILL.md) | Setup (per repo) | daily | **Bootstrap + re-runnable update:** deep-scan the repo, detect its **surface** and whether it's greenfield or grown, create a surface-scoped `docs/architecture/quality-attributes.md` + testing strategy **sized to the project** via a **variant seed** (platform / web / minimum — [ADR-0004](docs/adr/0004-one-master-three-generated-variants.md)) plus two dials — scope (which IDs survive within the variant) and tier (how much prose each carries; the full baseline is 87 IDs / ~510 lines). Every other skill reads the catalog at runtime, so its size is the suite's biggest cost lever. Also checks **AI-readiness**, and asks the setup questions (**solo or team?** protect `main`? docs language? tier? learning mode **for you personally**?). Existing docs are **kept** unless you ask for a reset. On a re-run with history: an optional **tuning pass** (proposed diffs; guardrails excluded). | "set up the skills", "initialize the project", "onboard this repo", "update the catalog", "tune the skills" |
| [`wai-cicd`](.claude/skills/wai-cicd/SKILL.md) | Setup (backend+web) | once per repo · proving | **One-time:** GitHub-native CI/CD (Actions, GHCR) + deploy to your own server via Compose/SSH — Dockerfile, Compose, Caddy, the **merge gate** + branch protection. Other delivery systems are out of scope by design. | "set up CI/CD", "deploy to my server", "wire required checks" |
| [`wai-mobile-release`](.claude/skills/wai-mobile-release/SKILL.md) | Setup (iOS/Android) | once per repo · proving | **One-time:** build, code signing (match / Play App Signing), the **mobile merge gate**, and store delivery (TestFlight / Play tracks). | "set up the iOS build", "Fastlane", "TestFlight", "Play Console" |
| [`wai-requirements-planning`](.claude/skills/wai-requirements-planning/SKILL.md) | Plan | daily | Prepare a requirement; interview — or **grill-me mode** (one question at a time, recommended answers, alternatives for imprecise asks); decompose **per surface + contract-first**; diagrams over text; small items become issues, not planning docs. | "plan this requirement", "how do we build X", "grill me" |
| [`wai-implementation`](.claude/skills/wai-implementation/SKILL.md) | Implement | daily | Concrete implementation — plan with risk/blast-radius first, then code, with per-surface concern sets. Default for code changes. | "implement X", "fix", "returns error 503", "refactor" |
| [`wai-testing`](.claude/skills/wai-testing/SKILL.md) | Test | daily | Deterministic tests + the testing strategy: per-surface levels, **contract tests both sides**, token economy as a mandatory target (no real models/billing). | "write tests for X", "is this covered", "cover the billing path" |
| [`wai-pr-review`](.claude/skills/wai-pr-review/SKILL.md) | Review | daily | Evaluate a PR/diff against the catalog, ordered by severity; classify by surface; token/billing & contract are human-gated domains. | "review this PR", "can this be merged", "check this diff" |
| [`wai-team`](.claude/skills/wai-team/SKILL.md) | Batch | less often · well-tested | **Mandated backlog orchestrator:** works a set of GitHub issues through the full cycle — one branch+PR per issue, serial by default, bounded parallelism only for disjoint issues — integrated via pr-review's **merge queue**; Blocker/Major & contract merges collect in **your decision list**. | "work the backlog", "process issues #12–#18", "burn down the tier" |
| [`wai-architecture-audit`](.claude/skills/wai-architecture-audit/SKILL.md) | Periodic | periodic — every 5–10 PRs | Whole-codebase **structural** audit: decoupling/modularity, drift, dead code + **non-obvious semantic redundancy / inconsistency / cross-surface dead-ends**, efficiency & container topology — as a trend over time. Measures against a persisted **architecture baseline**. | "audit the codebase", "is it decoupled", "find redundancy/drift" |
| [`wai-security-audit`](.claude/skills/wai-security-audit/SKILL.md) | Periodic | periodic — every 5–10 PRs | Whole-codebase **adversarial** cyber-security sweep: attack-surface map + authZ/IDOR, secrets, injection (incl. prompt), SSRF, rate-limiting, session/token lifecycle, dependency CVEs, crypto/TLS, **token-economy fraud**, client attestation — posture as a trend. Report-only; redacted. | "security audit", "are we secure", "pentest", "check the attack surface", "dependency CVEs" |
| [`wai-retro`](.claude/skills/wai-retro/SKILL.md) | Periodic | new — proving | **Artifact-derived retrospective** of the suite's own record, at a threshold (doctor's report-cadence advisory) — never from recall: the gate ledger's report extract, the run log and `git log` in; a dated, narrated report with raw counts beside every rate out; the judgment column stays human. Finishes by advancing the ledger's report marker so the cadence resets. Collaboration level gated until a question trace exists; publication to this repo only on explicit request, sanitized + pseudonymized (`fr-<12hex>`). | "run the retro", "retrospective", "what did the suite do this month", "cut a report" |

## Personal skills

Not part of the wAI lifecycle — reusable helpers for the human, adopted per project like the others.

| Skill | Exposure | What for | Trigger (examples) |
|-------|----------|----------|--------------------|
| [`wai-learning-gap`](.claude/skills/wai-learning-gap/SKILL.md) | daily · two developers (author + one junior) — **needs many users, not more days** | Cloze-coding tutor, **per developer and opt-in**: after **every implementation phase**, plant exactly one learning gap (1–3 removed lines, 🧩 `LEARN #` marker, working tree only) the human must rebuild to get back to green. On first run it builds a **stack profile** from the repo's manifests (+ a short self-assessment) that seeds the **Leitner boxes** in the *personal* ledger `~/.claude/learning/<repo>/ledger.md` (outside the repo, so it survives a second clone or worktree); topics are interleaved, a local pre-commit hook keeps gaps out of commits, stale gaps are resolved & explained so implementation speed doesn't suffer. **The ledger is the opt-in**: a developer without one gets nothing — no gap, no hook, no ledger — so in a shared repo your colleagues are untouched. Works standalone in any repo. | "learning gap", "hint", "solution", "learning status", "learning mode on" |

## Installation

**As a plugin (recommended).** This repo is its own [plugin marketplace](.claude-plugin/marketplace.json):
one plugin, all thirteen skills, versioned and updatable through Claude Code's plugin system.

```
/plugin marketplace add woldinius/wai-skill-suite
/plugin install wai-suite@wai
```

Updates arrive with `/plugin marketplace update wai`. The plugin ships the same tree as the
installer below — skills, scripts and references included — so everything the skills invoke
travels with them. (Plugin-installed skills live in the plugin cache, not in your repo;
`wai-init` still writes `docs/architecture/` into the repo, which is the part that belongs to you.)

**Or into the repo, with the installer.** The skills live in `.claude/skills/` and Claude Code
detects them automatically once the folder is in the project. Install them with the bundled
[`install.sh`](install.sh) — run it in your **project root**.

**Clone it, read it, then run it.** The installer is built to make that honest: when the script
sits inside a checkout, it installs *from that checkout* — so the tree you reviewed is the tree
you get, not whatever the remote's default branch holds.

```bash
git clone --depth 1 --branch v0.3.0 https://github.com/woldinius/wai-skill-suite.git /tmp/wai
sh /tmp/wai/install.sh            # installs into the current directory
rm -rf /tmp/wai
```

If you would rather pipe, pin it to a release — the script and the tree it installs must be the
same version. (An earlier README once pinned to a tag before that tag existed — which is why
`tests/numbers-lint.sh` now checks every version reference here against `git tag`.)

```bash
curl -fsSL https://raw.githubusercontent.com/woldinius/wai-skill-suite/v0.3.0/install.sh | SKILLS_REF=v0.3.0 sh
```

What the script does — and deliberately does **not** do:

- **Installs/updates** the suite's skills into `.claude/skills/` — and **nothing else**. It
  deliberately does **not** create `docs/architecture/`: the catalog and testing strategy must be
  scanned, scoped and sized to *your* repo, which is `wai-init`'s job. (Copying this repo's
  catalog over would hand you an 87-ID multi-surface document with the setup questions
  pre-answered — and `wai-init`, finding a catalog already there, would never ask them.)
- **Idempotent** — safe to re-run any time to pull the latest skills.
- **Tracks renames/removals** — it records the installed suite skills in
  `.claude/.wai-suite-manifest`; on the next run any suite skill that was renamed or removed
  upstream is pruned, so stale skills never pile up.
- **Migrates the old namespace** — a repo that still carries the suite under its former
  `platform-*` names (tracked in `.platform-suite-manifest`) is converted in place: the old suite
  skills are pruned by manifest, never by name, and yours are untouched.
- **Leaves your project alone** — it only touches the suite's own skills (reserved namespace
  `wai`, `wai-*`); it never removes *your* skills and touches nothing else. (Don't name your own
  skills in that reserved namespace.)
- **Env overrides:** `SKILLS_REF=<branch/tag>`, `SKILLS_REPO=<git url>` (e.g. a fork).

After it runs, in Claude Code:

> **`refresh skills`** (or restart), then **"run wai-init"**

`wai-init` deep-scans the repo, **detects the surface** (backend+web / iOS / Android) and
whether the project is greenfield or grown, then creates/reconciles a surface-scoped
`docs/architecture/quality-attributes.md` + `testing-strategy.md`, **sized to the project** (a
visible proposal — nothing is committed). It asks the setup questions (**solo or team?** protect
`main`? **docs language?** **catalog tier?** learning mode **for you personally**?), and reports what
the repo needs to be pleasant for an agent to work in (CLAUDE.md, ignored build dirs, no committed
secrets). An existing catalog is **kept** — it only proposes a diff, and resets only if you ask.
Then the lifecycle skills take effect. As a second setup step, wire delivery + the merge gate:

- **Backend+web:** "Set up CI/CD / prepare the deployment" → `wai-cicd`.
- **iOS/Android:** "Set up the iOS/Android build / TestFlight / Play" → `wai-mobile-release`.

> **Updating later:** just re-run the script (it prunes renamed skills and updates the rest),
> then run `wai-init` again to reconcile the catalog.

### What the suite writes — and what it never touches

Everything below is the complete list of side effects; nothing else is written.

| Actor | Writes | When |
|---|---|---|
| Plugin install | the plugin cache only — **nothing in your repo** | on `/plugin install` |
| `install.sh` | `.claude/skills/` + its own manifest and version stamp | when you run it |
| `wai-init` | `docs/architecture/` (catalog, testing strategy, gate config; optional coordination config) | after asking its setup questions |
| `wai-cicd` / `wai-mobile-release` | CI/deploy/release artifacts — **as visible proposals; the human commits** | when you invoke them |
| Lifecycle skills | `agent/**` branches, PRs, issues via `gh`, and appends to `docs/architecture/gate-ledger.md` | during normal work |
| `wai-learning-gap` | `~/.claude/learning/` — personal, opt-in, never repo state | only for a human with a ledger |

Nothing writes to `main` directly, nothing stores secrets, and no skill approves a PR.

## Quality catalog (Single Source of Truth)

The lifecycle skills read **one** central live catalog instead of bundled copies;
`wai-init` creates it from a shipped seed, **scoped to the repo's surface**. The seed comes in
**three variants** — so a repo that is not a multi-surface AI platform never carries that
framing (`PAY-*`, `AI-*`) to begin with:

- `docs/architecture/quality-attributes.md` — the **live catalog** in each target repo (this
  repo's own copy: [docs/architecture/quality-attributes.md](docs/architecture/quality-attributes.md)):
  the binding quality standard. Cross-cutting core (security, GDPR, API compatibility,
  maintainability) **+ backend** (AI orchestration, resilience, observability, performance)
  **+ token economy** (`PAY-*`) **+ client-common** (`CLIENT-*`) **+ per-surface** (`IOS-*`,
  `AND-*`, `WEB-*`). Each dimension has a **stable ID** (e.g. `AI-3`, `PAY-2`, `CLIENT-1`) that
  reviews and plans cite to justify findings, and a **surface-scope** tag so a per-repo catalog
  keeps only what applies.
- [`.claude/skills/wai-init/references/quality-attributes.baseline.md`](.claude/skills/wai-init/references/quality-attributes.baseline.md)
  — the **master** the seeds are derived from. Three **variant seeds** ship beside it, generated
  by [`catalog-variant.sh`](.claude/skills/wai-init/scripts/catalog-variant.sh) and re-derived +
  diffed by CI so they cannot drift from the master
  ([ADR-0004](docs/adr/0004-one-master-three-generated-variants.md)):
  [`quality-attributes.platform.md`](.claude/skills/wai-init/references/quality-attributes.platform.md)
  (today's full build — backend + clients + AI model integrations + token economy) ·
  [`quality-attributes.web.md`](.claude/skills/wai-init/references/quality-attributes.web.md)
  (backend + web frontend) ·
  [`quality-attributes.minimum.md`](.claude/skills/wai-init/references/quality-attributes.minimum.md)
  (the core of software engineering: clean architecture, maintainability, security, privacy,
  clean code). `wai-init` copies the variant that fits and tailors it; section numbers and IDs
  are never renumbered across variants, so `SEC-8` means the same dimension everywhere. All of it
  travels with the `.claude/skills` folder the installer lays down.
- [`docs/architecture/testing-strategy.md`](docs/architecture/testing-strategy.md) — the
  **reference copy** of the testing strategy: the shape `wai-init` writes into a target repo
  and `wai-testing` reads on every run. Deliberately extracted from the skill, because the
  policy is phase-dependent — when a project's phase changes, that project's document changes,
  not the skill.

The catalog is plain Markdown with stable IDs — **harness-neutral by construction**. Any agent
that can read files can work against it; only the lifecycle skills themselves are Claude
Code-specific.

## Shared protocols

Cross-skill rules live next to the router and are referenced by every relevant skill:

- [`.claude/skills/wai/references/agent-git-protocol.md`](.claude/skills/wai/references/agent-git-protocol.md)
  — identity (@handle) & repo mode (solo/team), branch/commit/PR rules, the **gated-merge**
  policy (`main` is protected; auto-merge only for clean, non-contract-domain PRs — in team mode
  armed via `--auto` and held for another human's approval; Blocker/Major = human decision
  point; branch guard), and the rule that **personal state never becomes repo state**.
- [`.claude/skills/wai/references/contract-protocol.md`](.claude/skills/wai/references/contract-protocol.md)
  — the **API contract spine**: location, additive/backward-compatible versioning, per-client
  codegen, provider+consumer contract tests, and the cross-repo change flow.
- [`.claude/skills/wai/references/issues-protocol.md`](.claude/skills/wai/references/issues-protocol.md)
  — **GitHub Issues**: the Blocker/Major decision-point rule and its mandate exceptions, the
  durable issue format (behavioral, checkbox criteria, out-of-scope), label taxonomy,
  dedupe-by-concept, and the per-skill read/write matrix.
- [`.claude/skills/wai/references/grilling-protocol.md`](.claude/skills/wai/references/grilling-protocol.md)
  — the **interrogation primitive** ("grill me"): one question at a time with a recommended
  answer, facts looked up vs. decisions asked, alternatives for imprecise requirements, hard
  shared-understanding gate.

> **Portability:** the lifecycle skills expect `docs/architecture/quality-attributes.md`. If it's
> missing they say so (→ run `wai-init`) and meanwhile work from their built-in short list of
> the platform-critical points.

## Where it comes from

Early versions of these skills grew inside product repos starting **December 2025** — a wild set
of similar skills, drifting apart. On **2026-06-13** they were consolidated into one suite, and
that suite has been **in daily use in three commercial projects plus prototypes** since. This
repository is a **curated re-publication** of that work: real milestone dates, cleaned content,
and the dated evidence — [empirics](docs/empirics.md),
[field reports](docs/field-reports/), [ADRs](docs/adr/), and the audits (returning from the
archive; not yet republished) — migrated with it. The full story, including what was
tried and dropped: [docs/history.md](docs/history.md).

**Built with AI, deliberately.** A range of AI models worked on this suite — whichever was most
capable for the problem at hand, including on these very documents. That is a statement of
method, not a confession: building today without the most capable model for the problem is
closer to negligence than to rigor. Using AI is not the weakness — using it without knowing
what it must never decide is. That knowledge is this repo's actual thesis: the model works
everywhere here, and the merge verdict still belongs to a script and a human
([ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)).

## Evidence

The claims above are checkable, and the failures are part of the record on purpose:

- [`docs/open-questions.md`](docs/open-questions.md) — **the numbers the suite does not have
  yet**, as a live eval agenda: each open question with its measured today-state and the
  experiment that would answer it. The ledger-derived numbers in it are re-measured by CI on
  every run.
- [`docs/known-criticism.md`](docs/known-criticism.md) — **the criticism, named before a reader
  has to**: the provable findings of the external audit with their status, and the expected
  objections with what the record answers.
- [`docs/history.md`](docs/history.md) — how the suite came to be, including what was
  dropped and why.
- [`docs/empirics.md`](docs/empirics.md) — dated runs against real repos; the outcome
  column belongs to the human, because *a skill grading its own homework is not evidence*.
- [`docs/field-reports/`](docs/field-reports/) — dated reports from production repos, a
  prototype and this repo itself, defects of the suite included. (No count here: it went
  stale twice in two days; the directory listing is the number.) **If you run the suite:** the
  most interesting report is the one where it was **wrong** — the ledger has a column for that,
  and [`TEMPLATE.md`](docs/field-reports/TEMPLATE.md) is the paste-sized way to send it.
- [`docs/adr/`](docs/adr/) — the four decisions that shaped the architecture, with the
  cases where the scripts lost.
- `docs/architecture/audits/` — the suite auditing itself with its own audit skill (first
  verdict: *significant drift*, since fixed). Not yet republished from the archive; the link
  returns with the files.
- [`docs/retrospective-2026-07.md`](docs/retrospective-2026-07.md) — the July
  retrospective, written from the repo, not from memory.

**Publication rule** ([docs/publication/](docs/publication/)): a claim that cannot be
traced to a measurement does not go out. This repo has already shipped one that could not; the
rule exists because of it.

## Repo structure

```
install.sh                                       # idempotent installer (inject/update skills into a project)
.claude/skills/
  wai/                                           # router + shared protocols + doctor/contract/handoff lints
  wai-init/                                      # bootstrap; catalog baseline + catalog-lint, issue mining
  wai-cicd/                                      # GitHub-native CI/CD + deployment runbook + templates
  wai-mobile-release/                            # iOS/Android build, signing, store delivery
  wai-requirements-planning/
  wai-implementation/
  wai-testing/                                   # + test-patterns reference
  wai-pr-review/                                 # + review lenses + merge-gate.sh (exit-code gate)
  wai-team/                                      # mandated batch orchestrator (merge queue) + scripts
  wai-architecture-audit/                        # + audit playbook
  wai-security-audit/                            # + security playbook + CVE/attack-path scripts
  wai-retro/                                     # artifact-derived retrospectives + retro-compliance.sh
  wai-learning-gap/                              # personal, opt-in; own scripts + tests
.githooks/                                       # pre-commit (no default-branch commits), pre-push (no dead-branch pushes)
tests/                                           # 383 cases for the deciding scripts — founded on bugs that shipped
docs/                                        # history, empirics, field reports, ADRs, audits, catalog, open questions
```

> After running `install.sh` in a target project, `.claude/.wai-suite-manifest` records the
> installed suite skills so the next run can prune ones that were renamed or removed here.

## Porting

Claude Code + GitHub is a deliberate narrowing, not a technical wall. The seams are explicit:
the gate script wraps `gh` calls, branch protection is a GitHub ruleset, the issues protocol maps
to `gh issue` — and the catalog, the testing strategy and all protocols are plain Markdown that
any file-reading agent can consume today. Whether the lifecycle skills run well on other
harnesses has **not been tested** — reports welcome.

## License

[MIT](LICENSE) © 2026 Benjamin Wolters
