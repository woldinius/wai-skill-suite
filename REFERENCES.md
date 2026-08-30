# References

The sources this suite was designed against — and, for each, **what it changed here**.

A link without its consequence is a bookmark, not a reference. Until 2026-07-14 **none of this was in
the repo**: five of these sources changed the two most load-bearing artifacts in the suite, and a
reader could not have told. The gate looked like an arbitrary shell script; the word limit enforced
in CI looked like it came from nowhere. **An arbitrary-looking rule is a rule the next person
deletes.**

---

## Evaluated — and what came of it

### Anthropic · *Effective context engineering for AI agents*
<https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>
**2026-07-13 · adopted**

> *"Hardcoding complex, brittle logic in prompts to elicit exact agentic behavior creates fragility."*

That sentence is the **entire reason `merge-gate.sh` and `catalog-lint.sh` are scripts** rather than
paragraphs in a `SKILL.md`. → [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)

Also adopted:

- **Just-in-time retrieval** — `references/` load on demand; progressive disclosure in three levels.
- **Tool clarity** — *"if a human engineer can't definitively say which tool should be used, an AI
  agent can't be expected to do better."* This is why every skill description carries a
  `Not for X — use Y` clause.

**Named, not yet acted on:** its anti-pattern — *"teams will often stuff a laundry list of edge cases
into a prompt… **we do not recommend this**."* **0 of 12 skills has an Examples section.** Tracked and
deferred on purpose until the field data says *which* rules never fire.

### The LLM-wiki pattern — **ingest → query → lint**
Referenced from the OKF article below. *The specific repository is not preserved; re-establishing the
URL is still open.*
**2026-07-13 · adopted**

A knowledge base has three operations. This suite **wrote** documents (`wai-init`, the audits)
and **read** them (ten of twelve skills) — and had **never once linted them**. That is how **55 of 89
dimensions came to have no Red Flag** while every skill was being told to *"look up the Red Flag for
ID X"*. Nobody noticed, because nothing checked.

`catalog-lint.sh` exists because of that one line, and has since found six further defects that no
amount of reading found. → [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)

### Anthropic · *The Complete Guide to Building Skills for Claude*
<https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf>
**2026-07-13 · adopted, and since 2026-07-14 enforced**

Five hard limits. They used to be things I remembered; they are now **assertions in `tests/run.sh`,
run in CI**:

| Limit | Why it is not a style rule |
|---|---|
| `description` under 1024 chars | it is loaded into **every** session — it is the routing surface |
| **no angle brackets in frontmatter** | frontmatter enters the **system prompt**; this is a security boundary, not formatting |
| `SKILL.md` under 5 000 words | attention budget |
| kebab-case folders, no `README.md` inside a skill folder | discovery |

### Google Cloud · *How the Open Knowledge Format can improve data sharing*
<https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing>
**2026-07-13 · evaluated — and the change it inspired was REJECTED**

I proposed splitting the 91-dimension catalog into 91 addressable OKF files. **The user approved it.
Then the arithmetic killed it, and I reversed my own recommendation.** The split was *my* invention:
OKF requires no such thing — `type` is its only required field, and consumers **must not** reject on
a missing `index.md`. → [ADR-0001](docs/adr/0001-the-catalog-stays-one-file.md)

The **conformance** half — frontmatter, stable IDs, addressability *without* a split — is still
open, together with the real token win the analysis did surface: the router, `wai-cicd` and
`wai-mobile-release` load all **518 lines** when they need about six IDs.

### hivetrail · *The Anthropic context-engineering guide*
<https://hivetrail.com/blog/anthropic-context-engineering-guide>
**2026-07-13 · evaluated, largely rejected**

It elevates "just-in-time exploration" to a **principle**, then sells context **pre-assembly** — its
own product. The Anthropic original it summarises is more careful and recommends a **hybrid**. Read
the source, not the summary. **A negative result is a result**, and it is written down here so the
question is not asked a third time.

### Jason Wei · *Verifier's Law / the asymmetry of verification*
<https://www.jasonwei.net/blog/asymmetry-of-verification-and-verifiers-law>
**2026-08-06 · adopted (via the external audit)**

> *"The ease of training AI to solve a task is proportional to how verifiable the task is."*

The principle behind [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)'s
split, named upstream: the script owns what is cheap to verify (an exit code), the model owns
what is expensive (judgment), and **where verifiability collapses, the human is the design, not
the fallback**. Landed as a dated addendum in the ADR itself — the reasoning existed there since
July; the audit supplied the name and the source.

