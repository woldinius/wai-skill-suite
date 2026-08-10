---
name: wai-mobile-release
description: >-
  One-time setup of build, code signing and store delivery for a native iOS or Android repo
  (TestFlight/App Store Connect, or Play Console tracks) — and owner of the mobile merge gate.
  Creates Fastlane lanes or the Gradle release config, signing, the Actions required-check gate,
  branch-protection ruleset, CODEOWNERS, PR template and release runbook. Use it for: "set up the
  iOS build", "Fastlane", "TestFlight", "code signing", "Play Console", "mobile CI", "staged
  rollout". Not for the backend+web pipeline (wai-cicd), implementation, tests or PR review.
license: MIT
---

# Mobile Release Setup

Prepare a **native mobile repo one-time** for build, code signing and store delivery — iOS
(Swift/SwiftUI → TestFlight / App Store Connect) or Android (Kotlin/Compose → Play Console
tracks). The value: a deep scan of the real app and, from it, correct, tailored release
artifacts and a **mobile merge gate** instead of generic boilerplate — as a visible proposal,
nothing is committed. This is the mobile counterpart to `wai-cicd` (which covers
backend+web).

## Platform context

The platform is a multi-surface product; the native apps are first-class surfaces that **cannot
be force-updated** and ship through **store review**, so two things dominate mobile delivery:
- **The store is the gate, not your server.** A release passes Apple/Google review on their
  timeline; the backend must stay backward-compatible for apps still in review/rollout
  (`API-1`/`CLIENT-3`, `references/contract-protocol.md` (in the `wai` skill)).
- **Tokens are digital goods.** Purchase flows go through **StoreKit (iOS) / Play Billing
  (Android)** and are verified server-side (`PAY-*`/`PAY-8`); a release that bills tokens any
  other way will be rejected.

## What this skill produces

Depending on platform (not everything is always needed):

**iOS**
- **Fastlane** setup (`Fastfile`/`Appfile`/`Matchfile`) — lanes for test, beta (TestFlight) and
  release (App Store Connect); **or** Xcode Cloud workflows if preferred.
- **Code signing** via `match` (certificates/profiles in a private repo/secret), or documented
  manual signing — reproducible, no manual certificate juggling (`IOS-5`).
- **`PrivacyInfo.xcprivacy`** reminder + App Privacy / nutrition-label checklist (`IOS-4`),
  in-app account deletion check (`IOS-6`/`GDPR-6`).

**Android**
- **Gradle release config** — signing config via **Play App Signing**, `bundle`/AAB build,
  versioning; **Fastlane (supply)** or Gradle Play Publisher lanes for the Play tracks (`AND-5`).
- **Target-API-level** check against Play's current requirement (`AND-4`); **Data Safety**
  checklist (`AND-3`).

**Both**
- **`.github/workflows/mobile-ci.yml`** — the **merge gate**: real lint (SwiftLint / detekt +
  Android Lint) · build · unit · UI tests · the **contract-consumer test** (the app against its
  generated client, `API-4`) · a secret scan (gitleaks) — as **required checks** on every PR;
  then, on `main`, upload to **TestFlight** / a **Play internal track** (build number/tag from
  the commit). Runs on the right runner (macOS for iOS).
- **`.github/CODEOWNERS`** — **generated from `docs/architecture/merge-gate.conf`** (its
  `CONTRACT_PATHS` is the suite's single answer to which paths are sensitive; a second hand-written
  list would drift from the gate that enforces it). In a mobile repo those are typically the
  generated API client, auth/login, and the StoreKit / Play-Billing code. CODEOWNERS supplies the
  *who*; the conf supplies the *what*. Missing conf → run `wai-init` first, don't guess.
- **`.github/pull_request_template.md`** — judgment-first PR body (what/why, contract version,
  store-policy impact, test plan, risk).
- A **branch-protection ruleset** for `main` (documented as a manual step): require a PR, the
  required checks above, no direct/force push. **Required approvals depend on the repo mode**: in
  **`team`**, require **1 approving review** + Code-Owners review (and enable *Allow auto-merge*).
  In **`solo`**, require **no approvals** — the only human is the PR author, and GitHub never
  counts an author's own review, so a required approval would make every PR unmergeable.
- **`docs/release/<ios|android>-release.md`** — the release runbook (signing, store metadata,
  staged/phased rollout, rollback-by-not-promoting, the submission steps).
- A **setup report** (format below) including the manual store-console steps.

## Stance

- **Scope: one mobile repo.** This skill sets up *this* iOS **or** Android repo. The backend+web
  pipeline is `wai-cicd`.
- **Scan before writing.** Understand the project (scheme/targets or modules, min OS, signing,
  billing, the generated API client) before generating artifacts.
- **One-time & idempotent.** If a Fastfile/workflows/signing config already exist, **don't
  silently overwrite** — deliver a diff/proposal and wait for "go".
- **Secrets out of the repo** (`SEC-3`/`CLIENT-1`). Signing certs/keys, ASC API key, Play service
  account go to Actions secrets / a private match repo / a secret store — never into the repo or
  the binary.
- **Release ≠ merge.** The merge gate makes a PR mergeable; **submitting to store review and
  releasing to users is a separate, human-gated step** (store review, phased rollout). This skill
  wires the upload to a test track; promotion to production stays with the human.
- **Never commit or push.** Everything is a proposal; the human commits and sets up the
  store-console side.

## Process

1. **Scan the repo** — platform (iOS/Android), build system (Xcode scheme/targets, or
   Gradle modules), min OS/target-API level, signing state, billing integration
   (StoreKit/Play Billing), the **generated API client** + its contract version, existing
   Fastlane/Gradle/CI/signing files, GitHub repo slug.
