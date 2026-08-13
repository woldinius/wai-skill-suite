---
name: wai-cicd
description: >-
  One-time setup of GitHub-native CI/CD for a backend+web repo (Actions, GHCR, Docker Compose over
  SSH to your own Linux server, any provider) — and owner of the merge gate that makes "green
  checks" trustworthy. Creates Dockerfiles, compose, a Caddy proxy, the Actions required-check gate,
  the branch-protection ruleset, CODEOWNERS, PR template, deploy script and runbook. GitHub-only by
  design; mobile store delivery is wai-mobile-release. Use it for: "set up CI/CD", "deploy to my
  server", "create GitHub Actions", "containerize", "wire required checks". Not for implementation,
  tests, PR review or the catalog (wai-init).
license: MIT
---

# CI/CD & Deployment Setup

Prepare a repo **one-time** for **GitHub-native** CI/CD and a deployment to your own Linux
server, whatever the provider: GitHub Actions as the pipeline, **GHCR** as the registry, Docker
Compose + Caddy + SSH deploy on the box. The value: a deep
scan of the real project and, from it, correct, tailored deploy artifacts instead of
generic boilerplate — as a visible proposal, nothing is committed.

**GitHub is the only delivery system this skill knows.** Actions, GHCR, branch protection,
CODEOWNERS — all GitHub. If a project delivers through something else (another CI system, a
PaaS), that is a different skill's job; this one stays GitHub-native rather than half-knowing
every tool.

## What this skill produces

Depending on stack and deploy target (not everything is always needed):

- **`Dockerfile`** per deployable app (multi-stage) + `.dockerignore`.
- **`.github/workflows/ci.yml`** — the **merge gate**: real lint · type-check · build · unit ·
  **integration/e2e (against an ephemeral DB)** · **security scan** on every PR, plus a guard that
  fails if a gate script is a stub; then build the image and push to **GHCR** (`sha`-tagged) on
  `main`. The **required** checks are the workflow's **job names** (below) — not the step names.

  **The security scan covers three CVE surfaces, not one — and a `pnpm audit`-only gate has a
  structural blind spot.** The dependency audit (`npm`/`pnpm`/`yarn audit`, `pip-audit`,
  `govulncheck`, `osv-scanner`) sees only **lockfile** dependencies. It cannot see **OS packages**
  (openssl, poppler) or **libraries bundled in the runtime** — e.g. Node's `undici`, the engine
  behind global `fetch()`. Those ship in the image and run in production, and only an **image scan**
  (trivy/grype on the built image) sees them. This is not hypothetical: a real `undici` CVE reported
  **0** under `pnpm audit` (undici is not an npm dependency — it is inside `node:*-alpine`) and was
  caught **only** by the image scan; its fix was a **base-image bump**, not a package update. So the
  template makes the **image scan a first-class layer of the gate** (built and scanned on every PR),
  and — because the fix for a runtime CVE is a version bump — **pin the base image to a patch tag**
  (`node:24.12.0-alpine`, never floating `node:24-alpine`) so every such fix is a reproducible,
  gated commit rather than silent drift. See the three-surface table in the `ci.yml` `security` job.
- **`.github/CODEOWNERS`** — **generated from `docs/architecture/merge-gate.conf`**, not invented
  here. That file's `CONTRACT_PATHS` is the suite's single answer to "which paths are sensitive",
  and `merge-gate.sh` already blocks the agent on exactly those. If CODEOWNERS carried its own
  list, the two would drift the first time someone moves a module — and then the human-review
  routing and the agent's gate would disagree about the *same* PR, each looking internally
  consistent. Read the conf, translate each glob to a CODEOWNERS pattern (a `case` glob's `*`
  crosses `/`, so `apps/api/src/auth/*` becomes `/apps/api/src/auth/`), and say in the report
  which paths you took from it. If the conf is missing, **stop and run `wai-init` first**
  rather than guessing a second list into existence. What CODEOWNERS adds on top is *who* — the
  handle(s). Note the catalog, the testing strategy, the gate config, `.claude/skills/**` and the
  CI workflows are **already agent-blocking** — `merge-gate.sh` hardcodes them as a guardrail floor
  that no config can lower, because an agent that can merge a change to them can lower the bar it
  is judged against. CODEOWNERS routes them to a human on top of that.
  It routes those paths to a named human so the PRs get that human's eyes even when CI is green;
  skills never approve a PR, so any approval there is a human's.