### CodeRabbit · *Quality gates for AI-generated code* / Codacy · *AI Code Review Is Not Enough*
<https://www.coderabbit.ai/guides/ai-generated-code-quality-gate> ·
<https://blog.codacy.com/ai-code-review-is-not-enough-how-engineering-leaders-should-gate-ai-generated-code>
**2026-08-06 · evaluated — changed the README's framing, not the design**

The category has a name — **quality gate**, with *policy-as-code* as the config discipline — and
the honest competitive line is a **level** distinction, not an existence claim: deterministic
*flow* and pre-review filters exist elsewhere (Codacy's own recommendation: AI advisory, branch
protection recognises only deterministic checks — this suite's §3 semantics, independently
arrived at); a deterministic *verdict inside the agent's own loop* is this suite's position.
Consequence: the README names the category, the prior art, and the level — and dropped nothing
of the design. An earlier draft claim ("the verdict is deterministic *nowhere else*") was
**rejected** during the audit as an unfalsifiable negative — the exact claim class the
publication rule exists for.

### obra/superpowers
<https://github.com/obra/superpowers> (MIT)
**2026-08-20 · partially adopted** · **2026-08-30 · re-read in full (14 skills); the three lanes
it covers and this suite does not are named below, as pointers rather than plans**

A software-development methodology shipped as composable skills. Read against
`wai-implementation`, it is strong on the one axis this suite is thinnest on: **evidence and
process discipline *during* the build**, where the suite had invested almost everything in
judgment *before* it. The four primitives below each closed a place where `wai-implementation`
could hand back finished-looking work with nothing behind it.

| Source skill | What it became here |
|---|---|
| `verification-before-completion` — *"no completion claims without fresh verification evidence"* | **step 6, *Prove it*** — name the command, run it now, paste it and its output into the PR. For a bug, step 1's red command must be re-run **green**. Until this, nothing in the skill ever *ran* anything: step 1 built a red command that no later step re-ran, step 5 read the diff against the catalog, step 7 opened the PR. That is [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)'s own failure shape — *"the model checked" is not a thing anyone can audit* — sitting unnoticed in the suite's default doer |
| `systematic-debugging` — the three-strikes rule | the bug branch of **step 1** now bounds its fix loop: hypothesis written before the first edit, one variable at a time, a failed attempt reverted before the next (the snapshot pattern), and **stop after three** — handing back what each attempt ruled out instead of stacking a fourth patch on a wrong model |
| `brainstorming` — *"hidden complexity upgrades the path; nothing downgrades mid-task"* | **step 3**'s stop condition **re-fires on discovery** and ratchets one way only. The gap: the plan-delta check (step 2) covered what the *human* changed after planning, and nothing at all covered what the *code* revealed mid-implementation — a contract domain reached after the gate had already said proceed |
| `requesting-code-review` — crafted context beats remembered context | **step 5** now starts from a full read of `git diff <base>...HEAD` and closes by naming the strongest reason a reviewer would reject the change. It had said "check your own diff" without ever requiring the diff be read — which is how a self-review becomes a checklist run against intent |

**Rejected — with the reason, so it is not asked a third time:**

- **The TDD iron law** (`test-driven-development`: no production code before a failing test).
  Incompatible with a split this suite made deliberately — `wai-testing` owns tests,
  `wai-implementation` only *notes* the needs, and the strategy bans speculative unit tests in
  favour of end-to-end-testable functions. The two places test-first genuinely pays are already
  kept: *bug → build the red first*, and the mid-implementation invocation for **foundational
  seams**. Adopting the law wholesale would buy duplication, not coverage.
- **The word budget** (`writing-skills`: frequently-loaded skills under ~500 words, detail
  displaced into `references/`). Correct on the merits, and already on this repo's own record as
  criticism **K8** and open question **Q5** (context cost per run, unmeasured). Deferred on
  purpose: it is a *suite-wide* convention — all twelve skills carry the same Platform-context
  and Affected-surfaces sections, and `wai-init` generates its catalog variants against them. One
  skill cut in isolation buys the inconsistency **without** the measurement, so it belongs in its
  own ADR with Q5's numbers attached. Recorded here rather than in a backlog because the negative
  result is the expensive half.

**Not adopted — because the gap is ours, not theirs.** Three lanes superpowers covers that this
suite does not cover *at all*. They are listed as **pointers, not plans**: nothing here is
scheduled, and a reader who needs one of them today is better served by going and reading the
source than by waiting for a wAI version of it.

