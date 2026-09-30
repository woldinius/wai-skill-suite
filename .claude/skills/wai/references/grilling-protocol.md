# Grilling Protocol — the interrogation primitive

> The shared rule for how wAI skills interview the human when a requirement or decision needs
> genuine shared understanding. `wai-requirements-planning` uses it as its **"grill me"** mode;
> a `wai-team` run follows its §*Unattended runs*. This file is the single source of truth for
> the technique — skills reference it rather than restating it. Adapted in part from
> mattpocock/skills — MIT, Copyright (c) 2026 Matt Pocock: [notice](third-party-notices.md).

## The core

Interview the human **relentlessly** about every aspect of the plan or requirement until you
reach a **shared understanding**. The plan is a **design tree**: settling one decision opens the
decisions that depend on it.

1. **Ask in rounds over the frontier.** The **frontier** is every open decision whose
   prerequisites are settled. Each round asks the whole frontier; a question that depends on
   another one still open waits for a later round. Recompute the frontier after each round's
   answers. **Opt-out:** when the human asks for "one at a time" (in the session or in their
   `CLAUDE.md`), ask singly, in dependency order.
2. **Attach a recommended answer to every question.** The human should mostly be confirming or
   overriding, not doing your thinking. Its place: §*Question format*.
3. **Facts vs. decisions.** If a *fact* can be found in the codebase, the docs, the contract or
   an issue — look it up, never ask; do it **in the background** through a subagent (the
   built-in `Explore`), so only the questions that depend on its result wait. The *decisions*
   belong to the human: put each one to them and wait.
4. **Offer alternatives when the requirement is imprecise.** If the requirement or change is
   not sharply specified, don't just interrogate the stated path — propose **2–3 alternative
   solution options** (each with one-line trade-offs, including a "smaller/simpler" variant)
   and let the human pick or combine before drilling deeper.
5. **No question cap.** Some plans need three questions, some fifty. Redundant or trivial
   questions are a quality bug, not a quantity bug — every question must be a real decision
   with consequences. The human steers with natural language ("enough", "go on", "skip this
   branch").
6. **Stop when the frontier is empty and nothing is silently assumed.** Any assumption you made
   instead of asking goes into the playback (rule 7).
7. **Hard gate.** Do **not** start planning output or implementation until the human confirms
   shared understanding has been reached. Close the session by playing back the decisions in a
   short list (decision → chosen answer) the human can veto at a glance, then one line:
   **Assumptions I made:** each one, or *none*.

## Question format

Number the questions consecutively across rounds; each one reads:

```
**Q<n> · <title>**
<the decision and its choices: A / B / C, each with what it costs>

→ **Recommended:** <answer> — <why, in one line>

---
```

The human may answer by number ("1 yes, 2 B"). A round that fits the question UI's limits (at
most 4 questions, 2–4 options each) is asked there instead, the recommended option marked.

## When to grill vs. when to interview normally

- **Normal interview** (default in `wai-requirements-planning`): grouped, concrete
  questions across the standard dimensions, skipping what context already answers. Right for
  requirements that are mostly clear.
- **Grilling** (this protocol): the human asks for it ("grill me", "push me on this", "poke holes
  in it"), or the requirement is fuzzy and high-stakes enough that a wrong assumption is
  expensive (contract domain, token economy, new architecture). Escalate from normal interview
  to grilling when answers keep revealing new unknowns.

## Unattended runs

In a `wai-team` run nobody answers, so **no decision is self-answered**: each open one becomes a
**marked assumption** with its recommended answer and joins the run's **decision list**. If the
grill trigger fires — fuzzy and high-stakes — the issue is not built on guesses; it waits for an
attended grill.

Under merge policy (a) (the repo's own mode, confirmed at a `wai-team` kickoff — `wai-team`
§*Mandate first*), a marked assumption on a decision that would not trigger a grill does not
hold the merge — it rides the decision list for the human's veto after the fact. A decision that
would trigger a grill (fuzzy and high-stakes) holds the issue: nothing merges on it.

## Recording the outcome

Every decision that survives the grilling lands in the planning artifact (plan document,
ADR, or the issue) — not only in the chat. A decision with a real trade-off and lasting
consequences becomes an ADR; vocabulary that emerged becomes part of the docs. The grilling
itself is worthless if its results evaporate with the session.