- **`.github/pull_request_template.md`** — the judgment-first PR body the lifecycle skills fill.
- A **branch-protection ruleset** for `main` (documented as a manual step): require a PR, the
  required checks above, no direct/force push — the server-side wall behind the gated-merge
  policy. **Required approvals depend on the repo mode**: in **`team`**, require **1 approving
  review** + Code-Owners review, and enable *Allow auto-merge* — that is what lets the agent arm
  auto-merge instead of merging by itself. In **`solo`**, require **no approvals**: the only human
  is the PR author, and GitHub never counts an author's own review, so a required approval would
  make every PR unmergeable.
- **Server deploy:** `docker-compose.prod.yml` (app + Caddy + optionally DB, with healthchecks),
  `Caddyfile` (auto-TLS), `.github/workflows/deploy-ssh.yml` + `deploy.sh`,
  `scripts/server-bootstrap` notes.
- **`.env.example`** — documents all runtime variables (values do NOT belong in the repo).
- **`docs/deploy/server-deployment.md`** — runbook, derived from
  `references/deployment-guide.md`.
- A **setup report** (format below) including the manual server steps.

## Stance

- **Scope: backend + web.** This skill containerizes and deploys the **backend and the web
  app**; the native **iOS/Android** apps ship through the app stores (Xcode/Fastlane/TestFlight,
  Gradle/Play Console) — a separate delivery concern, not handled here.
- **Scan before writing.** First understand the deployable units, ports, build steps and
  dependencies, then generate artifacts.
- **One-time & idempotent.** If Dockerfile/workflows/Compose already exist, **do not
  silently overwrite** — deliver as a diff/proposal and wait for "go".
- **Never put secrets in the repo** (`SEC-3`). Only references in code/Compose; values in
  GitHub Actions secrets or a root-only server `.env`.
- **Never commit or push.** Everything is a proposal; the human commits and sets up the
  secrets/server.

## Process

1. **Scan the repo** (scan checklist) — deployable units, build tooling, ports,
   DB/migrations, env variables, existing Docker/CI files, monorepo layout.

2. **Clarify the deploy target** — which server (host, domain), one box or several? The deploy
   model is fixed: **GitHub Actions builds → GHCR → Docker Compose over SSH** on your own
   Linux server (see runbook reference). If the project actually delivers through a different
   system, say so and stop — that setup belongs to a separate skill, not a half-adapted
   version of this one.

3. **Generate/tailor artifacts** — take the templates under
   `references/templates/` as a starting point and adapt them to the real stack
   (language/runtime, build commands, ports, service names, DB). Don't copy blindly.

4. **Secrets plan** — list which secrets need to be stored where
   (GitHub Actions secrets, server `.env`) — without ever writing real values.

5. **Write** — create files as a proposal (`.github/workflows/`, `.github/CODEOWNERS`,
   `.github/pull_request_template.md`, root artifacts, `docs/deploy/`), and document the `main`
   branch-protection ruleset as a manual step. If existing: propose a diff.

   **And declare what the gate depends on.** You wrote the workflow, so you know what it *runs* —
   follow each gate command all the way down and put every path it reaches into
   `docs/architecture/merge-gate.conf`'s `CONTRACT_PATHS`. `node tools/size-gate/check-size.mjs`
   means `tools/*` **is** gate-enforcement: an agent that may merge it may switch the check off, and
   the hardcoded floor cannot know about it. The floor covers the standard chain (package.json, the
   build files, the lint and type configs); **this closes the repo-specific tail, and it is not a
   human's job to notice.** The skill that builds the gate is the one that knows its dependencies.