2. **Choose the pipeline** — Fastlane vs Xcode Cloud (iOS); Fastlane supply vs Gradle Play
   Publisher (Android). If unclear from context, ask. Default: **Fastlane + GitHub Actions**.
3. **Generate/tailor artifacts** — adapt to the real scheme/module names, bundle id /
   application id, min OS, tracks. Don't copy blindly.
4. **Secrets plan** — list which secrets go where (Actions secrets, match repo, ASC API key,
   Play service-account JSON) — without ever writing real values.
5. **Write** — create files as a proposal (`fastlane/`, `.github/workflows/mobile-ci.yml`,
   `.github/CODEOWNERS`, PR template, `docs/release/`), and document the `main` branch-protection
   ruleset as a manual step. If existing: propose a diff.
6. **Output the setup report** — including the **manual store-console steps** (App Store Connect
   app + agreements + IAP products; Play Console app + Data Safety + billing products + tracks).

## Merge gate & store submission

The platform's gated-merge policy lets `wai-pr-review` **auto-merge** a clean,
non-contract-domain PR — but only if "green" is trustworthy. For mobile:

- **Required checks** — wire `mobile-ci.yml`'s gate jobs (lint, build, unit, UI, the
  contract-consumer test, secret scan) as **required status checks** in the `main` ruleset.
- **Human-gated contract domains** — `CODEOWNERS` forces the human onto the generated API
  client, auth, and token/billing (StoreKit/Play Billing) code — matching the suite's escalation;
  a billing change is `PAY-*` and always human-merged.
- **Team mode** (the `**Repo mode:**` line in the catalog header; missing = `solo`) — the ruleset
  additionally requires **1 approving review**, `CODEOWNERS` names two or more owners (or a team),
  and *Allow auto-merge* must be on: `wai-pr-review` then arms `gh pr merge --auto` instead
  of merging itself, so a second human always sees the change (git protocol §*Identity & repo
  mode*).
- **Submission is human.** Merge → upload to TestFlight / Play internal track is automatic;
  **submit-for-review and release-to-users (incl. phased rollout %) stay manual.** Store review,
  signing secrets and policy declarations are not something to automate blindly.
- **`wai-testing` decides *what* is tested; this skill wires it.** Until the mandatory
  mobile tests (incl. the purchase flow in sandbox and the contract-consumer test) exist and are
  required, keep auto-merge conservative.

## Relation to the quality catalog

Align artifacts to the surface-scoped catalog and cite IDs: signing/secrets `IOS-5`/`AND-5`/
`SEC-3`/`CLIENT-1`, attestation `IOS-2`/`AND-2`, store-policy `IOS-3`/`AND-3`, privacy
`IOS-4`/`AND-3`/`GDPR-6`, target-API currency `AND-4`, purchase verification/testing `PAY-2..6`,
contract-consumer test `API-4`/`CLIENT-3`. If the catalog is missing, note it once (run
`wai-init` in this repo to generate the surface-scoped catalog) and continue with these
points as the default.

## Output format — setup report

Use exactly this structure:

```
## Mobile release setup: [repo name]

**Status:** [Newly set up | Existing detected → change proposal]
**Platform:** [iOS (Swift) | Android (Kotlin)]
**Detected:** [build system · min OS/target-API · signing state · billing · contract client + version]
**Pipeline:** [Fastlane + GitHub Actions | Xcode Cloud | Gradle Play Publisher]

### Created / Changed
- [path] — [purpose]
- ...

### Secrets (to be stored — no values in the repo)
- GitHub Actions: [ASC_KEY_ID/ISSUER/P8 | PLAY_SERVICE_ACCOUNT_JSON, MATCH_*, …]
- [match repo | keystore store]: [signing certs/keys]

### Manual store-console steps
1. [App Store Connect / Play Console app, agreements, IAP/billing products, tracks, Data Safety]
2. ...

### To verify / Follow-up tasks
- [e.g. enable branch protection — required checks always; **`team` only:** 1 approving review +
  Code-Owners + *Allow auto-merge* (in `solo` a required approval blocks every PR, since the author
  can't approve themselves); missing purchase-flow tests;
  target-API-level bump; privacy manifest / Data Safety accuracy]
```

Omit sections that don't apply. With an existing setup, the output ends with the diff proposal
and waits for the "go".

## Principles

The Stance above governs (scan-first, idempotent, secrets/signing out of repo and binary, never
commit). Two are mobile-specific and load-bearing:
- **Release ≠ merge** — the gate makes a PR mergeable; store submission and rollout stay human.
- **Back-compat is sacred** — apps in review/rollout still hit the live backend; never ship a
  client that needs a breaking contract change before the backend serves it.

## Related Skills

This skill is a **setup** stage (stage 0) for the mobile surfaces, parallel to `wai-cicd`:
- **wai-cicd** — the same role for **backend+web** (Docker/Compose/Hetzner + that surface's
  merge gate). This skill is its mobile counterpart.
- **wai-init** — creates the surface-scoped quality catalog for this mobile repo (`IOS-*` /
  `AND-*` + `CLIENT-*` + the shared core); run it first so the artifacts cite the right IDs.
- **wai-testing** — defines the mandatory mobile tests this skill wires as **required merge
  checks** (purchase-flow sandbox, contract-consumer).
- **wai-pr-review** — evaluates mobile PRs and relies on this skill's gate for its
  auto/human merge decision.
- **wai** — the suite router/overview. Contract rules: `references/contract-protocol.md` (in the `wai` skill).