- **`writing-skills` — testing what a prompt actually does.** This suite tests the two scripts that
  own the verdict with 184 cases on two shells, and tests its **thirteen prompts with nothing**.
  That is not a suspicion; it is written down in this repo already:
  [`docs/learnings/empirical-test-plan.md`](docs/learnings/empirical-test-plan.md) opens with
  *"everything built in this session is specification-verified, not behaviour-verified."*
  superpowers supplies the missing **method** — write the failing scenario first, watch an agent
  violate the rule *without* the skill, then write minimal guidance against that observed failure;
  micro-test behaviour-shaping rules at 5+ repetitions against a no-guidance control. That is a
  usable instrument for **Q2** (does the model *run* the gate or check from memory?) and **Q4**
  (are the three lenses different, or decoration?), both of which have stayed open for lack of a
  method rather than lack of will. The irony is worth naming: [ADR-0002](docs/adr/0002-mechanics-in-scripts-judgment-in-prompts.md)
  moves mechanics into scripts *because a rule in a prompt fails silently* — and then the suite
  tests only the scripts.
- **`receiving-code-review` — the other end of a finding.** This suite is thorough about
  *producing* findings (`wai-pr-review`, both audits) and about *where a finding lands*
  (`issues-protocol.md`: fixed, rejected, or filed — no fourth outcome). It says nothing about how
  to **receive** one: verify the claim against the code before implementing it, clarify the whole
  set before starting on part of it, and push back with technical reasoning when the reviewer is
  wrong. That last one matters more here than upstream, because in this suite the reviewer is
  frequently an *agent* and the recipient is a human who did not write the finding.
- **`using-git-worktrees` — nothing owns their lifecycle.** `wai-team` parallelises *through*
  worktrees and four scripts (`open-gap-check`, `doctor`, `open-items`, `verify-arrival`) *sweep*
  them, but no skill creates or cleans one. The cost is measured, not hypothetical: on 2026-08-20
  two deleted scratchpad worktrees left stale registrations behind and `open-gap-check` fail-closed
  at **exit 2** — a red in this repo's own suite, from worktree bookkeeping nobody owns.
  superpowers has the four rules that were missing: detect existing isolation before creating any,
  prefer the harness's native worktree tool over raw `git worktree` ("never fight the harness"),
  verify the directory is ignored, and baseline-test before starting.

**One caution for anyone tempted to install both.** These skills reference each other, and one of
them **contradicts this suite's merge path**: `finishing-a-development-branch` offers *"merge
locally — switch to base, pull, merge"* as its first option, which `agent-git-protocol.md` forbids
outright (only `wai-pr-review` merges, only through the gate). Loading that one installs a
documented route around the guardrail this repo exists to defend. `receiving-code-review` and
`using-git-worktrees` are the two that are safely loadable side by side; they touch nothing on the
merge path.

**And one correction to the table above,** because half an adoption recorded as a whole one is the
kind of drift this file exists to prevent: what was taken from `requesting-code-review` was the
*lesser* half. Reading your own diff is now step 5 — but the skill's actual thesis is that a
reviewer should get **crafted context and no session history**, and `wai-pr-review` still runs in
the same session as the work it reviews. That was demonstrated on the very PR that added the rule
(#50): the review declared itself a self-review and could not audit its way out of it. Open, and
named as open.

### mattpocock/skills
<https://github.com/mattpocock/skills> (MIT)
**2026-07-09 · partially adopted**

The `grilling` primitive — one question at a time, a recommended answer attached, a hard confirm gate
— became the **"grill me" mode** (`wai/references/grilling-protocol.md`). The Agent-Brief format
for filed issues shaped `wai/references/issues-protocol.md`. The two-axis PR review (standards
vs. spec) informed `wai-pr-review/references/review-lenses.md`.

---

## Collected — not yet assessed

Added by the repo owner. **These have not been evaluated against the suite, and nothing in it was
derived from them.** Listed honestly rather than implied to be sources.

- <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>
- <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
- <https://obsidian.md/help/vault>
- <https://claude.ai/public/artifacts/f498a4cc-4c45-481c-a6dd-8e1d196dadb0>

---

## The rule this file exists to enforce

**When a source changes the suite, it lands here in the same commit — with the consequence, not just
the link.** Decisions that carry weight get an [ADR](docs/adr/); the rest get a line above.

The most expensive thing to lose is a **negative** result: the split we did *not* do, and the reason
it died. Nothing recorded that the question had even been asked — so it would have been asked again.