6. **Output the setup report** — including the **manual server steps** (provision,
   harden, install Docker, set secrets, first deploy).
   **Log the run before handing back:** `sh ../wai/scripts/run-log.sh "wai-cicd" "<subject>"
   "<half-sentence outcome>"` (from this skill's directory) — a run without a row is invisible
   work; fail-open: exit 0 even when the write fails, exit 2 only on misuse (missing arguments).

## Scan checklist

- **Deployable units** — which apps/services (e.g. `apps/api`, `apps/web`)? SSR vs.
  static? Worker/queue? Monorepo → multiple images or one image with targets?
- **Build** — package manager + build command per app (`npm/pnpm/yarn build`, `pip`, …),
  Node/runtime version, lockfile present?
- **Ports & health** — on which port does each app listen? Is there a `/health`/`/ready`
  (`RES-5`)? If not: mark as a mandatory follow-up task.
- **Data storage** — DB type, migration tooling (Prisma/Drizzle/Flyway/…), caches.
- **Env variables** — which are read (AI provider keys, DB URL, secrets)?
- **Existing** — already `Dockerfile`/`compose`/`.github/workflows`/IaC? (`MAINT-3`)
- **Registry/repo** — GitHub repo slug for GHCR image names.
- **Gate scripts real?** — do `lint`/`typecheck`/`test`/`test:integration`/`build` exist and
  actually run, or is one a stub (`echo "no lint"`)? A stub gate is a mandatory follow-up — it
  must become real before auto-merge can trust green.
- **Main protected?** — is there a branch-protection ruleset + `CODEOWNERS`? If not, the
  gated-merge policy has no server-side wall — flag it.
- **Contract-domain paths** — read them from `docs/architecture/merge-gate.conf`; do **not**
  re-derive them here. That file is the single source, and `merge-gate.sh` already enforces it.
  Missing → run `wai-init` first.

## The deploy model

Details, commands, hardening, backups and rollback are in the runbook:
`references/deployment-guide.md`.

You own the VPS: Docker + Compose, **Caddy** as reverse proxy with auto-TLS, deploy via
GitHub Actions → SSH → `docker compose pull && up -d`, images from **GHCR** (`sha`-tagged for
rollback). You are responsible for provisioning, hardening, backups and rollback — the runbook
covers each. No PaaS layer in between: the pipeline that gates the merge is the same one that
ships the image, and everything of it lives in GitHub.

## Merge gate & branch protection

The platform's gated-merge policy lets `wai-pr-review` **auto-merge** a clean,
non-contract-domain PR — but only if "green" is trustworthy. This skill makes it so:

- **Required checks — the names must be the workflow's JOB names.** GitHub matches a required
  check against the name of a **check run**, which is the job, not the step inside it. The bundled
  `ci.yml` runs lint, type-check, unit and integration as *steps* of one job called `test`, so the
  only check runs it produces are **`test`** and **`security`** — and a ruleset that requires
  `lint` or `build` will make every PR wait forever on *"Expected — waiting for status to be
  reported"*, because nothing will ever report it. GitHub lets you type any name; it will not warn
  you. So: **read the workflow, require exactly the job names it emits.** If you want per-gate
  granularity, split `ci.yml` into one job per gate first — then require those names.
  Also: the image push and the deploy are **post-merge** (`build-push` is `if: main`; the deploy
  runs on `workflow_run`). They never report a check on a PR, so they can never be required checks.
  **If the GitHub plan can't enforce this**
  (rulesets/branch protection return 403 on private repos on the free plan), say so plainly in
  the report: the gate then runs **advisory-only**, the suite's git protocol is the only wall,
  and "green" means "checks ran", not "checks were required" — don't let the setup pretend
  otherwise.
- **No skip-through gates** — every gate job must fail loudly on its own. Watch the `needs:`
  chains: if all jobs `need` a cheap first job (e.g. format check), one miss there **skips**
  the whole downstream gate and the PR looks green while nothing was validated. Prefer
  independent jobs, or make skipped-because-dependency-failed count as red.
- **Real, not vacuous** — the `ci.yml` guard fails a stub gate; flag any stub script as a
  mandatory follow-up.
- **Human-gated contract domains** — `CODEOWNERS` puts a named human on
  API/auth/token/billing/migration changes, matching the policy's escalation. **Enable "require
  Code-Owners review" only in `team`.** In `solo` that owner is also the PR author, GitHub never
  counts an author's own review, and the requirement would make every contract PR unmergeable —
  there, CODEOWNERS *requests* the review and the real gate is the suite's policy:
  `wai-pr-review` never auto-merges a contract-domain PR, the human merges it.
- **Team mode changes what the ruleset must enforce.** Read the `**Repo mode:**` line in the
  catalog header (missing = `solo`). In **`team`**, the ruleset must **require 1 approving
  review** (plus "dismiss stale approvals on push"), and `CODEOWNERS` must name **two or more**
  owners — or a GitHub team — per contract line. That is what makes `wai-pr-review`'s
  `gh pr merge --auto` safe: the PR arms itself and merges the moment another human approves,
  so nothing lands on `main` unseen without anyone having to babysit the checks. Also **enable
  "Allow auto-merge"** in the repo settings — without it the skill can't arm auto-merge and every
  team PR falls back to a manual merge. In `solo`, a single owner and no required approval is the
  correct, deliberate setting.
- **`wai-testing` decides *what* is tested; this skill wires it.** Testing defines the
  mandatory targets and writes the tests (`SEC-*`, `RES-3`, `GDPR-*`, `AI-3`); cicd turns them
  into required checks and provides the CI test infrastructure (ephemeral DB service, the
  integration/e2e job). Until both are in place, keep auto-merge conservative.

## Relation to the quality catalog

If `docs/architecture/quality-attributes.md` exists, align the generated artifacts to it
and cite IDs: secrets handling `SEC-3`, supply-chain/dependency scan `SEC-5`,
testability/required-checks `MAINT-2`, health/zero-downtime/rollback
`RES-5`, backup/DR `RES-6`, CI/CD & IaC `MAINT-3`, observability `OBS-*`,
backward compatibility of the API `API-1`. If the catalog is missing, briefly point this out
(optionally run `wai-init`) and continue working with these points as the default.

## Output format — setup report

Use exactly this structure:

```
## CI/CD setup: [repo name]

**Status:** [Newly set up | Existing detected → change proposal]
**Detected stack:** [languages · build tooling · deployable units · ports · DB]
**Deploy target:** [server/host · Actions → GHCR → Compose over SSH]
**Merge gate:** [required checks enforced via ruleset | advisory-only (plan can't enforce — flagged)]

### Created / Changed
- [path] — [purpose]
- ...

### Secrets (to be stored — no values in the repo)
- GitHub Actions: [GHCR_*, SSH_HOST/USER/KEY, …]
- Server `.env`: [DATABASE_URL, AI_API_KEY, …]

### Manual server steps
1. [provision VPS / harden / install Docker / secrets / first deploy]
2. ...

### To verify / Follow-up tasks
- [e.g. missing /health endpoints, migration strategy, backup target]
- [enable the `main` branch-protection ruleset — required checks always; **`team` only:** require
  1 approving review + Code-Owners review + *Allow auto-merge* (in `solo` a required approval
  would make every PR unmergeable — the author can't approve themselves); replace
  any stub gate scripts (`lint`/`typecheck`/`test:integration`) so auto-merge can trust green]
```

Omit sections that don't apply. With an existing CI/deploy config, the
output ends with the diff proposal and waits for the "go".

## Principles

- **Scan beats assumption** — artifacts reflect the real stack, not a standard setup.
- **Secrets out of the repo** — only references, never values (`SEC-3`).
- **Zero-Downtime & Rollback by design** — tagged images (SHA), healthchecks, an easy
  way back to a previous tag (`RES-5`).
- **Idempotent & non-destructive** — never silently overwrite existing pipeline/Compose.
- **Never commit or push** — the human completes the deployment setup.

## Related Skills

This skill is a **setup** stage (stage 0), parallel to `wai-init`:
- **wai-init** — creates the quality catalog; sensible to run before, so that the
  deploy artifacts are aligned to the right IDs (`SEC-3`, `RES-5`, …).
- **wai-mobile-release** — the mobile counterpart: iOS/Android build, signing and store
  delivery (TestFlight/Play) + the mobile merge gate (this skill covers backend+web only).
- **wai-implementation** — implements subsequent code changes (e.g. missing
  health endpoints that this skill reports as a follow-up task).
- **wai-testing** — defines the mandatory tests this skill wires as **required merge
  checks** (and consumes the ephemeral-DB/integration infrastructure set up here).
- **wai-pr-review** — later evaluates changes to pipeline/deploy against `MAINT-3`/`RES-*`,
  and relies on this skill's gate for its auto-merge decision.
- **wai** — the suite router/overview.
