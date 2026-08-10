# GitHub Issues Protocol — intake, findings & tracking

> The shared rule for how wAI skills read and write GitHub Issues. It extends the git
> protocol's one-liner (`agent-git-protocol.md` §*GitHub Issues*) into the authoritative
> version: which skill files what, how findings are escalated, and the format an issue must
> have so it stays actionable weeks later. Issues are the suite's **inbox/outbox**; PRs stay
> the unit of change, and files in `docs/` stay the source of truth issues point into.

## The one rule that matters

**Blockers and Majors are the human's decision point.** By default, a Blocker/Major finding —
from a review, an audit, or a self-review — is **presented to the human** with a
recommendation, and the skill waits. Skills may handle them differently **only when the human
has explicitly mandated it**, e.g.:

- *"Collect them as issues and show me the list at the end"* → file each Blocker/Major as an
  issue (format below), keep working, and end the session with the collected list as a
  decision summary.
- *"Fix them directly"* → hand each finding to `wai-implementation` on the same branch,
  then re-review.

A mandate is per-session or per-task and must come from the human in plain words — a green CI
run, an old memory, or "it seemed low-risk" is **not** a mandate. When in doubt, present and
wait. **Minors/Nits/improvements** never block by themselves — the human doesn't need to be
interrupted for them.

And the decision point is not only about *where a finding lands*. It is the one place the
**question behind the work** is open to challenge: the checks verified that the work is right;
whether the right thing was *asked* is the human's alone (`wai/SKILL.md` §Principles —
*artefacts check the work, not the question*). So when you present a Blocker/Major, present the
**premise** with it, not only the finding — the human is the owner of the *why*, not a router
picking a disposition for output the checks already blessed.

And severity is not the only thing that opens the decision point. A change that touches an
**excluded domain** is the human's no matter how clean the diff or how green the checks — the
canonical set (the contract domain, destructive migration, and **GDPR-erasure / data-deletion**)
is defined once in `agent-git-protocol.md` §*Excluded domains — always the human's, even in autonomy
mode*, and this protocol keeps no copy of it. Routing here reads the **same** set the merge gate
enforces, so an erasure or account-deletion change is presented and waited on exactly as a
Blocker/Major would be — even when nothing about it is *wrong* — and the two can never quietly
disagree about what is always the human's.

## Where a finding lands

The decision point says *who decides*. This says *where the finding ends up* — and it has no
"nowhere" option. Every finding a skill reports ends in **exactly one** of three states:

1. **Fixed now** — implemented in this branch/PR. **No issue**: the PR is the record.
2. **Deliberately rejected** — won't-fix, with the reason stated in the review/report output.
   **No issue**: the recorded reason is the record.
3. **Everything else** — later, larger, blocked, out of scope, needs infrastructure that doesn't
   exist yet, *or still undecided when the run ends* → **filed as an issue. Not optional.**

This is not a new authority: **filing an issue is not acting on it.** A skill still may not fix a
Blocker without a mandate, still may not merge, still may not approve. It may only refuse to let a
finding evaporate. The decision point is what *routes* a finding into 1, 2 or 3 — it is not an
exemption from having to land somewhere. So: present the Blocker/Major and wait, as before; if the
human decides, follow the decision; if the run ends without one, the finding is **filed** rather
than left in a chat log that closes with the session.

The one exception is **exploit detail in a public repo** — see §*Security findings*.

**Against tracker noise:** dedupe is mandatory (below), Nits from the same area may be grouped
into one issue, and every issue carries its severity label so the board stays filterable. The
rule is "no finding is lost", not "one issue per sentence".

## Reading — issue as task source

- When the human names an issue (`#N`, a URL, or "the issue about X"), pull it with
  `gh issue view <N> --comments` and treat title/body/discussion as the requirement or task
  source. Resolve "the issue about X" via `gh issue list --search "X"` before assuming a number.
- An issue is a starting point, not a complete spec — still interview/grill to fill gaps
  (`grilling-protocol.md`).
- Before filing new work, **check it isn't already tracked**: search open issues by **domain
  concept**, not just by the exact wording ("night theme" matches a "dark mode" issue).

