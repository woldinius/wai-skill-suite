# 0003 · The baseline owns the low numbers; a repo mints its own at ≥ 100

**Status:** accepted · 2026-07-14
**References:** none external. This one came from the field — three separate firings in two live
repos. See `docs/empirics.md` §Run 5.

## Context

An ID string is the suite's **only** linking primitive: every review, plan, issue and audit cites one.
And it **carries no provenance.** `MAINT-3` looks identical whether it is the baseline's or a repo's
own, and you cannot tell by looking.

The doctrine did not merely fail to prevent the collision. **It specified it.** `catalog-sizing.md`
said, in as many words:

> *"additions append at the end of the respective ID series ("SEC-14", "MAINT-10", …)"*

Those two numbers are, today, two of one repo's three collisions. **Two catalogs both appending to the
end of the same series will collide** — each appends from a different state.

The damage is not duplicate numbering. It is worse. One repo's whole `SEC-8…SEC-13` block is **shifted**
against the baseline:

| ID | in that repo | in the baseline |
|---|---|---|
| `SEC-8` | CSRF & Cookie-Auth Hardening | **Object-Level Authorization (IDOR)** |
| `SEC-9` | MFA / Strong Auth | Rate Limiting & Abuse Defense |
| `SEC-10` | **Object-Level Authorization (IDOR)** | Session & Token Lifecycle |
| `SEC-11` | Rate Limiting & Abuse Defense | SSRF & Outbound-Request Safety |
| `SEC-13` | SSRF & Outbound-Request Safety | Abuse & Fraud Surface of the Token Economy |

`review-lenses.md` cites `SEC-8` for IDOR. In that repo, `SEC-8` is CSRF. **The finding is real, the
citation resolves, and the anchor is wrong.**

> **A dangling reference fails. A misbinding *resolves* — to the wrong dimension.**

No checker sees it: the reference is valid. And it is invisible *at the moment of action*, because
applying it looks exactly like applying an upstream fix — which is what one is supposed to do. It has
cost three times, including once when a repo's own defensive note about the collision tripped the lint
built to catch collisions.

**Vigilance is not a control here, and no lint can be one either.**

## Decision

**The baseline owns the low numbers. A repo that mints its own dimension starts at 100.**

Two digits = shared, from the baseline. Three digits = this repo's own. "MAINT-103" **cannot be
misread** as "MAINT-3". Provenance goes into the string itself, which is the property whose absence
caused every one of the firings — and it is **mechanically checkable**, which is what turns a
convention into a guarantee.

It composes with the existing rule rather than replacing it:

> A concept that is **cross-surface or cross-repo** → propose it **upstream, into the baseline**: one
> number, one meaning, everywhere.
> A concept that genuinely belongs to **this repo alone** → mint it at **≥ 100**.

**Enforced** by `catalog-lint.sh` (check 7) and by check 6: **a copied template may not cite a bare ID
at all.** Vendored skills were already safe — they resolve against the baseline — but *templates are
copied*, and on copy every number rebinds to the repo's ID space. The suite's own `ci.yml` was
carrying an ID that meant one thing upstream and another downstream.

## The rule that actually holds the line — and it is not a lint

A lint cannot see a misbinding: the reference **resolves**. So the control is not a check. It is a
**boundary**, and it is the sharpest thing anyone has said about this problem:

> An ID arriving **from upstream** — a commit message, a skill, a template, a retirement list — is
> **baseline space** until proven otherwise. This repo's own docs, CI config, ADRs and PR bodies are
> **local space**.
> **Never copy an ID across that boundary. Translate it, or drop it.**

That boundary explains all three firings at once, and each one looked like doing the right thing:

1. Applying the baseline's **retirement list** literally would have deleted two live local dimensions.
2. A note written *because* of the collision used the arrow glyph the lint keys on — and tripped the
   tool built to catch the thing it was warning about.
3. An upstream fix re-pointed a `ci.yml` comment from one number to another. **Correct upstream.**
   Copying it down would have made it **wrong**.

## Two debts, not one — and they need two sections

`## Local IDs` was written to satisfy the lint, and it therefore reads as though it were the whole
story. **It is the lesser half.**

| | **Minted** | **Reused** |
|---|---|---|
| what | a number this repo invented | a baseline number given a different meaning here |
| section | `## Local IDs` | `## Reused Baseline IDs` |
| repair | forward-only: mint at ≥ 100 from now on | **none.** A translation table, forever. |
| can a lint see it? | **yes** — enforced (check 7) | **no.** The reference resolves. |

Conflate them and the translation table — the artifact that *must* exist for as long as the repo
lives — disappears inside a list of things that are already handled.

**The cost of delay is measured, not guessed.** In one repo, realigning after **four days** meant
rewriting **30 citations across 15 files** — an hour. After four months of issues, audits and PR
history it is a migration project. **The debt does not sit still.**

## Consequences

- The suite's baseline uses at most ~14 numbers per series. **100 leaves enormous headroom** and is
  visually unambiguous.
- Repo catalogs grow a `## Local IDs` section. **That declaration *is* the translation table**, and it
  is a thing those repos need for as long as they live.

## What this does not fix — and this must not read as a cure

- **Existing collisions are permanent.** An ID is never reassigned. A repo that already minted
  "MAINT-10" keeps it, and keeps its translation table, forever. **The rule is forward-only.** It
  buys nothing back.
- **Two different repos can still both mint "MAINT-100"** for different things. Smaller — repo-specific
  dimensions rarely travel — but real at hand-off. Mitigation, and it is a convention, not a guarantee:
  **in any cross-repo document, never cite a bare local ID. Always the ID *and* the dimension's name.**
- **Whether two dimensions on one number mean the same thing stays a semantic judgment.** No script
  makes it. `wai-init` makes it on every reconcile, and *reports* it — it does not decide. See
  [ADR-0002](0002-mechanics-in-scripts-judgment-in-prompts.md).

---

*A note the tool wrote for me: this file first failed `catalog-lint`. I had written "MAINT-10",
"MAINT-103" and "MAINT-100" in backticks — and by the suite's own convention a backtick **is** a
citation into *this* repo's catalog, which holds none of them. They are another repo's number and
two format examples. The lint enforced, on the document, the exact distinction the document was
written to teach. Plain quotes, and it went green.*
