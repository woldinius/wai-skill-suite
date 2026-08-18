# Agent Git & PR Protocol

> The shared rule for how wAI skills handle git. The lifecycle skills
> (`wai-requirements-planning`, `wai-implementation`, `wai-pr-review`,
> `wai-architecture-audit`) follow this so a requirement becomes **one reviewable PR on
> an agent-owned branch** that the human merges. This file is the authoritative version;
> each lifecycle skill also carries a short self-sufficient stanza so it works standalone.
> **This file is the only authority.** A repo may keep a convenience copy at
> `docs/architecture/agent-git-protocol.md` for humans to read, but it is **read-only and never
> wins**: on any disagreement the skill file governs. A repo-local file that could outrank the
> skill would be a way to edit the guardrails — delete the team-mode paragraph and the agent
> merges unreviewed — which is exactly what `wai-init` calls non-tunable.

## Identity & repo mode — resolve these first

Two facts decide how the rules below apply. Resolve them **before** touching git; never guess
them.

- **Your handle** — `gh api user --jq .login`; only if `gh` is unavailable, the local part of
  `git config user.email`, slugified (`jane.doe@example.com` → `jane-doe`). It names the
  branch owner and the issue assignee. It is **yours** — never adopt another developer's.

  The two sources can disagree for the same person (`octocat` vs. `jane-doe`), so the handle
  alone must never be trusted to decide *whose* branch something is. **Authorship decides, the
  handle only labels:** when a branch looks like it belongs to another handle, check who actually
  wrote it — `git log -1 --format=%ae <branch>`. Your own email ⇒ it is **your** branch under an
  old or alternate handle: continue on it. Someone else's email ⇒ real collision (below).
