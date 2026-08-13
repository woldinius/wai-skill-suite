# Gate ledger

Every row is a verdict this repo's merge gate actually emitted — written by the SCRIPT, not by a
human who had to remember. That is the point: "the model checked" cannot be audited; this can. This
file is the **denominator** of the empirical phase (`docs/learnings/empirical-test-plan.md`, §0–1,
kept in the suite repo).

**APPEND-ONLY.** Never edit or delete a past row. The one thing you add is the `outcome` cell, later,
once you have acted on the PR:

- `ok` — the verdict matched your judgment (a GO you merged; a NO-GO you held or fixed).
- `fp` — **false positive:** a NO-GO you then merged UNCHANGED. The gate was too strict here.
- `fn` — **false negative:** a GO you later judged SHOULD have been blocked.
  **This is the measurement that matters. One `fn` outweighs ten `fp`.** It is the only thing that
  turns "suggestive" into "evidence", and no script can supply it — only you can.
  `fn` is defined on **GO rows only** — a NO-GO cannot be a "should have blocked and did not".
  A NO-GO that blocked for a reason outside the code (CI still running) is `nil`, not `fn`.
- `nil` — the verdict says **nothing about the code** (e.g. a NO-GO caused only by CI still
  running). Excluded from the fp/fn math; counted on its own line by `gate-stats.sh`.

Tags are matched on their **first two characters** — free text after a comma is welcome and
preserved. `ok, besser GO` is the calibration signal: the block was correct by the rules, but a GO
would have been fine here; `gate-stats.sh` counts it as its own metric. A field ledger once carried
20 such suffixed tags and a literal-match parser silently dropped every one — writing them was
never the mistake.

A `MOOT` row is a review that ran AFTER the PR was merged — the gate could prevent nothing. It is
not a decision; leave its outcome blank and do not count it in fp/fn. Its value is the opposite of
a missing row: it records that the gate *ran and was too late*, rather than reading as never-checked.

**Weekly:** read the GO rows you merged. Any you would now block → tag `fn`. Do not skip this; the
`fn` count is the whole reason the ledger exists.

A verdict claimed in a review with **no matching row here** means the reviewer checked from memory
instead of running the gate (empirical-test-plan §0). That is itself a finding.

(Rows up to 2026-08-10 carry `T00:00Z`: they were migrated under a since-retired date-only rule.
They are records and stay as written; newer rows carry the normal UTC timestamp.)

| when (UTC) | PR | verdict | why | outcome |
|---|---|---|---|---|
| 2026-08-05T00:00Z | 12 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✗ main declares no required status checks, so EVERY reported check must be SUCCESS — 2 of 3 are not: test (ubuntu- | ok |
| 2026-08-05T00:00Z | 15 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ 3 CI check(s), all SUCCESS (main declares no required checks — strict rule applied); ✗ touches an excluded domain — the human merges these, always: EX-AUTH EX-CONTRACT EX-GUARD | ok |
| 2026-08-05T00:00Z | 15 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ 3 CI check(s), all SUCCESS (main declares no required checks — strict rule applied); ✗ touches an excluded domain — the human merges these, always: EX-AUTH EX-CONTRACT EX-GUARD | ok |
| 2026-08-06T00:00Z | 17 | GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ 3 CI check(s), all SUCCESS (main declares no required checks — strict rule applied); ✓ no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure) | ok |
| 2026-08-06T00:00Z | 21 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 3 check(s) main requires are SUCCESS; ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT | ok |
| 2026-08-06T00:00Z | 19 | UNKNOWN | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 3 check(s) main requires are SUCCESS; ? the domain classifier could not verify this PR (fail closed): excluded-domains: UNKNOWN — could not read the file list for PR #19 VERDICT: UNKNOWN — could not read the change; held for the human. | need inspection |
| 2026-08-06T00:00Z | 19 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 3 check(s) main requires are SUCCESS; ✗ touches an excluded domain — the human merges these, always: EX-GDPR EX-GUARD | ok |
| 2026-08-07T00:00Z | 30 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✗ main declares no required status checks, so EVERY reported check must be SUCCESS — 1 of 1 are not: ci=IN_PROGRESS; · → declare required checks on main (wai-cicd / wai-init). The gate then judges only those, and a build job that runs on main only stops blocking every PR.; ✗ touches an excluded domain — the human merges these, always:… | |
| 2026-08-07T00:00Z | 30 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ 1 CI check(s), all SUCCESS (main declares no required checks — strict rule applied); ✗ touches an excluded domain — the human merges these, always: EX-API EX-AUTH EX-CONTRACT EX-GDPR EX-GUARD EX-PAY EX-SEC | |
| 2026-08-10T00:00Z | 1 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✗ required check(s) not green: lint=DID-NOT-REPORT test (macos-latest)=DID-NOT-REPORT test (ubuntu-latest)=DID-NOT-REPORT; ✓ no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure) | |
| 2026-08-10T00:00Z | 1 | GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS; ✓ no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure) | |
| 2026-08-11T17:32Z | 2 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS; ✗ touches an excluded domain — the human merges these, always: EX-GUARD | |
| 2026-08-11T21:24Z | 4 | GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS; ✓ no excluded domain touched (guardrail floor, contract domain, destructive migration, erasure) | |
| 2026-08-11T22:21Z | 5 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS; ✗ touches an excluded domain — the human merges these, always: EX-GUARD | |
| 2026-08-11T22:36Z | 6 | NO-GO | ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS; ✗ touches an excluded domain — the human merges these, always: EX-GDPR EX-GUARD EX-PAY EX-SEC | |
| 2026-08-12T20:31Z | 17 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT EX-GUARD; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
| 2026-08-13T05:26Z | 20 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT EX-GDPR; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
<!-- restored 2026-08-13: the row below was appended on the #19 branch and lost when the #19/#20 merge conflict was hand-resolved — the second field occurrence of "an append-only file is what a merge tool silently truncates". Verbatim from agent/woldinius/p4-counterproof; a verdict without a row reads as never-run, and this one ran. -->
| 2026-08-13T05:25Z | 19 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-GUARD; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
| 2026-08-13T19:48Z | 21 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT EX-GUARD; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
| 2026-08-13T20:48Z | 22 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT EX-GUARD; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
| 2026-08-13T21:29Z | 23 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-CONTRACT EX-GUARD; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
| 2026-08-13T22:24Z | 25 | NO-GO | ✗ touches an excluded domain — the human merges these, always: EX-API EX-GDPR EX-GUARD EX-PAY EX-SEC; ✓ quality catalog present; ✓ repo mode: solo; ✓ all 1 check(s) main requires are SUCCESS | |
