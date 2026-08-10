# Error statistics · field run, production iOS repo, 2026-07-13/14

> Translated from the German original; the original remains in the private archive. The product
> repo is anonymized (a production iOS app, native Swift client).

> Collected by the agent session itself, at the owner's request ("how often were you wrong, how
> often were *we* wrong, how often did topics get lost in context").
>
> **Data basis, named honestly:** the 2026-07-13/14 session (suite updates, catalog reconcile,
> ID harmonisation, three PRs, CI setup) plus what git history and the issues of both repos prove
> about earlier sessions. I have no access to earlier chat transcripts — "all experience" here
> means: everything with artefact evidence. Counting is conservative: only concretely provable
> cases, no estimates.

## The numbers, compact

| Category | Count | found by self/mechanical check | median discovery latency |
| --- | --- | --- | --- |
| A · Agent errors (this session) | **7** | 6 of 7 | minutes to 1 day |
| B · "We" were wrong (human + earlier sessions, artefact-backed) | **9** | 8 by new mechanical checks | **days to weeks** |
| C · Context losses / ignored topics | **6** | 5 by lint/gate/CI | days to weeks |
| D · Upstream suite self-corrections (reference, 07-09 → 07-14) | **8 fix PRs** | mostly via field runs | hours to days |

The one number that matters: **category A was found in minutes, categories B/C in days to weeks —
the difference is not diligence, it is whether a mechanical check existed.**

---

## A · Agent errors (this session, 7 cases)

