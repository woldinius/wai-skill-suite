# Field report: the gate held up over 30 runs — including the one find only it could make

**Repo:** a hobby game-server repo (`solo` mode, two developers + one agent) — one of the
suite's field repos; the name stays in the private archive.
**Period:** 2026-07-22 to 2026-08-06 · suite versions up to `819923d`
**Why this report:** the field reports here mostly collect what went wrong. These numbers say
something else, and they are worth recording before someone mistakes the rule for bureaucracy.
*(Translated; the German original — filed as a suite issue — is in the private archive.)*

## The numbers

```
30 verdicts the script demonstrably emitted
   GO 5 · NO-GO 22 · UNKNOWN 0
   0 of 12 judged NO-GOs were false-positive
   0 false negatives
```

Every row is proof the gate **ran** — not that a model remembered. That is the whole point of the
construction, and it holds: I could not claim any of these 30 decisions after the fact without the
row being missing.

## The case that carries it

One PR (#137) was described as "documentation only, no code" — and that was true of what I had
written. But the branch had accidentally been cut from the wrong predecessor and carried
**22 files** along — among them the repo's contract file.

The gate said `EX-CONTRACT` and NO-GO.

Neither CI nor my own review text would have caught it: CI was green (the tests did pass), and my
review described the diff I had *meant*. The classifier describes the diff that is **there**.
Without it, an unreviewed feature bundle would have ridden a docs PR onto `main`.

## Two observations for the evaluation

**1. "GO" does not mean "merge", and the script says so itself.** On #133 the gate was green and
the PR still did not merge — the review had found a Major (a function bypassed the feature
kill-switch, making sources indestructible and the win condition unreachable). The verdict text
literally says *"Merge only if your review also found no Blocker/Major."* The conjunction of
mechanical and judgment verdicts is valuable in practice exactly where the two halves
**diverge** — and here they did, twice, in both directions.

**2. The only two false alarms were not code findings but time and text artifacts:**

- **`EX-SEC` on a PR that touches no security file.** The trigger was the widening rule: the only
  `SEC-` occurrence in the diff was a line in the bundled plan document stating that `SEC-7` is
  **not** affected. Mechanically correct (a cited family may only widen), a false alarm in effect.
  **Probably systematic:** `wai-requirements-planning` writes a *Cross-cutting requirements*
  section with catalog IDs into every plan — every PR that carries its own plan document hits the
  rule. → Filed upstream as a suite issue.
- **`test=IN_PROGRESS`.** The gate was asked right after a push, while CI was still building. The
  right answer to a badly-timed question.

Both are conservative (they stop rather than pass) and therefore the right direction. The first
one still deserves a look.

## What I take from it

Over the same period I found **not a single substantial error by reading** — every one came from
something that ran and disagreed: a measurement, a revert cross-check, or the gate. In that lineup
the gate is the only tool that also disagrees when the agent is currently **convinced** it is
right. That is exactly why it must not be overrulable, and exactly why the ledger row matters more
than the verdict: the row is the part you cannot invent afterwards.

One open spot in the same chain is reported separately
([2026-08-06-merged-but-not-on-main.md](2026-08-06-merged-but-not-on-main.md)): the gate checks
the *diff*, never its *destination* — a PR can be "merged" and still arrive nowhere.
