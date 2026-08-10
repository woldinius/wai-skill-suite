# Grilling Protocol — the interrogation primitive

> The shared rule for how wAI skills interview the human when a requirement, finding or
> decision needs genuine shared understanding. `wai-requirements-planning` uses it as its
> **"grill me"** mode; `wai-pr-review` and `wai-architecture-audit` may use it when an
> intent is unclear instead of guessing. This file is the single source of truth for the
> technique — skills reference it rather than restating it.

## The core

Interview the human **relentlessly** about every aspect of the plan or requirement until you
reach a **shared understanding**. Walk down each branch of the design tree, resolving
dependencies between decisions one by one.

1. **One question at a time.** Ask, wait for the answer, then continue — an early answer
   reshapes the later questions. A firehose of parallel questions loses the structure that
   makes the interview converge. (The question UI may group tightly-coupled sub-options of ONE
   decision, but never several independent decisions at once.)
2. **Attach a recommended answer to every question.** The human should mostly be confirming or
   overriding, not doing your thinking. Put the recommendation first and mark it.
3. **Facts vs. decisions.** If a *fact* can be found in the codebase, the docs, the contract or
   an issue — look it up, never ask. The *decisions* belong to the human: put each one to them
   and wait.
4. **Offer alternatives when the requirement is imprecise.** If the requirement or change is
   not sharply specified, don't just interrogate the stated path — propose **2–3 alternative
   solution options** (each with one-line trade-offs, including a "smaller/simpler" variant)
   and let the human pick or combine before drilling deeper.
5. **No question cap.** Some plans need three questions, some fifty. Redundant or trivial
   questions are a quality bug, not a quantity bug — every question must be a real decision
   with consequences. The human steers with natural language ("enough", "go on", "skip this
   branch").
6. **Hard gate.** Do **not** start planning output or implementation until the human confirms
   shared understanding has been reached. Close the session by playing back the decisions in a
   short list (decision → chosen answer) the human can veto at a glance.

## When to grill vs. when to interview normally

- **Normal interview** (default in `wai-requirements-planning`): grouped, concrete
  questions across the standard dimensions, skipping what context already answers. Right for
  requirements that are mostly clear.
- **Grilling** (this protocol): the human asks for it ("grill me", "push me on this", "poke holes
  in it"), or the requirement is high-stakes/fuzzy enough that a wrong assumption is
  expensive (contract domain, token economy, new architecture). Escalate from normal interview
  to grilling when answers keep revealing new unknowns.

## Recording the outcome

Every decision that survives the grilling lands in the planning artifact (plan document,
ADR, or the issue) — not only in the chat. A decision with a real trade-off and lasting
consequences becomes an ADR; vocabulary that emerged becomes part of the docs. The grilling
itself is worthless if its results evaporate with the session.