| # | What | Found by | Cost | Root |
| --- | --- | --- | --- | --- |
| A1 | zsh word splitting: unquoted `$FILES` → 4 perl invocations ran into nothing, **no file changed** | own verification grep right after | 1 tool round | assumed shell semantics instead of checking |
| A2 | 3× `Edit` on files that had only been grepped, never read (tool rejection) | tooling, immediately | trivial | process shortcut |
| A3 | **Opened a PR without running the app suite locally** — although that PR introduces exactly the check that runs it. CI run 1 found: the suite had not compiled for days | CI (the agent's own new gate) | 1 CI round | sold "swift test green" as "tests green"; never executed the second suite |
| A4 | First read the 26 "dangling IDs" as real findings, before it was clear: a lint artefact of the suite skills | own re-check in the same working phase | small | believed lint output before understanding the consumer scan |
| A5 | ID collisions (SEC-8/-9, MAINT-4/-6) first preserved as "keep + decision point"; the owner decided full harmonisation → the same file restructured twice on the same day | the owner's decision | double work on the catalog | weighed too conservatively where the cheap time for the rebuild was **now** (4 days old = 30 citations; 4 months = a migration project) |
| A6 | Left `IOS-7` as a local mint inside the baseline's number space during harmonisation (only noted "propose upstream") | upstream lint, next day | small follow-up PR | the rule stood in the sizing doc but was followed only once a check enforced it — **the same error type I criticise under B** |
| A7 | Tried to create an issue in a foreign repo → blocked by the permission classifier, detour via drafts | classifier | replanning | did not anticipate the environment boundary |

Not counted as an error: the locale artefact in CI run 2 (runner simulator en vs. local de) — not
reproducible locally, found in one run and fixed as a determinism pin.

## B · "We" were wrong (artefact-backed, 9 cases)

Drift between what documents/issues claimed and what was:

| # | What | unnoticed for |
| --- | --- | --- |
| B1 | **The app test suite did not compile** (a fake missing a method since an earlier PR) — while the testing strategy claimed "run on every change" | ~3–4 days |
| B2 | **12 roster tests orphaned** (a guard landed, tests never adjusted) | ~3–4 days |
| B3 | Undiscovered **locale dependency** of the suite (German strings hard-expected, never run under en) | since the tests exist |
| B4 | An open issue carried an already-done item (prod-URL fail-fast long fixed) | days |
| B5 | An issue claimed "localisation missing — 100 % hardcoded" — a string catalog had long existed, 4 languages maintained | days |
| B6 | A CSRF-blocker issue presumably obsolete after a backend fix, never closed | days |
| B7 | Requirements doc: a feature "open", actually implemented (with a follow-up bug) | ~1 week |
| B8 | The iOS catalog minted `SEC-8`/`SEC-9` locally, **the backend catalog `MAINT-10`/`MAINT-11`/`SEC-14`** — both against the documented "propose upstream" rule | since creation |
| B9 | CLAUDE.md declared learning mode "active"; in reality silently off since the suite update (ledger at the old location) | ~1 day to discovery, fix pending |

## C · Context losses / ignored topics (6 cases)

| # | What was lost / skipped | Outcome |
| --- | --- | --- |
| C1 | `merge-gate.conf` missing since the gate was introduced → the gate ran **silently on UNKNOWN**, auto-merge de facto off, nobody knew | found by an init re-run; field report → upstream |
| C2 | 34 dimensions without a Red Flag (catalog older than the baseline fix) — reviews cited Red Flags that did not exist | the lint found it; reconcile closed it |
| C3 | "Propose new local IDs upstream" stood in the sizing doc — followed by no session (mine included, see A6) until the lint came | the lint now enforces it |
| C4 | The learning-mode protocol change upstream arrived without a migration signal — without an active search it would have stayed "on, but dead" forever | found; fix open, **postponed repeatedly** |
| C5 | 3 upstream field reports: first blocked, then parked as drafts — the classic candidate for forgetting | moved to the handoff inbox; 1 of 3 already implemented upstream |
| C6 | Backend: updated skills sit there uncommitted + lint red — secured only as a handoff note, pulled by nobody yet | open |

**Within the session itself** nothing was demonstrably lost (todos + memory + landing rule: every
finding was fixed, rejected-with-reason, or filed as an issue). The losses happen **between**
sessions and **between** repos — exactly where no artefact carries them.

## D · Reference: the suite itself (upstream, 07-09 → 07-14)

For calibration of how normal erring is when you measure honestly — the suite corrected itself
**8 times** in 5 days via fix PRs, mostly after field runs: 55 of 89 dimensions without a Red
Flag; the agent could merge the standard it is judged against; an unverified claim in the lint;
3 field findings in one batch; the floor protected the rules but not the enforcers; a lint with
50 % false positives that blocked a PR; a lint that could only ever fail in its home repo; and
**the gate could never say GO — in any repo, ever**.

## Patterns & takeaways

1. **Latency follows the check, not the diligence.** Everything in A was found in minutes
   (because it was verified); everything in B/C took days to weeks — and then fell **within
   24 h** as soon as lint/gate/CI existed. Convention documents behaviour; only a check enforces
   it (C3 vs. A6 shows: that holds for me too).
2. **"Green" is a claim about exactly what ran.** "swift test 95/95" was true and still
   misleading — the second suite was dead (A3/B1). Takeaway: before wiring a check, live through
   it once yourself; always state test claims with the suite's name.
3. **Every new mandatory artefact needs a missing-signal.** merge-gate.conf (C1) and the
   learning-mode switch (C4) are the same error in two costumes: fail-closed/opt-in without a
   report is indistinguishable from "feature not in use". (Sent upstream as field reports.)
4. **Issues and status docs lie with an expiry date.** 4 of ~14 open issues and 3 status claims
   in docs were stale (B4–B7, B9). Takeaway: backlog hygiene as a recurring small pass — or
   issues that age automatically on merge events.
5. **Renumbering economics:** the same correction cost 30 citations in 15 files after 4 days;
   after months it would be a migration project. Resolve collisions immediately, never "later"
   (A5).
6. **Cross-repo is the most lossy seam** (C5/C6): everything that lives only in a chat or a head
   dies with the session — handoff inboxes and issues are the only carriers that survive. Write
   there immediately, always.