## Claiming — one issue, one developer

An issue is a piece of work, and two people building it twice is worse than nobody building it.
So **claim before you start** — every time a skill begins work on an issue. **Whichever skill
starts the work claims it**, and that is usually not implementation: if planning runs first, *it*
claims, because two people can plan the same issue for an hour before either writes a line of
code. (`wai-team` claims per issue inside its run.)

1. **Check it's free:** `gh issue view <N> --json assignees,state`. **The assignee is the claim** —
   it is the only field that says *who*; a label cannot (labels carry no author, so "labelled by
   someone else" is not a thing you can check). Assigned to **someone other than you** → **do not
   start**: report the collision ("#N is already claimed by @x") and move to the next issue.
   Assigned to you in an earlier session → yours, continue. Unassigned → free.
2. **Claim it:** `gh issue edit <N> --add-assignee @me`. This is the same Issues write authority
   skills already have for filing findings — no new permission. Optionally also add an
   `in-progress` label for humans skimming the board; treat it as **cosmetic and best-effort** —
   if the label doesn't exist in this repo, **don't fail and don't create it mid-run**, just skip
   it (`wai-init` offers to create it during setup). The assignment is what counts.
3. **Release it** when the work lands: the PR's `Closes #N` closes the issue on merge (which
   drops it out of the open backlog). If you abandon the issue instead, remove the assignment (and
   the label, if set) so it returns to the backlog free rather than looking claimed forever.

This is cheap in `solo` mode (you are the only claimant) and load-bearing in `team` mode. The
claim is **advisory** — a race is still possible if two people claim within seconds — but it
turns silent duplicate work into a visible, early collision. **Never block the task on it**: if
`gh` is missing, say the claim couldn't be recorded and proceed.

## Writing — filing an issue

Every issue a skill files uses this shape (adapted from the agent-brief pattern):

```
Title: <severity/type prefix if useful> <behavioral summary>

> *Filed by a wAI skill (AI) — see the linked source for full context.*

**Skill:** <which wAI skill produced this, e.g. wai-pr-review>   ← who found it
**Source:** <PR #N / audit report path / plan path / review>       ← the trail back
**Catalog:** <ID(s), e.g. SEC-3, PAY-2>                            ← why it matters
**What & why:** 2–4 sentences: the behavior/risk, anchored to the module or capability
(file paths as hints, not as the spec — they go stale).

**Acceptance criteria** (each independently checkable):
- [ ] <verifiable behavior, e.g. "a replayed webhook credits exactly once">
- [ ] ...

**Out of scope:** <what this issue deliberately does NOT cover — prevents gold-plating>
```

- **Labels:** severity (`blocker` | `major` | `minor` | `nit`) + type
  (`tech-debt` | `follow-up` | `audit` | `improvement` | `bug` | `feature`), plus `security` for a
  security finding and the optional workflow label `in-progress` (claiming, above). Create missing
  labels once (approval-gated — `wai-init` offers this during setup). If the repo has its own
  label scheme, map to it instead of inventing a parallel one.

  **A missing label must never cost you the issue.** `gh issue create --label minor` **fails** if
  `minor` doesn't exist in the repo — and a skill told to "never block the task on Issues being
  wired" would then drop the finding entirely, which is exactly the outcome the landing rule
  exists to prevent. So: if labelling fails, **file the issue without the label** and say so in
  one line (and offer to create the label). The issue is the point; the label is metadata.
- **Dedupe first** (see Reading). If an open issue covers the concept: comment/update it and
  link the new source instead of re-filing.
- **One issue per finding**; a small set of same-area Nits may be grouped into one.
- **A backtick means a citation.** Catalog IDs are cited as `` `SEC-3` `` — everywhere: reviews,
  plans, audits, issues. `catalog-lint.sh` checks every backticked ID against the catalog, so the
  backtick is now load-bearing: it is the difference between *citing* `SEC-8` and merely *mentioning*
  a string that looks like an ID. Discussing a hypothetical or non-existent ID? Write it in plain
  quotes: "SEC-99". Backticking it claims it exists, and the lint will call you on it.

