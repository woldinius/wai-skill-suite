# `merge-gate.sh` — why it is written this way

> The narrative that used to live in this script's comment blocks. Moved here on 2026-08-19, and
> the move is the point: a comment costs context every time a model pulls the file in, and it does
> — when the skill says "run it", when something breaks, when anyone edits the gate. The *rules*
> stayed in the script, where an editor sees them. The *incidents that bought the rules* are here,
> where they are still citable and no longer billed per run.
>
> Nothing was deleted. If a claim below has a date, it keeps it: a claim in a comment rots exactly
> like a claim in a document.

## The gate that never said GO

*A gate that has never said GO is not cautious. It is broken — and the breakage is invisible, because
"no" is what a working gate looks like.*

This gate never said GO. Not once, in two repos, for its entire existence: it read `SKIPPED` as a
failure, and the suite's own CI template ships a job skipped on every PR. The auto-merge path — the
whole reason it exists — shipped **dead**, and nobody noticed for months.

**On 2026-07-15 it said GO.** The first one, in any repo, ever — and it fell to the PR that
documented that it never had. The gate is a validated branch now and not merely a hopeful one; keep
that sentence in the past tense, and keep the date.

The model declined to merge it anyway — docs about its own errors, corrected twice in ten minutes,
were not its to land unread. Both halves were green and it still said no. That is not a rule being
dodged. **That is the judgment half of the conjunction doing its job**, and it is the only recorded
instance of it. ([field report](../field-reports/2026-07-15-backend-web-the-gate-said-go.md))

A gate has four ways to be wrong. Only **one** of them is loud:

| Failure | What you observe |
|---|---|
| says GO when it should say NO | something bad merges. You find out. Everyone designs for this. |
| says NO-GO when it should say GO | **nothing happens** — which is what a gate looks like. Nobody does. |
| right verdict, wrong reason | nobody does. |
| an answer you cannot audit | "the model checked". Nobody does. |

Gates do not die by letting something through. They die by becoming decoration people route around.
So: everyone tests that it **blocks** — the easy path, and the one that fails safe. Almost nobody
tests that it **passes**, and the pass path carries the gate's entire value. If your test plan has
no case that says "here is a PR that SHOULD get GO, and it does", you have tested half the machine.
`tests/run.sh` case 1 is that case, and it exists because of this.

*Fail closed — and then go and check whether "closed" is where it has been the whole time.*

## Three states, not two

The temptation is to fold UNKNOWN into NO-GO — both mean "the human merges", so why distinguish?
Because they are statements about different things:

- **NO-GO** is a fact about the PR. It failed a check.
- **UNKNOWN** is a bug report about the gate. It could not check.

Fold them and you throw away the only signal that says the gate needs fixing — which is exactly the
signal that was missing for the months it never said GO. Folding the other way is worse: a repair
*hint* once went out through `unknown()`, silently upgrading a definite NO-GO to "I couldn't tell".
Never unsafe. But a gate that misreports which of its own states it is in is a gate people stop
reading.

## Why a script and not a paragraph

Anthropic, *Effective context engineering for AI agents*: *hardcoding complex, brittle logic in
prompts to elicit exact agentic behavior creates fragility.* This gate used to be six conditions a
model had to remember on every run — and "the model checked" is not something anyone can audit. You
cannot grep it, you cannot diff it, and six months on you cannot answer whether it happened: the
failure case and the success case produce identical output.

→ [ADR-0002](../adr/0002-mechanics-in-scripts-judgment-in-prompts.md) · [REFERENCES.md](../../REFERENCES.md)

And the line this script must not cross: **it owns mechanics, the model owns judgment.** No script
can decide whether a finding is a Blocker. The gate is one half of a conjunction.

## Repo and base resolution

Those two `gh` calls used to be unguarded, and under `set -e` that made a tool failure look like a
verdict. `gh` exits 1 when it cannot resolve a repository; `set -e` then killed the script with
gh's exit code — and **1 is this gate's code for NO-GO**. In the field: `origin` pointed at a repo
the human had lost access to, the PR lived on a second remote, and the gate reported "a precondition
failed" for a PR it had never even looked at.

That is the exact failure the three-states rule calls unforgivable. Reporting state 2 as state 1 is
corrosive in **both** directions — the human reads a network error as a content verdict, and then
learns to discount NO-GO ("that's just the remote"), which is the state the gate protects `main`
with.

Guarded on **two** conditions, because there are two ways to get nothing: a non-zero exit, and a
*successful* call that printed nothing (the same class as a scanner whose empty output reads as
"zero findings"). Either one is UNKNOWN.

