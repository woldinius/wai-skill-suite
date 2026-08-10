---
name: wai-learning-gap
description: >-
  Personal learning mode (cloze coding + Leitner), tech-stack agnostic — opt-in per developer, never
  repo-wide. Active ONLY for a human who has a personal ledger under `~/.claude/learning/`; with no
  ledger it does nothing and creates nothing, so colleagues stay untouched. It plants exactly one
  learning gap (🧩 LEARN marker) at the end of an implementation phase, reviews the human's solution,
  and moves topics through Leitner boxes. Triggers: "learning gap", "hint", "solution", "learning
  status", "solved", "check my solution", "skip the gap", "learning mode on/off", "learning axes",
  "combine the building blocks", "learn architecture/domain".
license: MIT
---

# Learning mode: cloze coding with Leitner

The human learns the tech stack on the living project: after every implementation phase,
**exactly one learning gap** is planted — 1–3 related lines they have to restore themselves so
that build/tests go green again. Topics move through Leitner boxes. The goal is to make the learning
stick without slowing implementation down.

## Learning mode is personal, not project-wide

**A repo is shared; a learning state is not.** In a repo with several developers, maybe one of
them is learning the stack — the others want no gaps in their working tree, no hook and no ledger.
Therefore:

**The ledger IS the consent.** The skill is active exactly for the human who has a personal
ledger. No ledger → the skill does **nothing**: it plants no gap, installs no hook, creates no
ledger, and does not even ask. It is silently off for that person. Nothing in the repo may switch
the mode on for anyone else — not a name, not a self-assessment, not a flag in a committed file.

### Ledger location (personal, outside git)

1. **Primary:** `~/.claude/learning/<repo-slug>/ledger.md`. The learning state then belongs to
   **the person**, not to the clone: it survives a second clone, a `git worktree` and a fresh
   checkout — **but only if the slug reflects the repo identity, not the folder name.** So resolve
   in this order:
   - `gh repo view --json nameWithOwner` → `<owner>-<repo>` (stable, whatever the folder is called);
   - otherwise derive the same from `git config remote.origin.url`;
   - only as a last resort the **repo root's** folder name — the *parent* of the common git dir:
     `basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"`.
     Take the parent, not the basename of `--git-common-dir` itself, which is the literal string
     `.git` in every repo — and would put every offline repo into one shared ledger. And **not**
     `--show-toplevel`: in a linked worktree that returns the worktree path, so the learning state
     would differ per worktree — exactly the mistake this location avoids.
