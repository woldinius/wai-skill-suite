# Further learnings from the game-server session (2026-08-02)

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a game-server prototype: a hobby game, repo mode `team`, tier
> `compact`, **deliberately without CI**).

New, reported nowhere yet. Ordered by severity.

---

## 1. `merge-gate.sh` resolves the repo via the git default remote → wrong verdict class

**Observed:** `sh scripts/merge-gate.sh 46` aborted with
`GraphQL: Could not resolve to a Repository …` and **exit 1 = NO-GO**.

**Cause:** the line `REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"`. That
follows the git remote `origin`. In the incident, `origin` was a dead repo (access lost); the work
ran over a second remote. The PR therefore lived somewhere other than where the script looked.

**Why that is dangerous:** the script explicitly distinguishes **NO-GO (1) = a precondition is
violated** from **UNKNOWN (2) = could not be verified**. "Repo not resolvable" is textbook
**UNKNOWN**, but was reported as **NO-GO**. A human who only sees the exit code takes a tool
failure for a substantive judgment — and conversely learns to ignore NO-GO, because "that's just
the remote again".

**Proposal:**
- Make the repo explicitly selectable (`--repo`, `$GH_REPO`, or from the PR branch's remote).
- Map every resolution/network/`gh` failure to **exit 2 (UNKNOWN)**, never to 1.
- The script's error message should say *which* repo it looked for.

*Field workaround:* `gh repo set-default OWNER/REPO` — after that the script judged correctly.

---

## 2. In a repo without CI the gate can **never** say GO — which devalues it

**Observed:** after the repo fix the verdict was still NO-GO, with two ✗:
- `no CI checks report on this PR — zero checks is not 'green'`
- `team mode, but no enforced approval rule on 'main'`

Both are **structural constants** in this repo: its own
`docs/architecture/testing-strategy.md` says explicitly *"Today: none — there is no CI. The gate
is the human"*, and there is simply no second human to approve (father + son).

**Consequence:** the gate reports NO-GO on **every** PR until the end of time. A signal that
never flips is not read — and then the day it is red for a *real* reason passes unnoticed. That
is the classic alarm-fatigue failure.

**Proposal:** the gate should know the repo's **own declaration** instead of enforcing
multi-surface-platform assumptions:
- Extend `merge-gate.conf` with `CI_EXPECTED=yes|no` and `APPROVAL_RULE_EXPECTED=yes|no`
  (pre-filled by `wai-init` from the testing strategy's tier/phase).
- If `CI_EXPECTED=no`, "zero checks" is **not** a ✗ but a note — and the human remains the gate,
  as the testing strategy already says.
- Otherwise everything stays as it is. A gate that does not know its own context gets bypassed
  instead of obeyed.

---

## 3. `wai-requirements-planning`: the plan belongs on the issue **in substance**, not only as a path

**The user's wish, verbatim (translated):** *"Always save the planning outputs to the issue as
well — that is easier for me to organise."*

Today the skill says: *"post a short plan summary + the `docs/planning/<slug>/plan.md` path back
to the issue"* — a summary plus a link. But the user organises his work in the issue tracker, not
in the repo tree. A summary plus path forces him into the code to read the plan; he then never
answers "is this plan good?".

**Proposal:** the **full plan text** goes out as an issue comment; `docs/planning/…` remains the
repo copy, not the primary artefact. Same logic as with the PR verdict (see the other file) — and
it costs nothing.

---

## 4. Bug skills: the "red" measurement must be **falsifiable**, or it invents design questions

**Case:** reported was "I am standing on flat terrain and cannot move".
First measurement: *"38.8 % of flat points have a blocked direction whose target is also flat"* →
looked like a threshold problem. From that followed a **wrong design question** to the user
("should cliffs become more permeable? price: less buildable land"), which would have demanded a
real game-balance decision from him.

**The measurement was too generous:** a real cliff *between* two flat plateaus satisfies the
criterion too — correct behaviour, counted as a defect. The strict measurement (sample the path
in 6-px steps; wrong only if it is steep **nowhere**) yielded: **3,820 false blockades, all
diagonal, zero axis-parallel.** With that the cause was unambiguous (an unnormalised input
vector), the fix one line — and the design question **moot**.

**Proposal for `wai-implementation` (§*build the red first*):** add a sentence like
*"Check whether your red measurement can also be satisfied by correct behaviour. If yes, it is
not yet a defect measurement — sharpen it until only the defect triggers it. A fuzzy measurement
produces phantom findings and phantom decisions for the human."*
The difference here: with the fuzzy measurement the user would have had to make a balance
decision that never existed.

---

## 5. What worked well (please keep / extend)

- **Parallel research subagents before planning.** For two independent issues one Explore agent
  each, with a pure fact-finding brief ("no proposals, no judgment"). Both found things I would
  otherwise have missed: a module that is Node-only and never loaded in the client (without a
  UMD wrapper the glossary would have double-maintained the chains and gone stale); a schema type
  with no time field, where a new field would have been **contract-domain** — the server-internal
  route avoided a human merge gate. Both were course-settings, not details. **Recommendation:**
  name this as a pattern in the planning skill when several issues are planned at once.
- **The gap flow with the building-blocks style** (from the earlier feedback, meanwhile built in
  as "combine the building blocks") holds up. Three gaps this session, all solved without a hint.
  Especially effective: placing the gap **on the just-fixed bug** (vector normalisation right
  after the diagonal fix) — the concept was freshly motivated instead of arbitrarily picked.
- **The rule "a gap may turn a test red, but must not crash the running game"** prevented a bad
  gap location several times (among them an uninitialised MapSchema that would have killed the
  tick).
