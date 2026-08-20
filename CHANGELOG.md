# Changelog

Notable changes to the wAI skill suite. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags, and every claim here is
checkable against the tagged tree — `tests/numbers-lint.sh` keeps the measurable ones honest.

## [Unreleased]

### Changed

- **`wai-implementation` gains a step that actually runs something — plus a bounded fix loop, a
  ratchet and a real diff read.** Read against
  [obra/superpowers](https://github.com/obra/superpowers) (MIT), the suite's default doer had four
  places where it could hand back finished-looking work with nothing behind it. **A new step 6,
  *Prove it*:** name the one command that proves the change, run it *now*, and paste it and its
  output into the PR under **Verification** — and for a bug, re-run step 1's red command and see
  it go **green**. Nothing in the skill had ever *executed* anything: step 1 built a red command
  that no later step re-ran, step 5 read the diff against the catalog, step 7 opened the PR. That
  is [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)'s own failure shape —
  *"the model checked" is not a thing anyone can audit* — sitting unnoticed at home. Where no
  command can prove it, the skill must now *say so* (`"not verified locally: <why>"`): fail-open
  is allowed, silence is not. **Step 1** bounds the bug fix loop — hypothesis written before the
  first edit, one variable at a time, revert before retry, and **stop after three** rather than
  stacking a fourth patch on a wrong hypothesis class. **Step 3**'s stop condition now re-fires on
  what the *code* reveals mid-implementation (the step 2 delta check only ever covered what the
  *human* changed after planning) and **ratchets one way only**. **Step 5** starts from a full
  `git diff <base>...HEAD` read and closes by naming the strongest reason a reviewer would reject
  the change. Steps renumbered 6 → 7 → 8 → 9 with every cross-reference updated; no other skill
  referenced these numbers. The source, and the two borrows deliberately **rejected** — the TDD
  iron law (it conflicts with `wai-testing` owning tests) and the sub-500-word budget (that is
  **K8**/**Q5**, and it needs its own ADR with the measurement attached) — are recorded in
  [REFERENCES.md](REFERENCES.md), in the same commit, per that file's own rule.

## [0.3.1] — 2026-08-19

### Changed

- **The catalog QA pass — 91 → 87 IDs, and a gap in a family now means "retired".** A
  four-question review (benefit / SMART bar / red-flag logic / word count) of all 91 IDs, landed
  in the master baseline, the live catalog and the three regenerated variants. Four IDs retired,
  never renumbered — the gap is the signal, and `## Retired IDs` names each successor:
  `IOS-2` → `CLIENT-2` and `AND-2` → `CLIENT-2` (their red flags described server-side behavior
  invisible in a client repo; `CLIENT-2` now names the concrete mechanisms and the degradation
  path), `IOS-6` → `GDPR-6` and `AND-6` → `GDPR-6` (in-app deletion is part of `GDPR-6`'s rule).
  Eleven rows rewritten so the rule is decidable and the flag observable (`SEC-13`, `AI-4`,
  `AI-7`, `RES-6`, `OBS-3`, `PERF-1`, `PERF-4`, `PERF-5`, `MAINT-9`, `PAY-11`, `WEB-4` — the
  last gaining the CWV "good" thresholds LCP ≤ 2.5 s / CLS ≤ 0.1 / INP ≤ 200 ms), plus `WEB-1`'s
  flag repointed at the observable symptom (crediting in the redirect instead of the verified
  webhook). Twenty rows trimmed without changing their rule. `PAY-12`'s cross-reference fixed:
  distinct from `GDPR-*` (consumer/tax law, not data protection), and `CLIENT-5` now names its
  bar (WCAG 2.1 AA).
- **The rules stay in the script, the incidents move to `docs/rationale/`.** Measured on
  2026-08-19: the shipped scripts carried **29,180 words of comment against 27,440 words of code**
  — more prose than all thirteen `SKILL.md` files put together — with 60 % of it in 68 blocks of
  eight lines or more. That prose is free on disk and expensive in a context window, and these
  files *do* get opened. So each of the five biggest now keeps its rule at the line an editor would
  break, and the incident that bought the rule moved one directory over: `merge-gate.sh`
  3,699 → 2,496 comment words, `excluded-domains.sh` 2,430 → 2,236, `catalog-lint.sh` 2,078 →
  1,193, `doctor.sh` 2,064 → 1,508, `contract-lint.sh` 1,399 → 851 (**−3,386, −29 %**).
  **No behaviour changed and nothing was deleted** — `Usage:`, every `exit N`, the fail-open /
  fail-closed declarations and the editor warnings stayed put; 5,732 words of narrative are now
  under `docs/rationale/`, read as dated evidence like a field report and deliberately outside
  `numbers-lint`'s living set. A second pass finished the job across the remaining tree:
  **seventeen more scripts** moved their narrative the same way (seven others were confirmed
  all-operative and left alone), so every shipped script now carries its rules at the line and
  its incidents in `docs/rationale/`.

### Fixed

- A **dead link in `merge-gate.sh`'s header** pointed at `docs/learnings/field-reports/` with a
  German filename — a path that never existed in this repo, hiding in a comment where neither the
  link test nor `lang-guard` looks.
- Three example IDs became real citations the moment they landed under `docs/`: `catalog-lint`
  failed on "AI-503", "API-5" and "MAINT-10". They are foreign or invented IDs and now carry plain
  quotes — the repo's own convention, and the rule one of the moved blocks explains.

## [0.3.0] — 2026-08-18

### Changed

- **The citation dial — READ THIS BEFORE UPGRADING** (#30). A catalog citation (`SEC-7`, `GDPR-1`)
  now **decides** the excluded-domain verdict only where the family is *anchored*: the repo
  declares paths whose shape classifies into it. Unanchored, the citation is **reported** on a
  visible `ADVISORY-DOMAINS:` line — in the verdict and in the ledger row — and does **not** gate.
  **A repo upgrading from 0.2.0 will see GO where it saw NO-GO**, on diffs whose only excluded-
  domain contact was a citation to a family it declares no paths for. Paths and diff statements
  stay authoritative everywhere, the widening rule stays widen-only, and under `--autonomy` an
  advisory citation still **HOLDS** the drain — autonomy errs closed, always. Why: measured cost.
  In one field repo (124 verdicts, 0 fn over 37 judged GOs) the citation false alarm stood alone
  three times — once on an author's own *"SEC-7: unchanged"* self-review line — and the cheapest
  route to a green gate became *"do not cite catalog IDs"*, the exact opposite of what every skill
  instructs. Both field cases are pinned as fixtures.
- **The gate ledger's home is decided: in-repo, and rows belong on `main`** (#35). The evidence
  loop is the reason — `numbers-lint` re-measures the ledger's published claims in CI, and a
  ledger under `~/.claude/` cannot be re-measured by anything. The cost of in-repo is the squash
  race that has now deleted a row twice; the mitigation is a rule the gate prints itself, every
  time it lands a row off the default branch, and that a fresh ledger's generated header teaches
  from day one. Field repos may still choose the personal path; that door stays open in #35.

### Added

- **`tests/release-lint.sh`** — the tree must not silently disagree with its newest tag. Two
  relations, both mechanical: work shipped since the newest tag under `.claude/skills/**` must be
  declared in this changelog (an `## [Unreleased]` heading or a newer version's), and the plugin
  manifests' version string must never be *behind* the newest tag — asymmetric, because *ahead* is
  the normal state of a release PR. Written because the fix below sat on `main`, unreleased and
  unrecorded, while both documented install paths pinned the release without it.
- **The invocation denominator** (#29): `wai/scripts/invocation-log.sh` plus an opt-in `PostToolUse`
  hook (`--snippet` prints the block for `.claude/settings.local.json`, never the committed
  `settings.json` — a committed hook is a repo-wide switch). One row per skill *start*, with no
  outcome column, ever: the denominator for "how often does a skill actually run", beside the
  run log's model-written numerator.
- **The installer's no-op answer** (field-reported): an update that changes nothing now *says so*
  — `diff -rq` over exactly the set `install.sh` owns, rather than a hash over a tree it does not.
  A version stamp that advances silently over zero delta reads as "something happened", and the
  next audit inherits that misread.
- **`numbers-lint` reaches the marketplace copy** — `.claude-plugin/*.json` joined the living set,
  and the script-count pattern grew an adjective slot. "27 enforcement scripts and 300+ tests"
  had evaded the lint twice over: outside its glob, and written vaguely enough that no pattern
  could match. A "300+" is not a modest claim, it is an unfalsifiable one.
- **`numbers-lint` re-measures Q3's judged-NO-GO count** — the open-questions agenda drifted from
  5 to 26 judged rows without noticing that its own exit criterion (≥ 20 human-tagged rows) had
  been met.

### Fixed

- **Default paths resolve against the repo, not the accident of the cwd** (#29 pt.1) — seven
  scripts (`merge-gate`, `excluded-domains`, `run-log`, `gate-stats`, `doctor`, `open-items`,
  `retro-compliance`). Run per the skills' own documented invocation — *"from this skill's
  directory"* — `merge-gate.sh` produced a **false verdict** (*"no quality catalog"*, in the repo
  that has one) and planted a stray gate-ledger **inside `.claude/skills/`**, the very tree
  `install.sh` copies into every target repo. The same class made `gate-stats` report "no ledger"
  over 28 rows and `doctor` audit the *skill folder* as if it were the repo, printing "no drift"
  over a missing catalog. An explicit argument or env override still wins; outside any repo the
  cwd stays the base.
- **Squash-aware denominators** (#24, #27) — `open-items.sh` and `retro-compliance.sh` take the
  merged-PR set from the authority `gh` answers from, instead of `git log --merges`, which sees
  nothing at all in a squash-merge repo. `traced share` was "not derivable" for two consecutive
  retrospectives because of it.
- The `case … esac` inside `$( )` — a bash 3.2 syntax error that shellcheck passes — shipped for
  the **fifth** time, in the advisory dedupe, and took out 27 cases at once. `merge-gate.sh`'s
  header count of four is now five.

### Evidence

- Two retrospectives cut from artifacts and dated (#31, #32) — the second records a merge deleting
  a row from an append-only ledger while the row count went *up*, and three cwd-wrong invocations
  in the retro skill's own documentation, both fixed above.

## [0.2.0] — 2026-08-14

### Added

- **`wai-retro`** — the thirteenth skill (#14): retrospectives **from artifacts, at a threshold —
  never from recall** ("reports happen when someone asks": ~250 field verdicts produced zero
  reports in between, and a from-memory retrospective reported 2 of 6 verified collaboration
  failures). Triggered by doctor's report-cadence advisory or on request, it consumes
  `gate-stats.sh --report`, the run log and the open-items footer, narrates with raw row counts
  beside every rate (ADR-0002: scripts extract, the model narrates, the human judges), and
  finishes with `--report --mark` so the cadence resets. Ships
  `wai-retro/scripts/retro-compliance.sh`: run-log rows × gate-ledger rows × `git log --merges`
  → the share of merged PRs that left a trace. The collaboration level is gated until a question
  trace exists; publication to this repo is explicit-request only, sanitized and pseudonymized
  (`fr-<12hex>`, keyed hash, key stays with the reporter).

- **Hand-back instrumentation** (#11, #7). A **run log** beside the gate ledger
  (`wai/scripts/run-log.sh` → `docs/architecture/run-log.md`, append-only, fail-open): one
  attendance row per skill run, because the record used to measure side effects, not work — a run
  that filed nothing vanished. `merge-gate.sh`, `backlog-scan.sh` and `dep-cve-scan.sh` self-log
  (their script↔skill mapping is 1:1); the prose skills log at their hand-off step.
- **`wai/scripts/open-items.sh`** — the derived hand-back footer: open PRs, issues assigned to the
  handle, branches with unique commits and no PR, the merged-but-unreachable sweep, untagged
  ledger rows, merged PRs since the last audit, foreign worktrees — pasted verbatim beneath every
  `▶ Recommended next`, because self-recall under-reports ~3×. Empty lines name their derivation,
  absent artifact classes are skipped and named, a dead `gh` degrades per line.

- **`wai-team` package mode** (#12): the mandate can group issues into ordered packages with one
  branch/PR per package; worktree handling is honest about what exists, and a run that finds
  nothing to fix has a name — "Verified — nothing to fix" — instead of inventing work.
- **Counterproof as the rule** (#9): prove a test red before trusting it green, verify survivors,
  count hits, snapshot before sabotage — in the testing skill, the audit playbook and the git
  protocol's snapshot pattern.
- **Evidence-chain repair** (#8, #10): ledger outcome tags match on a 2-char prefix and unmatched
  tags are counted, never silently dropped; ledger why-cells put ✗/? reasons first; `gate-stats.sh
  --report [--mark]` emits the dated report extract and plants the cadence marker; doctor carries
  the report-cadence advisory (threshold 25, `REPORT_THRESHOLD` override).
- **The installer's ledger guarantee** (#10): every `rm -rf` in `install.sh` stays inside
  `.claude/skills/`, and `docs/` — above all the gate ledger and the run log — is never touched by
  an update; held by a byte-identical fixture test. The three-week field-ledger report landed as
  dated evidence beside it.
- The suite is its own **plugin marketplace**: `/plugin marketplace add woldinius/wai-skill-suite`,
  then `/plugin install wai-suite@wai`. `install.sh` remains as the copy-into-repo path.
- This changelog, and a README section stating exactly what the suite writes into a repo — and
  what it never touches.

### Changed

- **The purpose leads the pitch, and the premise is named**: README intro, plugin and
  marketplace descriptions now state what the suite is for — sustainable software product
  development, maintainable and clean architecture, first-class security — and why it works the
  way it does: even frontier models lose context, are confident when wrong, and forget rules, so
  each goal gets a gate, a rule, or a deterministic check instead of a reminder; keywords follow.
- **Token-reduction pass** over the 13 SKILL.md bodies (−2,972 words, −7.7%): repeated rationale
  and narrative padding removed, every normative rule, script contract, pinned format and counted
  claim kept — the full battery holds it.
- **`wai-learning-gap`**: the open-gap sweep sees every worktree of the repo (#13), and difficulty
  now scales hint strength instead of answer visibility (#3).

- **Provider-neutral deployment**: `wai-cicd`'s model is unchanged (GitHub Actions → GHCR →
  Docker Compose over SSH to your own Linux server) but no longer names a hosting provider;
  the runbook reference is now `references/deployment-guide.md`.
- **Platform context framed as the worked example** in the seven skills that carry it: the
  suite's home platform stays concrete, and the framing sentence says what it is — an
  illustration `wai-init` scopes to *your* repo, not a claim about your codebase.
- **Skill prompts phrase script calls relative to the skill's own directory**, so the same
  sentence is true in a repo install and in the plugin cache.
- Timestamps written by suite scripts carry normal UTC time again; the date-only rule is retired.

### Fixed

- **PR #19's gate row, lost to a merge-conflict resolution, restored verbatim** with provenance —
  field evidence for the known class "append-only files are what merge tools silently truncate".
- **doctor's hooksPath check canonicalizes both sides** (#18), so an absolute `core.hooksPath`
  pointing at the repo's own `.githooks` no longer reads as drift.
- Every inline rule in the skills is anchored to its catalog ID, and two contradictions between
  skills were resolved.
- Dead references to archived audit/proposal files unlinked.

## [0.1.0] — 2026-08-10

### Added

- First release of the fresh repository: twelve skills, twenty-four enforcement scripts, the
  quality-catalog system (one master, three generated variants — ADR-0004), the mechanical merge
  gate with its append-only ledger, the numbers/lang/link lints, and the dated evidence base
  (field reports, empirics, ADRs, retrospective). The prior repository's history is summarized
  in `docs/history.md`.