## Who files what

Every row below is an instance of the landing rule: what the skill finds and does **not** fix or
reject in that run, it files.

| Skill | Reads | Writes |
|---|---|---|
| `wai-requirements-planning` | issue as requirement source | **claim it** if it starts the work (assignee + `in-progress`); plan summary back to the issue; **small follow-ups & out-of-scope items as issues instead of planning docs**; risks/open questions that survive the run |
| `wai-implementation` | issue as task source | **claim** (assignee + `in-progress`) before starting; `Closes #N` in the PR body (same-repo only; cross-repo `owner/repo#N` + manual close); **self-review findings it doesn't fix in the PR** as issues |
| `wai-team` | the mandated issue set | **claim each issue** before its cycle; skips issues claimed by another handle and reports them; files the run's leftovers with the decision list |
| `wai-testing` | test-needs notes, plan | **coverage gaps it can't close now** as issues (labelled `follow-up` + severity) |
| `wai-pr-review` | the PR, its plan/issue | deferred **Minors/Nits as issues** — whether or not the PR merges; a human-gated PR's minors are filed too, or they die when the session does. Blocker/Major → **decision point** first, then filed unless fixed or rejected |
| `wai-init` · `wai-cicd` · `wai-mobile-release` | the repo as it is | the setup gaps they find but don't fix in the run — a stub lint job, a missing `/health`, an absent purchase-flow test. A "mandatory follow-up" announced in a chat report and nowhere else is not a follow-up |
| `wai-architecture-audit` | open `audit`-labelled issues (dedupe) | findings that survive the run unfixed and unrejected as issues (Nits may be grouped); the dated report stays the narrative source of truth |
| `wai-security-audit` | open `security`-labelled issues (dedupe) | same, **redacted** — see §*Security findings* |

## Security findings — the one exception, and it is not "don't track it"

For an **exploitable** security finding, publishing is itself the risk. **Check the repo's
visibility first** (`gh repo view --json visibility`) — and understand what "public" covers: an
issue, *and a PR diff, and a committed file*. They are all world-readable, all emailed to
watchers, all permanent. Redacting the issue while committing the exploit to a report in the same
run protects nothing.

The landing rule still holds. What changes is *what may be written down where*:

- **The issue is a redacted placeholder**: severity, catalog ID, the affected capability/module,
  and a pointer. **No reproduction, no payload, no live secret, no exact bypass.** Enough to
  schedule the work, not enough to run the attack.
- **In a public repo the committed report is class-level too** — the same redaction as the issue.
  The exploitable detail goes to the human directly and to whichever private channel they name.
  On GitHub that channel is a **draft security advisory** (the Security tab, or
  `gh api --method POST /repos/{owner}/{repo}/security-advisories`), which stays private until
  published. It is **not** `gh issue create` — there is no such thing as a private issue in a
  public repo, and an agent that reaches for one publishes the finding it was trying to protect.
- **In a private repo** the report may carry the full detail: everyone who can read it can already
  read the code.

"Don't publish the exploit" is a constraint on the *content* of the issue, the report and the PR.
It is never a licence to leave the finding untracked.

## Cross-repo (hybrid topology)

`Closes #N` only closes issues in the **same** repo — a client-repo PR can't auto-close a
backend-repo issue; reference it as `owner/repo#N` and close manually, or track per repo. Keep
the **same `<slug>`** across repos so issue, branch and PRs stay correlatable.

## Graceful fallback

No issue reference, or `gh` missing/unauthenticated → don't fail and don't invent an issue:
proceed with chat intake and file-based artifacts, and offer the exact `gh issue` command as a
proposed manual step. **Never block the task on Issues being wired** — but a Blocker/Major
decision point still happens in chat even without `gh`.

A broken `gh` suspends the *mechanism*, not the landing rule: every finding that would have been
filed is listed explicitly at the end of the run — in the report and in the hand-off — each with
its ready-to-paste `gh issue create` command. "The tracker wasn't reachable" is a reason for the
human to run one command, never a reason for a finding to disappear.
