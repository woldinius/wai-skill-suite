# Architecture Decision Records

A decision gets an ADR when **reversing it would be expensive** — when it constrains what can be
built later, or when someone six months from now, finding the rule, would otherwise reasonably
conclude it is arbitrary and delete it.

That last clause is the whole point. Every rule in this repo looked arbitrary until 2026-07-14,
because the reasoning lived in a conversation and the sources lived nowhere. A rule with no
recorded reason is a rule with a countdown on it.

## The form

`NNNN-a-sentence-not-a-noun.md` — the title states the **decision**, not the topic.
`0002-mechanics-in-scripts-judgment-in-prompts.md`, not `0002-scripting.md`.

Each one carries, in this order:

- **Status** — proposed / accepted / superseded by NNNN. An ADR is never deleted or edited into
  agreement with the present; it is superseded, and the old one stays readable. Same rule as the
  catalog's retired IDs, and for the same reason.
- **Context** — what was true, and what forced a choice.
- **Options** — including the one that was rejected, and *why*. **This is the part with the value.**
- **Decision.**
- **Consequences** — and specifically **what it does not fix**. A decision recorded without its
  limits gets read as a cure.
- **References** — the sources, if any. → [`REFERENCES.md`](../../REFERENCES.md)

## The records

| | Decision | Status |
|---|---|---|
| [0001](0001-the-catalog-stays-one-file.md) | The catalog stays one file — the OKF split is rejected | accepted |
| [0002](0002-mechanics-in-scripts-judgment-in-prompts.md) | Mechanics go in scripts; judgment stays in prompts | accepted |
| [0003](0003-the-baseline-owns-the-low-numbers.md) | The baseline owns the low numbers; a repo mints at ≥ 100 | accepted |
| [0004](0004-one-master-three-generated-variants.md) | One master, three generated catalog variants | accepted |