## Required checks and skip-to-green

The old rule was "every reported check must be SUCCESS", which treats `SKIPPED` as a failure. It is
not one — `SKIPPED` means the job's own condition said "do not run". The suite's own `ci.yml` once
shipped a build job gated on `github.ref == 'refs/heads/main'`, so on a PR that job is skipped and
GitHub still reports a check run with conclusion `skipped`. Result: every PR in every repo carried a
permanently non-green check, and this gate returned NO-GO on all of them, forever. (Reproduced on
two PRs, two repos.)

**The obvious fix is a trap.** "Treat SKIPPED as green" opens skip-to-green: put a `paths-ignore` on
the test job, and an API PR skips it, the gate calls it green, and the required check never ran. Same
evasion class the stub guard was hardened against. A fix that swaps one hole for another is not a fix.

So: ask the branch what it **requires**, and judge only that. A required check that is SKIPPED is a
NO-GO — deliberately stricter than GitHub, which lets a skipped required check pass.

## Verdict reasons first

The reasons arrive in check order — ✓ preambles, then the failure — and under any cap the ledger
cell loses its **last** token first. Field-measured (issue #10): median 143 characters of
"everything fine" before the first ✗, so of 7 domain NO-GOs exactly one still carried readable `EX-*`
IDs, and the human reconstructed the rest **by hand** as ledger comments — the most expensive
possible proof that the ordering was wrong.

So ✗ and ? go first, ✓ and · after — reordered at **assembly time only**: the terminal output keeps
its natural check order, and past rows are records (append-only), so only new cells carry the new
order. `index()==1`, not a regex: ✗ is multibyte and a bracket expression over it is byte-roulette.
Guarded like every other line in that function — a reorder that fails falls back to the raw reasons,
because a worse-ordered row is a data gap and aborting the verdict over it would be a real cost.

## Excluded domains: one classifier

Three checks used to live here inline: the hardcoded guardrail floor, the repo's `CONTRACT_PATHS`,
and destructive migrations. They live in **one** place now — `../../wai/scripts/excluded-domains.sh`
— and this gate calls it. The same question ("is this an excluded domain, the human's alone?") is
asked by this everyday gate, by `wai-pr-review`, and by `wai-team`'s autonomous drain. Three inline
copies are three chances to disagree about what is human-only, **and the copy that fails open is the
one that wins.** One definition, cited from the canonical `agent-git-protocol.md` §*Excluded
domains*, cannot drift against itself.

**What moved, and what did not:**

- The hardcoded `GUARDRAIL_PATHS` floor moved *into* the classifier — still hardcoded there, so
  config still cannot lower it. The two-harmless-steps escalation (an agent PR "tidies"
  `merge-gate.conf`, drops `billing/*` from `CONTRACT_PATHS`, then merges billing freely) is closed
  in the floor's new home, not reopened here. `EX-PAY`/`AUTH`/`API`/`SEC`, `EX-MIG` and the new
  `EX-GDPR` live there too.
- **`EX-GDPR` is the hole that refactor closed.** The classifier reads an `ERASURE_PATHS` key *and*
  greps the whole diff for erasure — so an ad-hoc `DELETE FROM users`, `ON DELETE CASCADE` or
  `deleteAccount()` dropped outside any migration file is caught. A path-only check let that
  self-merge through; a whole-diff grep does not.
- **§4 (team-mode approval enforcement) did not move, and must not.** It is a fact about branch
  *protection*, not about the diff's domain — a different question with a different source of truth.

**Fail closed.** The classifier is located from the script's own path, not from the cwd. If it
cannot be found, or it returns UNKNOWN because it could not read the diff, this gate is UNKNOWN and
the human merges. `wai-pr-review` inherits `EX-GDPR` for free: it obeys this exit code, it does not
re-derive the domain set.

## Logging fails open

`emit_ledger` and `emit_runlog` are best-effort and guarded on every line. Losing a row is a data
gap; blocking a correct merge because a file was read-only would be a real cost. The gate fails
**closed**; its logging fails **open**, and the asymmetry is intentional.

The ledger cell's 400-character cap is a word-boundary cut with a visible `…`. The first cap was a
silent `cut -c1-160`, and the ledger's first real row ended mid-token (`test (ubuntu-`) — an
amputation that reads exactly like a complete reason. The second review fixed the ledger cell and
missed the classifier summary two hundred lines down: same cut, same cell, one level deeper. Both
sites share one function now so they cannot drift apart a third time.