2. **Fallback:** `temp/learning/ledger.md` inside the repo — only when `~/.claude/` is not
   writable (CI, container, someone else's machine). Then add `temp/learning/` to
   **`.git/info/exclude`** (local, unshared), *not* to the shared `.gitignore`.

### The identity lives in the ledger, not only in the path

A slug is derived, and derived things drift: the repo is transferred to an org, renamed, or forked;
`gh` is authenticated in one session and not the next. When the slug changes, a path lookup finds
nothing — and the opt-in gate then concludes "this human never opted in" and goes **silent**. The
human's Leitner state is orphaned and, by the very design of the gate, nobody tells them. That is
the one way this skill fails invisibly, so guard it:

- **Record the identity when creating the ledger** — write `nameWithOwner` and the remote URL into
  its header. Identity then lives in the *content*, which does not drift.
- **The gate is a lookup, not a path check.** No ledger at the resolved slug → before concluding
  "not opted in", glob `~/.claude/learning/*/ledger.md` and check whether any of them records
  **this** repo (by remote URL, by a previous `nameWithOwner`, or by the repo name with a different
  owner). A match means the repo moved, not that the human left: say so in one line and offer to
  rename the folder to the new slug. Only "no ledger anywhere claims this repo" means not opted in.
- **Migration (`temp/` → home):** if an old `temp/learning/ledger.md` exists but there is none in
  the home directory (and home is writable), move it there once and say so in one sentence. Never
  keep both — the home ledger wins.

**An existing ledger belongs to the human, not to this skill.** If one is already there, follow
**its** structure, section names and status vocabulary — including when they are in a language
other than this file's. Never rewrite, reformat or translate someone's ledger to match the
template in `references/templates.md`; the template is for creating a *new* one.

### Opt-in / opt-out (by the human)

- **Opt-in:** the human invokes `wai-learning-gap` once, explicitly ("learning mode on", "plant a
  learning gap"). Only then are ledger, stack profile and pre-commit hook created — for them alone.
- **Opt-out — say "learning mode off".** Then: resolve the open gap (flow C), remove the hook,
  archive the ledger. After that the skill is silent for them again.
- **Opting out by deleting the ledger must also be safe**, because people will do it. On its own,
  deleting the file would leave two orphans behind: a deliberately red working tree that no skill
  will ever resolve (learning mode is now off, so flow C can never run), and an executable hook
  that keeps blocking commits with no ledger left to explain why. So the hook **carries its
  ledger's path and disables itself when the ledger is gone** (see `references/templates.md`), and a deleted
  ledger is therefore a clean opt-out. If you find a red tree with a `LEARN #` marker and no
  ledger, resolve the gap once, explain it, remove the hook, and stay silent from then on.
- In projects using the wAI suite, `wai-init` asks the question **for the human running
  init** — and creates *their* ledger, not a repo-wide switch.

### Optional CLAUDE.md anchor (neutral, activates nobody)

The committed `CLAUDE.md` may **describe** the mechanism so the team can find it — it may not
**switch it on**. Exactly this much is allowed, with no name and no self-assessment:

```markdown
## Learning mode (per developer, opt-in)

Learning mode is **personal**: active only for a developer who has a personal ledger
(`~/.claude/learning/<repo>/ledger.md`). For them, the `wai-learning-gap` skill plants one learning
gap (🧩 `LEARN #`, working tree only — a local pre-commit hook blocks committing it) at the end of
an implementation phase. **No ledger → the skill is silently off for you:** no gap, no hook,
nothing created. To opt in, run `wai-learning-gap` once.
Protocol: `.claude/skills/wai-learning-gap/SKILL.md`.
```

## Ground rules (always)

- **Opt-in gate first.** The lookup itself is `ledger-locate.sh`: exit **0** = a ledger claims this
  repo (opted in — the path is printed), **1** = none does (not opted in), **2** = could not resolve
  (fail-closed → treat as not-opted-in and do nothing). It owns the identity-not-path match described
  below, so nothing re-implements the ledger-is-consent check. **If it does not return 0 and the
  human has not just consented → stop immediately, creating nothing.** This human did not opt in.
  Ledger, hook and stack profile are created **only** out of one of the two consents: an **explicit
  invocation** by the human ("learning mode on", "plant a gap") — or a **hand-off from
  `wai-init`** after the human answered its learning-mode question with yes. An automatic call
  from inside `wai-implementation` is **not** consent: without a ledger it is silently skipped
  there. (Whether to *offer a folder rename* on a moved-repo match stays a judgment call — see *The
  identity lives in the ledger*.)
- **At most ONE open gap at a time.** Check **both** sides before planting with `open-gap-check.sh`:
  exit **0** = none open, **1** = an open gap exists (it prints WHICH side — working tree and/or
  ledger — to stdout), **2** = could not read the tree or ledger (UNKNOWN, fail-closed → do not
  plant). Checking both sides matters because the ledger alone is not enough — it is a single
  unlocked file shared across every clone and worktree of the repo, so two concurrent sessions would
  both read "none open" and both plant, while a `LEARN #` can sit in a working tree with no ledger
  row yet. If either side says a gap is open → run flow B or C first. **Concurrent sessions on one
  repo are not supported**; there is no lock, and the ledger's last writer wins.
- **Gaps exist only in the working tree, never in commits.** Plant only AFTER the phase has been
  committed. Because gaps are never committed, **no other developer** ever sees them — and gap
  numbers (`LEARN #12`) are ledger-local, so they never collide across people.
- **Record what you removed.** The gap log row stores the file, the line range and the original
  line(s) (or the `HEAD` blob hash). Flow B verifies the restoration **against that record** — not
  against "no marker and tests are green", which a `git restore` also satisfies.
- **Never carry an open gap across a branch switch.** Before `git checkout`, `switch`, `rebase` or
  `stash` (e.g. when `wai-team` moves to the next issue): resolve the open gap — flow C. A gap
  belongs to the branch it was planted on. Note that git will **not** protect you here: it only
  refuses the switch when the dirty file differs between the branches; the common case is that it
  silently carries the gap over, and flow B then diffs against the wrong `HEAD`.
- **Hook check (idempotent, participants only):** if this human has a ledger, run `install-hook.sh`
  to make sure a pre-commit hook that blocks `LEARN #` actually **runs**. It encodes both common
  traps as mechanics, and returns exit **0** installed/verified · **1** refused (the hooks dir is
  committed to the repo) · **2** git config unreadable (fail-closed). On **exit 1**, fall back to
  blocking-by-check at plant time — do not fight the refusal; it is the one judgment that must never
  be prose, *a personal hook must never become repo state*. The two traps the script handles, so you
  understand what a refusal means:
  - **`core.hooksPath`.** When it is set — husky and lefthook both set it, and they are
    near-ubiquitous in JS/TS repos — git ignores `.git/hooks/` entirely, and a hook written there is
    a **silent no-op**. The script installs into the configured directory instead, chaining any
    existing pre-commit rather than overwriting it. If that directory is committed to the repo
    (husky's `.husky/` is), it **refuses** (exit 1) rather than commit a personal hook into repo
    state.
  - **Existence ≠ execution.** The file merely existing proves nothing; the script verifies it is
    executable and is the file git will actually run.

  **Without a ledger, install no hook** — it would burden a colleague who never consented.
- **Ledger:** personal, see *Ledger location* above. If it is missing **and** the human wants to
  opt in, create it from the template in `references/templates.md`.
- **Stack profile & learning axes (idempotent, first run):** if the ledger has no "Stack profile"
  section, create it once: detect the stack from the **manifests** — `references/stacks.md` lists
  them per platform (web · desktop · iOS · Android · server/tooling). No `docs/` scan: architecture
  docs teach no idioms. **A stack the list does not name is a normal case, not a failure** — say
  which files you did find, ask the human what the stack is and how the project builds and tests,
  and record both in the ledger. You need that command for every gap anyway. Then ask the human **briefly** for a
  self-assessment per technology (one question, options: solid / basics / new) and record the
  result as topic starting points: known starts in box 3, basics in box 2, new in box 1. In the
  same first-run step, elicit the **three learning axes** — tech-stack / architecture /
  domain-implementation — each with its own level (`off` · `basics` · `focus`), and record them in a
  `## Learning axes` ledger table (see *Learning axes*). The axis says *which kind* of line a gap
  lands on, the box says *how hard* — they are orthogonal. All of this stays in the personal ledger;
  it **never** goes into the repo.

  **Split the idempotency gate.** The step also fires when a "Stack profile" section already exists
  but the `## Learning axes` table is **absent**: for a template-shaped ledger, add **only** that
  table and touch nothing else, so a ledger created before axes existed gains them without a rewrite.
  A human-authored ledger whose shape differs is left exactly as it is — Flow A's axis filter then
  degrades to "all axes eligible" for it (`ledger-lint.sh` reports, never rewrites). Once both
  sections are present this step is skipped.
- **No learning mode** when: the human says "skip", during urgent hotfixes, or for pure
  docs/comment changes with no runtime effect.

## Learning axes — which KIND of line, and how each fails visibly

A **box** is *how hard* a gap is (the Leitner schedule); an **axis** is *which kind* of line it
lands on. They are orthogonal — every topic carries both. The three axes live in the ledger's
`## Learning axes` table, each with its own level (`off` · `basics` · `focus`; `off` plants nothing
from that axis, `focus` outweighs `basics` in selection):

- **tech-stack** — language and framework idioms, syntax, library APIs, build/config semantics.
  Fails visibly as a **compile or type error**.
- **domain-implementation** — the business rules the code encodes. Fails visibly as a **red test on
  a line the suite already covers** (confirm with `verify-gap-breaks.sh`). If no test covers the
  line, it is not a domain gap — choose another line or axis.
- **architecture** — structural patterns: layering, dependency direction, module boundaries,
  protocol/interface conformance, DI registration. **Prefer a build-breaking structural line** (a
  removed conformance, a deleted DI registration, a cross-layer call). **Only if none exists**, fall
  back to a **Socratic gap** — a question about the structure that stays green.

**The Socratic gap is a separate, non-removal form.** It removes no code and uses its **own**
difficulty ladder (box 1–2 *locate*, box 3 *trace*, box 4+ *why*) — never the combine/reconstruct
rungs, and the ingredient machinery and `shuffle-ingredients.sh` do not apply to it. It records an
**expected answer** in the gap log; Flow B checks the human's written explanation against it.

**The Socratic pre-commit blind spot.** A Socratic gap leaves the tree green, so the pre-commit hook
and CI are **no backstop**: deleting its marker without answering drops the gap silently, and
`verify-gap-breaks.sh` must not be run against it (it would wrongly reject a gap green by design).
Only Flow B's comparison against the recorded answer closes it; `ledger-lint.sh` enforces that the
answer was recorded at all.

When a gap teaches a cross-cutting concern that the quality catalog names, cite that dimension **by
its name**, never a bare catalog ID (ADR-0003). Full per-axis detail and the architecture-gap ladder
are in `references/axes.md`.

## Flow A — plant a gap (end of every implementation phase)

1. **Green first, then the gap.** The project's build/test commands (see its CLAUDE.md, e.g.
   `swift test`, `npm test`, `./gradlew test`) must pass BEFORE the gap is created. Commit the
   phase as usual. That way red afterwards = the exercise only.

   **And the gap is the last action before handing back to the human.** An open gap makes the
   working tree deliberately red. If another skill runs on the same branch afterwards
   (`wai-testing`, `wai-pr-review`), it sees the red and quietly "repairs" the exercise
   away, or reports the phase as failed. So **plant no gap** when something else is still meant to
   run on this branch in the same turn, when a branch switch is coming — or when an **autopilot**
   is running (`wai-team` working through a batch of issues): nobody is at the keyboard to
   close the gap there, it would only block the run. The normal case is the interactive one:
   commit the phase, plant the gap, hand control back to the human.

   Once planted, confirm the gap fails visibly with `verify-gap-breaks.sh` — **except against a
   Socratic architecture gap**, which stays green by design and would be wrongly rejected by the
   probe (pass its `--form socratic` and it skips). Every other gap must go red.
2. **Topic choice:** prefer due topics from low boxes (see the ledger), within the stack profile.
   **Axis filter:** consider only topics whose axis is enabled in the `## Learning axes` table,
   weighting a `focus` axis above a `basics` one; which axis a line belongs to is model judgment
   (`ledger-lint.sh` checks only that the label is a valid enum, not that it is the *right* one).
   **Backward-compatible default:** when the ledger has **no** `## Learning axes` table (a
   human-authored or older ledger, or before the axes question is answered), axis-filtering degrades
   to **all axes eligible / no filtering** — the skill plants exactly as it does today and never
   rewrites the ledger to add the table.
   **Interleaving:** if the diff offers a line for a due topic from a *different* area than the one
   just implemented, prefer that over the freshly written code — spaced repetition teaches better
   than "just saw it, immediately quizzed on it". If no due topic fits the current diff, take the
   most instructive new concept from the code you just changed (→ new topic, box 1).
3. **Line choice:** 1–3 related lines carrying one concept (a language feature, a framework idiom,
   build/config semantics, …). Exclusions:
   - nothing security-critical (auth, secrets, keychain, consent, billing),
   - no generated or vendored files (per project convention — lockfiles, build output, generated
     clients, project files a tool rewrites),
   - no lines whose absence would **silently** succeed — the gap MUST fail visibly, preferably as a
     compile/type error or a red test.
4. **Difficulty by the topic's box (the code-removal ladder):**
   - **Box 1–2 — restore:** leave the original line(s) commented out and **visible**; the exercise
     is understand + restore + answer the why-question.
   - **Box 3 — combine the building blocks:** remove the line(s); the marker lists the required
     ingredients as an **unordered** set (grouped calls/keywords · variables · operators/math,
     sorted within each bucket by `shuffle-ingredients.sh` so presentation order never leaks usage
     order). The human assembles them.
   - **Box 4–5 — reconstruct:** remove the line(s) entirely; only the task description remains.

   All three CODE-REMOVAL rungs still fail visibly — confirm with `verify-gap-breaks.sh`. The
   Socratic architecture gap is a separate, non-removal form (see *Learning axes*) and does not use
   this ladder.
5. **Plant the marker** in the file's comment syntax (`//`, `#`, `<!-- -->`, …); format per the
   marker template above.
6. **Update the ledger:** new row in the gap log (status `open`), and add the topic to box 1 if it
   is new.
7. **Closing message:** file:line (clickable), the exercise, the concrete verification command, and
   the escalation: "Say **hint** for a more concrete tip, **solution** for code + explanation.
   (`git diff` gives the solution away — cheating works, but only hurts you.)"

## Flow B — review (the human reports a solution, or the marker is gone next turn)

1. **Check:** marker removed? Build/tests green? Is the restored code correct and idiomatic —
   compared against **the original line(s) recorded in the gap log**, not merely against "the tree
   is clean"? An equivalent-but-different solution is fine and counts as solved.

   **A clean tree is not a solve.** `git restore`, `git checkout -- <file>` and `git stash` all
   produce exactly the "solved" state: marker gone, tree matches `HEAD`, tests green. So does an
   agent obeying the git protocol's *clean the tree before you switch* rule. Never infer a solve
   from state alone: a box promotion requires an explicit claim from the human ("solved", "check my
   solution") **or** a recorded edit of their own. Marker gone with no claim → status `expired`,
   box **unchanged**.

   **Socratic gaps verify against the recorded answer.** A Socratic architecture gap leaves the tree
   green, so there is no red-to-clean transition to read: assess the human's written explanation
   against the **expected answer recorded in the gap log** (`Original` column, for a `socratic`
   form). A solve is always an explicit claim *plus* that answer — never inferred from the green
   tree; marker gone with no answer → `expired`, box unchanged.
2. **Leitner update:** solved without a hint → box +1 (max 5) · solved with a hint → box stays ·
   solved wrong / solution requested → box −1 (min 1) · expired without a claim → box unchanged.
3. **Feedback (2–4 sentences):** what is the concept, and why is it needed *here*? On mistakes,
   correct concretely instead of just saying "wrong".
4. **Ledger:** set the status (`solved` / `solved-with-hint` / `solved-with-solution` / `expired`),
   record the date and the box movement.
5. **Leave the tree in a defined state.** This is what keeps the whole mechanism honest: an
   equivalent solution means `tree ≠ HEAD`, and an uncommitted improvement left lying around will
   be stashed by the next skill that cleans the tree — or buried under the next gap. So finish the
   job: **amend the solution onto the phase commit and update the PR** (it is the human's code and
   belongs in the change), or, if they'd rather not keep it, restore to `HEAD`. Say which you did.
   After flow B the working tree is clean again, and `git diff` once more means "an open gap".

## Flow C — expiry (gap in the way, or older than one phase)

Policy: **tempo wins.** If an open gap blocks the next phase, or is older than one phase: resolve
it yourself, explain the solution in 2–4 sentences, ledger status `resolved (Claude)`, box −1.
Then carry on as normal.

## Flow D — post-autopilot offer (opt-in, one gap, off a merged commit)

After a **clean** `wai-team` run, the most instructive change of the batch can seed exactly
**one** learning gap — never a queue. This flow is strictly opt-in and has hard preconditions; when
any one fails, it plants nothing and says nothing.

1. **Interactive precondition (checked, not assumed).** There must be a human present at the
   hand-back. On a headless, scheduled or otherwise non-interactive run, **skip silently and plant
   nothing** — an autopilot has nobody to close a gap, so a gap there is pure obstruction. This is a
   checked precondition, not an intention.
2. **Opt-in gate.** Run `ledger-locate.sh`; only exit **0** (a ledger claims this repo) means this
   human opted in. Exit 1 (none) or 2 (could not resolve → fail-closed) → do nothing, create
   nothing. `wai-team` itself never checks a ledger.
3. **One open gap.** Run `open-gap-check.sh`; if either side already has an open gap (exit 1), or it
   cannot read (exit 2), do not plant.
4. **Pick the change.** `rank-pr-candidates.sh` shortlists the run's PRs by cheap proxies with the
   excluded-domain no-go zones already removed (it calls the shared classifier, not a private list);
   you pick the single most instructive PR and the one line and axis worth learning. Only exit **0**
   yields a shortlist; **1** (no eligible PR — all excluded) and **2** (the PR list could not be
   read → fail-closed) both mean **plant nothing**.
5. **Branch discipline.** Plant on a **fresh `agent/learn-*` branch cut from the merged commit** —
   **never** on `main`'s working tree, and never on a still-open PR branch. The gap is the human's
   to solve on their own branch, off code that already landed.
6. **Plant via Flow A.** From here Flow D **hands to Flow A** (topic/axis/box choice, the
   code-removal ladder or a Socratic gap, `verify-gap-breaks.sh`, the ledger row). Flow D adds only
   the preconditions and the branch.

## Hint escalation

- **Level 0** is already in the marker: a concept hint, no solution code.
- **"hint"** → level 1: more concrete (names e.g. the type, wrapper or operator), still no code.
- **"solution"** → full code + a mini explanation (3–5 sentences); counts as wrong in Leitner.
- Record every escalation level in the ledger's "Hints" column.

## Leitner due-dates

A **phase** is **one hand-back to the human** — not one commit. A turn that produces three commits
is still one phase and still gets at most one gap. (Read standalone, outside the wAI suite,
this is the definition that matters: plant when you are done and handing control back.)

Box 1: always due · Box 2: after ≥2 phases · Box 3: after ≥5 · Box 4: after ≥10 ·
Box 5: mastered, sprinkle in only occasionally.

## Template: marker (use each file's comment syntax)

**Box 1–2 (restore) — the original line stays, commented and visible:**

```
// 🧩 LEARN #12 [tech-stack · state/mutable-binding] ★★☆
// Task: restore the line below. Why is an immutable binding not enough here?
// Hint: the declaration form whose value may still change after initialisation.
// Check: the build passes and the counter test goes green.
// var attempts = 0
```

The `//` is illustrative: **use whatever the file uses** — `#`, `--`, `%`, `<!-- -->`. The examples
are stack-neutral on purpose — a worked example in one language reads as *the* template to a reader
whose repo is another.

**Box 3 (combine the building blocks) — line removed, ingredients listed unordered:**

```
// 🧩 LEARN #17 [tech-stack · async/error-handling] ★★★
// Task: rebuild the one line that awaits the fetch and turns a thrown error into a returned result.
// Ingredients (unordered — assembling them is the exercise):
//   calls/keywords: await · try · catch · return
//   variables:      response · fallback
//   operators:      = · ?
// Check: the error-path test goes green.
```

The ingredient buckets are a **complete** set with usage order and nesting **omitted** — the model
does the bucketing (a lexer across every language is out of scope) and `shuffle-ingredients.sh`
sorts within each bucket so order never leaks. For **box 4–5 (reconstruct)** the ingredients are
omitted too — only the task description remains. A **Socratic** architecture gap uses none of this:
it carries a question and a recorded expected answer, not code (see *Learning axes* and
`references/axes.md`).

## Templates: ledger and pre-commit hook

Both live in `references/templates.md` — they are one-time artifacts (a ledger is created once per
repo, the hook installed once per participant), so they load only when those flows run. Use the
ledger template for a **new** ledger only; an existing one keeps its own shape (see *Ledger
location*). For the hook, **prefer `scripts/install-hook.sh`**: it writes into the directory git
actually runs (`core.hooksPath`-aware), chains a pre-existing hook, refuses a repo-committed hooks
dir, and embeds the ledger path so the hook self-disables when the human opts out.

**What this hook cannot catch**, and why the gap log records the original line(s): a human who
deletes the marker comment *without* restoring the code stages no `LEARN #` at all, so the commit
passes. Only flow B's comparison against the recorded original catches that — the hook is the
backstop, not the proof.