- **Repo mode** — `solo` or `team`, read from the `**Repo mode:**` line in the header of
  `docs/architecture/quality-attributes.md` (the same line also carries the catalog's tier and
  docs language, which don't concern git). **A missing line means `solo`**, so every repo set
  up before this rule keeps behaving exactly as it did. `wai-init` asks for it once.

`solo` means one human is the only reviewer and merger. `team` means more than one human commits
here — so a change needs a second pair of *human* eyes before it reaches `main`, and **nothing
personal may be imposed repo-wide** (see *Personal state* below).

## The one rule that matters

**Skills own `agent/**` branches; `main` is protected.** Skills may create branches, commit,
push, and open/update a PR. Skills **never** commit, push, or force-push **directly** to
`main`. The only way `main` changes is by merging a reviewed PR — and that merge is **gated**:

- **Auto-merge — only `wai-pr-review`, only when safe.** The gate is a **conjunction**: the
  reviewer's judgment (*Merge* — no Blocker/Major) **and** a green run of
  `.claude/skills/wai-pr-review/scripts/merge-gate.sh`, which checks the mechanical
  preconditions below and returns an exit code. **Obey the exit code; never re-derive it from
  memory.** The script is
  fail-closed: "could not verify" is a NO-GO, never a GO. Its checks are:
  - the change touches **no excluded domain.** The canonical set — the contract domain and the
    suite's own guardrails, plus destructive migration and erasure / data-deletion — is defined
    once in §*Excluded domains — always the human's, even in autonomy mode* below; every skill
    cites it from there rather than keeping its own copy, and `merge-gate.sh` enforces this floor
    so no repo config can lower it;
  - **no destructive DB migration** — a drop, a rename, a type narrowing, or any irreversible data
    transform (a `DROP COLUMN` behind a completed backfill still counts);
  - **the required CI checks are green — and there are some.** Zero checks is not green; a repo
    with no gate has nothing to be green.
  - **the quality catalog exists.** No `docs/architecture/quality-attributes.md` ⇒ no repo mode, no
    agreed standard to review against, no evidence a human ever set this repo up ⇒ **never
    auto-merge**.

  How it merges depends on the repo mode:
  - **`solo`** → merge directly (`gh pr merge`, preserving the commit sequence) and delete the
    branch, as before.
  - **`team`** → **never merge directly.** Post the verdict as a PR comment and enable GitHub's
    native auto-merge (`gh pr merge --auto`). The PR then merges *by itself* the moment branch
    protection is satisfied — which in team mode includes **one approving review from another
    human**. The tempo is preserved (nobody has to watch for green checks and press a button),
    but nothing reaches `main` that no second human ever saw.

    **`--auto` is only a gate if the server-side gate exists.** It merges the moment nothing is
    outstanding — so with no rule requiring an approving review, it merges *at once*, and the
    second-human guarantee is gone while the run claims to be waiting for one. Verify a rule
    requiring ≥1 approval actually applies to `main` before arming; if there is none, or
    auto-merge is disabled on the repo, fall back to the ready-to-merge handling below and name
    the missing wall.

  Either way it **files the outstanding Minor findings as GitHub issues** (per
  `issues-protocol.md`) so the deferred minors are tracked, not lost.
- **Blocker/Major = the human's decision point.** By default a Blocker/Major finding is
  **presented to the human** with a recommendation, and the skill waits. Only an **explicit
  mandate from the human** changes that handling — e.g. "collect them as issues and show me at
  the end" or "fix them directly" (`issues-protocol.md` §*The one rule that matters*). A mandate
  is per-session/per-task; when in doubt, present and wait.
- **Every finding lands somewhere.** Fixed in the PR, deliberately rejected with a stated reason,
  or filed as an issue — no fourth outcome (`issues-protocol.md` §*Where a finding lands*).
  Filing is **not** acting: it grants no skill the right to fix, merge or approve anything. It
  only means an undecided finding leaves the session as a tracked issue instead of as nothing.
- **Human merge — required for everything else.** Any Blocker/Major (absent a mandate), any
  contract-domain or destructive-migration change, or red checks → the PR is left **draft +
  flagged** for the human to merge.

**Skills never approve a pull request — not their own, and not a colleague's.** No skill runs
`gh pr review --approve` on any PR, ever. A review verdict is a **comment**. This is what makes
the team gate real: the one approval branch protection waits for must come from a human, and an
agent that could approve *someone else's* PR would satisfy that gate mechanically and merge work
no second human ever read. (GitHub already ignores a PR author's own review, so "don't approve
your own" would be no protection at all — which is why the rule is absolute.)

**Arming several PRs at once is safe only for independent changes.** `gh pr merge --auto` fires
whenever *its* PR turns green and approved, in whatever order the humans approve. That is fine for
changes that don't touch the same ground — and wrong for changes that do, because the second one
would land on a `main` its checks never saw. So: arm freely across **disjoint** work (that is the
normal team run — `wai-team` only starts an issue whose blockers have merged), but for
**interdependent or queued** PRs arm **one at a time** and let it merge before arming the next.
Enabling *Require branches to be up to date before merging* in the ruleset makes GitHub enforce
this for you.

Merging `main` triggers the release build, so when in doubt the PR waits for the human.
**Planning and implementation never merge** — only `wai-pr-review` does.

**If the merge is denied by the environment** (a permission gate or safety classifier refuses
`gh pr merge` — commonly for a PR the agent authored in the same session): don't fight it and
don't retry variations. Leave the PR **ready-to-merge** — post the review verdict as a PR
comment, label it (e.g. `ready-to-merge`), note it in a short **merge queue** list for the
human — and continue the next requirement on a fresh branch. The policy above stays intact;
only the button press moves to the human.

## Excluded domains — always the human's, even in autonomy mode

Some changes are the human's no matter how clean the diff looks or how green the checks are. This
section is the **single canonical definition** of that set. Every skill, script and mode below
**cites it from here** and keeps no copy of its own — exactly the way the contract-domain list has
always lived in one place. When you read "excluded domain" anywhere in the suite, it means precisely
what this section says, and nothing may silently narrow it.

**The set — stated once:**

```
EXCLUDED DOMAINS = contract domain   (EX-PAY ∪ EX-AUTH ∪ EX-API ∪ EX-SEC — includes User Management)
                 ∪ EX-MIG            (destructive DB migration)
                 ∪ EX-GDPR           (erasure / data-deletion)
                 ∪ EX-GUARD          (the hardcoded guardrail floor, a-fortiori)
```

- **Contract domain** keeps its name and meaning: the four families a `main` merge has always
  routed to a human. It is a **subset** of the excluded domains, not a synonym for them.
- **Excluded domains** is the umbrella every autonomy mode reads — contract domain **plus**
  destructive migration, erasure / data-deletion, and the guardrail floor.
- The **six policy domains** are everything except `EX-GUARD`: the domains a human can enumerate,
  and only ever **widen**, when configuring autonomy. `EX-GUARD` is never human-listable because it
  is **hardcoded** (a repo config that could drop it would be a way to edit the guardrails); it is
  in the set a-fortiori. An autonomy floor built by a human (`coordination.conf`) is exactly these
  six, sourced from `excluded-domains.sh --list-domains --policy-only` so the floor and the
  classifier can never quietly disagree.
- **User Management** folds under `EX-AUTH`, but the phrase is kept spelled out here so the
  canonical list is never read as *narrower* than the one it replaced.

**The seven domains — catalog family, authoritative detection, advisory widening:**

| Tag | Catalog family | Authoritative detection (paths + diff) | Advisory-widening only |
|---|---|---|---|
| `EX-GUARD` | quality catalog, testing strategy, gate config, `.claude/skills/**`, CI, build/lint enforcement | hardcoded `GUARDRAIL_PATHS` | — |
| `EX-PAY` | payment / token / billing | `CONTRACT_PATHS` (billing/token globs) | labels; `PAY-` family prefix |
| `EX-AUTH` | auth / login, user management | `CONTRACT_PATHS` (auth/user globs) | labels; `AUTH` family prefix |
| `EX-API` | API contract | `CONTRACT_PATHS` (contract/DTO globs) | labels; `API-` family prefix |
| `EX-SEC` | security | `CONTRACT_PATHS` (security globs) | labels; `SEC-` family prefix |
| `EX-MIG` | destructive migration | `MIGRATION_PATHS` + a destructive-statement grep | labels |
| `EX-GDPR` | erasure / data-deletion | `ERASURE_PATHS` + an erasure grep **over the whole diff** | labels; `GDPR-` family prefix |

`EX-GDPR` closes an everyday self-merge hole. An ad-hoc `DELETE FROM users`, an `ON DELETE CASCADE`,
or a `deleteAccount()` that lands **outside** any migration file used to slip through, because
migration detection only watched `MIGRATION_PATHS`. The erasure grep runs over the **whole** diff,
so erasure is caught wherever it is written, not only inside a migration.

Why the guardrails (`EX-GUARD`) are in the set at all is worth stating, because it is the one domain
with no config knob. The floor covers both what *defines* the standard (the quality catalog, the
testing strategy, `merge-gate.conf`, `.claude/skills/**`) and what *enforces* it (the CI workflows,
`CODEOWNERS`, and the gate's own enforcement logic — the `package.json` scripts, the build files, the
lint and type configs). Protecting the workflow protects the *declaration* `run: pnpm lint`; it does
**not** protect what `pnpm lint` actually does. A skill that could merge a change to the standard it
is judged against — or to the machinery that checks it — does not have a guardrail, it has a
suggestion. `merge-gate.sh` enforces this floor and **no repo config can lower it.**

**Detection is ID-agnostic (ADR-0003).** Paths and diff statements are authoritative; a catalog ID
that appears in the PR's own text is read **only** as a family-prefix widening *hint*. So a
repo-local ID in the `PAY-` family (minted at ≥100) still trips `EX-PAY` — it shares that family — and **no bare number is
ever resolved against a catalog or copied across a repo boundary**: a "GDPR-3" or "GDPR-6" is never
matched as such, and erasure granularity comes from `ERASURE_PATHS` and the grep, not from a number.
Labels and family prefixes may only **ADD** a domain, never subtract one — a missing or renamed
label can never *suppress* a path or diff match.

**The citation dial (#30, decided 2026-08-18).** A citation or label *decides* the verdict only
where its family is **anchored** — the repo declares paths whose shape classifies into it
(`EX-GDPR` anchors on a non-empty `ERASURE_PATHS`). Unanchored, the citation is **reported as
advisory** (`ADVISORY-DOMAINS:` in the classifier's output) but does not gate: where a repo
declares no surface for a family, a citation is documentation, not contact. The rule exists
because the safe version was measured expensive — the false alarm stood alone three times in one
field repo, and the cheapest route to a green gate became *not citing catalog IDs*, the exact
opposite of what the suite instructs. Paths and diff statements stay authoritative everywhere,
and under `--autonomy` an advisory citation still **holds** the drain — autonomy errs closed.

**Enforcement — stated once, two modes:**

- **Everyday mode.** A touched excluded domain ⇒ `merge-gate.sh` returns **NO-GO** ⇒ **the human
  merges.** This is the same human-merge trigger the contract domain always had, now covering the
  full set.
- **Autonomy mode.** The excluded-domain check **precedes and overrides** any autonomy mandate. An
  item touching an excluded domain is dropped from the autonomous drain **before** the mandate is
  applied, kept as a human decision point, and reported — never fixed, merged, or sent autonomously.
- **The blocklist alone is under-inclusive and does NOT authorize autonomy.** Eligibility is an
  **allowlist**, not the mere absence of a blocklist hit: a diff enters the autonomous lane only if
  **every touched path** is inside the human-affirmed `AUTONOMY_SAFE_PATHS` set. Any path not
  provably safe ⇒ **held for the human (fail-closed).** The excluded-domains blocklist stays on top
  as a second, defense-in-depth layer, but it is never the thing that *grants* autonomy.
- **An empty or unaffirmed surface refuses autonomy entirely.** If `CONTRACT_PATHS`, `ERASURE_PATHS`
  or `AUTONOMY_SAFE_PATHS` is empty, or `AUTONOMY_AFFIRMED` is absent, autonomy is off — and under an
  autonomy caller an empty `CONTRACT_PATHS` means "**all** paths are contract-domain," never "no path
  touched." A repo that declines the allowlist gets no autonomy in solo mode; only a team repo, where
  a server-side approving review is the real wall, may run it.
- **No autonomous-merge command exists.** Every merge — autonomous or not — routes through the same
  `merge-gate.sh` conjunction, and the model obeys its exit code rather than re-deriving it. The
  drain-preflight is advisory fail-fast only; a preflight that wrongly *keeps* an item still meets a
  NO-GO at the gate on that item's final diff.
- **Strictly serial.** `post-merge-verify.sh` is a hard barrier between autonomous merges: the next
  one does not start until it returns 0 (`main` is green). Autonomy **may not** combine with bounded
  parallelism or the self-draining queue — arming several PRs at once stays reserved for the
  human-approved, independent-change case above.

**Single mechanism.** All of this is one script — `excluded-domains.sh`, homed next to `doctor.sh` —
with `--autonomy` for the allowlist-eligibility gate and `--list-domains [--policy-only]` for the
floor. `merge-gate.sh` §5–6 **delegate** domain classification to it; `merge-gate.sh` §4 — the
team-mode approving-review enforcement — **stays in `merge-gate.sh`** and is *not* part of the
classifier's remit. The hardcoded `GUARDRAIL_PATHS` floor lives inside the shared script so config
still cannot lower it.

**Who cites this section (and keeps no copy):** `wai-pr-review` and its `merge-gate.sh`;
`wai-team`'s autonomous-integration mode; `wai-learning-gap` Flow D, through
`rank-pr-candidates.sh`'s exclusion filter; the future comms skill's send gate; `contract-protocol.md`
(contract domain as a subset) and `issues-protocol.md` (the routing decision point); and
`coordination-lint.sh`, whose autonomy floor is sourced from `--list-domains --policy-only`. If you
find the domain set written out anywhere else, that copy is the bug — fix it back to a citation.

## Branch

- **One branch per requirement, owned by you:** `agent/<handle>/<type>-<slug>`, cut from the
  latest `origin/main` (`<type>` ∈ feat | fix | refactor | perf | chore | docs, matching
  Conventional Commits). Example: `agent/jane-doe/feat-token-budget`. The handle segment is
  what keeps two developers working the same requirement from landing on the same branch.
- **Reuse your own branch; never take over someone else's.** Before branching, check whether a
  branch for this requirement's `<slug>` already exists (planning pushes it; the PR is opened
  later by implementation). Planning → implementation → review all operate on the **same** branch
  so the PR reads as one unit. Decide by **authorship, not by the name**:
  - `agent/<your-handle>/<type>-<slug>` → yours, continue on it.
  - **A legacy branch without a handle segment** (`agent/<type>-<slug>` — cut before this rule
    existed) whose commits are **yours** → **yours**. Continue on it as-is; do not cut a parallel
    branch, which would orphan its plan commit and its open PR. Renaming it is optional and only
    when no PR is open yet.
  - A branch under another handle, or a legacy branch whose commits carry **someone else's**
    email → **collision, not an invitation**: do not commit to it, do not branch off it — tell
    the human that someone else is already on this requirement, and stop.
- **Who does what:** planning **creates and pushes the branch** (local + remote) with the plan
  commit **when it runs**; implementation **opens the PR** once there is a diff; review evaluates
  that PR. **When planning did not run** — the router sends a scoped change straight to
  implementation, or the change is small enough to need no plan document — **implementation cuts
  the branch itself**. Nobody works on `main` because an earlier step was skipped.
- If you are on `main` (or any default branch), **branch first** — never work directly on it.
- **Branch guard — a hook, not a habit.** `.githooks/pre-commit` **refuses** a commit on
  `main`/`master` (`git config core.hooksPath .githooks`). It used to say *"run
  `git branch --show-current` before committing"* — stated right here, enforced by nothing, and
  **three commits landed on `main` anyway.**

  The third is the whole argument. It carried a fix; the follow-up `git push origin <branch>` pushed
  that **branch ref**, which was unchanged, so it was a **silent no-op**; and `gh pr edit` returned
  **success**, because you *can* edit a merged PR. Every signal came back green while the change sat
  unpushed on the wrong branch. **The failure case looked exactly like the success case** — which is
  the one thing this suite exists to make impossible, and it was left to vigilance in its own repo.

  A human who means it: `git commit --no-verify`. Explicit, visible, chosen.
- **Verify the push and the PR — do not infer them.** `git push origin <branch>` pushes that branch
  *ref*: if the commit went elsewhere, it is a no-op that prints almost nothing. And a URL in the
  output of `gh pr create`/`gh pr edit` is **not** evidence that a PR is open. Check the state:
  `gh pr view <n> --json state,mergeable`. Two independent signals, because one of them lied.
- **And verify the MERGE, which is not the same thing.** A push to a branch whose PR is already
  merged **succeeds**. The commits land on a dead branch, reach nobody's `main`, and `main` stays
  green — because everything that *is* there is correct. **Nothing looks like something that is
  missing.**

  It has happened **three times**: one lost a translation, one lost the enforcement-surface
  **security fix**, one lost a retrospective and an entire docs reorganisation. The third was found
  only because somebody asked which branches were safe to delete — *"every PR is merged, so every
  branch is safe"* would have destroyed the work.

  `.githooks/pre-push` now **refuses** a push to a branch whose PR is MERGED. It fails *open* on a
  `gh` error on purpose — a hook that blocks pushes when you are offline is a hook people delete.
  So keep the backstop, and it is one line:

      # is the branch tip the commit the PR actually merged?
      [ "$(git rev-parse origin/<branch>)" = "$(gh pr view <n> --json headRefOid --jq .headRefOid)" ]

  **Never delete a branch on "the PR is merged".** Delete it on *that*.
- **Clean tree before you switch or rebase.** A branch switch, rebase or `git stash` must not
  drag uncommitted personal state onto another branch. If an open learning gap (🧩 `LEARN #`) is
  in the working tree, resolve it first (`wai-learning-gap`, flow C — resolve and explain), then
  switch. This matters most in `wai-team`'s serial run, which changes branch per issue.
- **Glob note for tooling:** `agent/*` no longer matches — `*` does not cross a `/`. Any CI
  `branches:` filter, ruleset or script that targeted agent branches must use **`agent/**`**.
  Rulesets targeting `main` are unaffected.

## Commit

This is the **only** place the commit format is defined; the skills point here rather than each
carrying their own copy of it.

- **Atomic, Conventional Commits:** one focused commit per coherent step. `<type>` ∈ feat | fix |
  refactor | perf | chore | docs; `<scope>` is the affected component or app. The body explains
  *what* and *why*, never *how*; add `BREAKING CHANGE:` when applicable.

  ```
  feat(billing): add a per-user token budget

  Uncapped spend was possible on the free tier: a single user could drain the
  monthly inference budget. The cap is enforced server-side at debit time.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  ```

- **Stage explicitly; never `git add -A` or `git add .` on a shared branch.** Add the paths you
  changed, by name. `git add -A` stages whatever else is in the tree — and it did: an unrelated
  `merge-gate.sh` change once rode into a **security PR** that way, the exact *"a change to the thing
  that decides which PRs merge must not travel inside another PR"* the guardrail floor exists to
  prevent, arriving through the **staging** step instead of the merge step. The floor guards the
  merge; nothing guards the staging but this.

  This one stays a **discipline, not a hook** — and that is a deliberate split from the branch guard
  above. A branch is a fixed target, so a hook can refuse `main` without ever crying wolf; "staged
  the wrong file" has no fixed target, so a hook would fire on every legitimate multi-file commit,
  get muted, and protect nothing. The cost of a staging slip is also smaller: a reviewable diff, not
  a silent no-op push to the wrong branch. So the branch guard earned its hook (discipline failed
  three times); staging earns a rule. Do **not** re-add the retired *"run `git branch --show-current`
  before every commit"* habit — the hook already owns that, and stating it twice invites the reader
  to trust the words over the enforcement.
- **Provenance trailer on every commit**, naming the model **actually in use** — write the real
  name, as above. `Claude <model name>` is a placeholder in this document, not a string to commit.
- Commit the skill's own durable artifacts on the branch too: the plan
  (`docs/planning/<slug>/`), an audit report (`docs/architecture/audits/`), doc updates.

## The snapshot pattern — how a deliberate sabotage is undone

Some steps in this suite break files **on purpose**: `wai-testing`'s counterproof proves a new
assertion can go red by sabotaging the production line it guards, and the audit playbook's
mutation pass plants one-line mutations to measure the suite's kill rate. The sabotage is the
easy half; the **restore** is where finished work dies. The rule:

- **Before** any deliberate sabotage — or any risky revert of uncommitted work — copy the file(s)
  aside with plain `cp` (to your scratch space, or `<file>.snap` beside it). **Afterwards** copy
  the snapshot back, delete it, and confirm green.
- **Never `git checkout -- <file>`, `git restore <file>` or `git checkout-index` for this.** They
  restore from the **index**, and at that moment the index may contain the sabotage itself (if
  anything staged it) or nothing at all (a file never yet committed). Either way the command
  destroys the finished work — and **exits 0**, so the failure case looks exactly like the
  success case.
- **A ban without a named replacement action breaks under pressure.** That is why this section
  exists as a pattern, not only a prohibition: one field session destroyed finished work **three
  times despite a standing written ban** on exactly these commands — each time while reverting a
  sabotage from a counterproof, each time with a green exit code. What held afterwards was not a
  stronger ban but a named action to reach for instead: `cp` aside before, copy back after.

## Pull request

- Open/update via `gh` (`gh pr create` / `gh pr edit`). Target `main`. Open as **draft** when
  the change touches a contract domain (API, User Management, Login, Security, Token, Billing)
  or has high blast radius, and label it for the human's attention.
- **PR body** (use the repo's `.github/pull_request_template.md` if present), covering:
  what & why + a link to the plan; catalog IDs touched; an explicit **API backward-compat
  statement** for store clients (no breaking change, or the versioning/migration plan); test
  plan; risk / blast-radius. End the body with:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- The PR is the human's review surface. Lead it with what needs a decision, not a green check.

## GitHub Issues — intake & tracking

Issues are the suite's **inbox/outbox**; PRs stay the unit of change. The authoritative rules —
the Blocker/Major decision-point default and its mandate exceptions, the issue format
(behavioral, checkbox acceptance criteria, out-of-scope), the label taxonomy, dedupe-by-concept,
the per-skill read/write matrix, cross-repo handling and the graceful `gh`-missing fallback —
live in **`issues-protocol.md`** next to this file. In short: skills read a named issue as the
task source (`gh issue view <N> --comments`), wire `Closes #N` into the PR (same-repo only),
and file deferred findings as well-formed issues instead of letting them evaporate in chat —
but never block a task on Issues being wired.

## Setup skills stay proposal-only

`wai-init` and `wai-cicd` create high-stakes artifacts (the quality catalog, CI
pipelines, secrets references, deploy config). They **propose** these as a visible diff; the
**human commits** them. They do not take branch/commit/PR authority. (`wai-cicd` may
additionally *generate* the server-side guardrails that make the `main` merge-gate real —
branch-protection ruleset with required checks, `CODEOWNERS` routing contract paths to the
human, PR template — but still as a proposal the human applies.)

## Personal state never becomes repo state

A repo is shared; a developer's habits, skill level and learning progress are not. Anything that
belongs to **one human** must live where only that human sees it, and must be a **no-op for
everyone else**:

- **Never** write a person's name, self-assessment, learning progress or personal preference
  into a committed file (`CLAUDE.md`, `docs/`, `.gitignore`, …). A committed switch is a
  **repo-wide** switch — it will fire in every other developer's session too.
- Personal opt-ins live in the human's own scope: `~/.claude/...`, `.claude/settings.local.json`,
  or `.git/info/exclude` — never in the shared `.gitignore`.
- **Presence of the personal artifact is the opt-in.** A skill with personal state checks
  whether *this* human has that artifact; if not, it does nothing at all — it does not create
  it, does not install a hook, does not ask. (`wai-learning-gap` works exactly this way: no personal
  ledger → the skill is silently off for you.)
- A committed file may *describe* the mechanism (so the team can discover it), but must not
  *activate* it for anyone.
- **A 🧩 `LEARN #` marker is somebody's open exercise — never a bug, never dead code.** It is a
  deliberately broken line in a working tree, waiting for a human. **No skill may fix it, clean it
  up, "restore" it, or delete it as a commented-out block** — that silently steals the exercise and
  hands out an unearned Leitner promotion. This binds *every* skill, and the two that would
  otherwise walk straight into it are the ones that hunt red tests (`wai-testing`) and dead
  code (`wai-architecture-audit`: a box-1 gap *is* a commented-out block, and its safe
  cleanups are applied on approval). If a marker blocks your work, hand it back to the human, or
  ask `wai-learning-gap` to resolve it (flow C) — explicitly, with an explanation. Never in passing.

## Graceful fallback

- **Not a git repo, or `gh` is missing/unauthenticated:** do not fail the task. Produce the
  change plus a **proposed** commit message and PR body, and tell the human the one manual
  step (init git / install + auth `gh`). Degrade to "prepare the change," never to "lose it."
- **Branch would conflict with a moved `main`:** rebase onto the latest `main`; if it does not
  apply cleanly, stop and hand the conflict to the human rather than guessing a resolution.
- **Direct writes to `main` are always refused** — `main` only ever changes via a merged PR
  under the gate above; there is no direct-commit path, and contract-domain / risky merges
  always wait for the human.
