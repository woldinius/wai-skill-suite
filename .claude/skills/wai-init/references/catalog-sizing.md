# Catalog sizing & tailoring

> Reference for `wai-init`. The SKILL says *when* to size and tailor the catalog (process
> steps 4 and 5); this file says *how much* and *what to change*. Read it before asking for scope
> and tier, and again before writing the catalog.

---

## Sizing — the catalog is the suite's token budget

The bundled baseline is the **full** tier: **87 IDs, ~510 lines**. Both numbers are mechanically
checkable (`grep -c`, `wc -l`) — which is why they are the ones stated, and why no token count is.
A token figure is a guess that nobody re-measures, so it quietly becomes a false claim on the first
edit; a line count goes stale loudly.

The catalog is read at runtime by `wai-requirements-planning`, `wai-implementation`,
`wai-testing`, `wai-pr-review`, both audits, `wai-cicd`, `wai-mobile-release` and the router — so every
line of it is paid for again and again, and it is routinely **larger than the skill reading it**.
That is what makes its size the suite's single biggest lever. Most repos need far less than the
baseline.

**The coarse cut comes first — the variant seed** (ADR-0004). Three generated seeds ship beside
the baseline master, derived from it by `scripts/catalog-variant.sh` and diffed against it in CI:
**platform** (the master verbatim — the only variant carrying `IOS-*`/`AND-*`/`PAY-*`/`AI-*`) ·
**web** (backend + web frontend — no AI integration, no token economy, no store surfaces) ·
**minimum** (`MAINT`/`SEC`/`GDPR` + `RES-3`). Start from the smallest variant whose concerns the
repo actually has; the dials below then fine-tune within it. Section numbers and IDs are never
renumbered across variants — a gap means "not in this variant", and `SEC-8` is the same dimension
everywhere.

**Then two independent dials control the size, and confusing them breaks the suite:**

- **Scope decides *which* IDs exist** within the chosen variant. This is where the remaining
  reduction comes from, and it is
  principled: a backend-only repo has no `IOS-*`/`AND-*`/`WEB-*`; with no AI provider there is no
  `AI-*`. Dropping a dimension the repo **structurally cannot have** costs nothing, because
  nothing here could ever violate it. **"Not yet" is not the same as "not applicable"** — a
  project that plans to sell tokens but hasn't wired payments keeps `PAY-*`, *softened* to a
  target (see *Tailoring rules*); dropping it would mean the day payments land, nothing guards
  them.
- **Tier decides *how much prose* each surviving ID carries.** It never removes an ID. Shortening
  an entry costs some review depth; deleting one removes a guarantee. Those are not the same
  operation and must not be traded against each other.

**The *Red Flag* is the last thing to go, not the first.** `wai-pr-review`,
`wai-implementation` and `wai-architecture-audit` all look up the per-dimension Red Flag
in the catalog at runtime — it is the operative content, the part that actually decides a finding.
So every tier keeps it; the tiers add *around* it:

| Tier | Per ID | Fits |
| --- | --- | --- |
| **Minimal** | ID + name + **Red Flag**, one line. No definition. | A prototype or spike. The Red Flag alone still makes a finding decidable — but a reviewer without the definition can't reason about borderline cases. |
| **Compact** | + a one-sentence definition | The common case for a small-to-mid app. Fully citable, everything reviews need. |
| **Standard** | + the *Good* marker (what the dimension looks like when satisfied) | A real product with users, payments or personal data. |
| **Full** | the baseline prose as-is, all surfaces | A multi-surface platform with a token economy — what the baseline was written for. |

**Whatever the tier, these survive it:** the header, the surface-scope note, *Prioritization*, and
**`## Retired IDs`**. Retired IDs are not prose to be trimmed — they are the record of which
numbers must never be reused. Drop that section at Minimal and the next re-run happily hands `SEC-12`
to a new dimension, silently rewriting the meaning of every old finding that cited it.

**Size is a consequence, not a target.** Total ≈ *IDs in scope* × *lines per tier*. Do the
arithmetic honestly before you promise a number: the mandatory core alone (`SEC` 12 + `GDPR` 6 +
`API` 3 + `MAINT` 7 + `PAY` 11 + `RES-3`) is **~40 IDs**, and a backend-only scope lands near 60 —
so a backend prototype at Minimal is roughly **60–70 lines**, not fifteen. You reach a small catalog
by **scoping honestly**, not by deleting dimensions that do apply. If the human asks for "about 15
lines" and the scope genuinely holds 60 IDs, say so: the honest options are a tighter scope or a
smaller tier — never a shorter list of guarantees.

**A core that survives every tier and every scope.** These are the dimensions the rest of the
suite *mandates* against — `wai-testing` requires tests for them, the audits always sweep
them, and reviews escalate on them. They are kept with their Red Flag intact, at any tier:
**security (`SEC-*`), GDPR/privacy (`GDPR-*`), idempotency (`RES-3` — kept on every surface, the
one exception to the `RES-*` = backend rule)**, plus **billing/token (`PAY-*`) wherever money is
actually handled** and **output validation (`AI-3`) wherever a model is called**. If the human wants one of these gone, that is a deliberate risk decision, not a
sizing choice — treat it as such and say so in the report.

**Recommend a tier, don't just offer one.** Derive it from the scan: a 3-file prototype gets
Minimal; anything touching money, personal data or auth does **not** — recommend Standard or Full
there regardless of repo size, and say why. The human overrides; you make the case.
The same tier applies to `testing-strategy.md`. Record it in the catalog header so a re-run knows.

## Tailoring rules

- **Scope to the surface first.** Always keep the cross-cutting core
  (`SEC`/`GDPR`/`API`/`MAINT`), `PAY-*` **and `RES-3`** (correctness under repetition/disorder is
  not backend-only — a client retrying a purchase is the same dimension, and `PAY-3`/`PAY-4`
  reference it); then keep only the surface's sections — backend+web
  repo → `AI`/`RES`/`OBS`/`PERF`/`WEB` **+ `CLIENT-*`** (the web app *is* a client: no provider
  key in the bundle, attestation, a contract version it can be stuck on); iOS repo → `IOS-*` +
  `CLIENT-*`; Android repo → `AND-*` + `CLIENT-*`. `CLIENT-*` is dropped only by a repo that ships
  **no** client at all. Drop the sections for surfaces this repo is not, and **say so in the
  report**.
- **Keep**, if the dimension applies (the baseline wording is well calibrated).
- **Soften/remove**, if clearly inapplicable — e.g. no payment flow yet →
  downgrade `PAY-*`/billing-idempotency (idempotency for expensive AI calls stays);
  no store client → relativize `API-2` (force-update)/attestation. **Justify in the
  report** what was removed.
- **Add** tech-stack specifics, each with a **new ID in the matching section**:
  - GraphQL instead of REST → adapt `API-4` from "OpenAPI" to "SDL/Schema + contract tests".
  - Statically typed language / TS → `MAINT-10 · Type-checking gate in CI`.
  - Terraform/Pulumi present → sharpen `MAINT-3` with concrete IaC tooling.
  - Hardcoded provider SDK calls found → note under `AI-1` as an existing Red Flag.
  - No auto-scaling/serverless → adapt `PERF-3` to the real deploy form.
  - Native iOS (Swift) → sharpen `IOS-1` with the StoreKit/Server-Notifications setup found and
    `IOS-5` with the signing tooling (Fastlane match / Xcode Cloud).
  - Native Android (Kotlin) → sharpen `AND-1` with the Play Billing/RTDN setup and `AND-4` with
    the current target-API-level requirement.
- **IDs are stable, and they carry no provenance — so the number space is split.** Never reassign
  an existing ID. And never *"append at the end of the series"*: two catalogs both appending to
  `SEC-*` will collide, because each is appending from a different state. **This is not a
  hypothetical — this very line used to read "additions append at the end (`SEC-14`, `MAINT-10`, …)",
  and a repo that followed it now holds exactly those two numbers for concepts the baseline has since
  given to other numbers.** The doctrine instructed the trap.

  **THE BASELINE OWNS THE LOW NUMBERS. A REPO THAT MINTS ITS OWN DIMENSION STARTS AT 100.**

  Two digits = shared, from the baseline. Three digits = this repo's own. `MAINT-103` can never be
  misread as `MAINT-3`, and an ID arriving in an upstream diff is identifiable **by looking at it** —
  the exact property whose absence caused every collision the suite has hit. It is also mechanically
  checkable (`catalog-lint`), which is what turns a convention into a guarantee.

  **Which of the two is a real decision, and it is yours to make:**

  - The concept is **cross-surface or cross-repo** — it could sensibly exist in the backend, the web
    app *and* the mobile clients → **propose it UPSTREAM, into the baseline.** One number, one
    meaning, everywhere. `SEC-*`, `GDPR-*`, `API-*`, `MAINT-*`, `PAY-*` and `CLIENT-*` are all
    cross-surface series. Mint locally as a stopgap if you must — **at ≥ 100** — but say so in the
    report and propose it upstream in the same breath.
  - The concept genuinely belongs to **this repo alone** → mint it at **≥ 100** and leave it there.

  **What this does NOT fix — do not let it read as though it does.** Existing sub-100 local IDs are
  *permanent*: an ID is never reassigned, so a repo that already minted `MAINT-10` keeps it, and
  keeps its translation table, forever. Declare them under a `## Local IDs` section in the catalog —
  **that declaration *is* the translation table.** The rule is forward-only.

  **And one residual risk it does not close:** two different repos can both mint `MAINT-100` for
  different things. Smaller — repo-specific dimensions rarely travel — but real at hand-off. So in
  any CROSS-REPO document, never cite a bare local ID: always the ID **and the dimension's name**.

- **Prioritization** at the end adapt to the project's real risk profile.


---

## ID provenance — the misbinding no checker can see

A dangling reference is easy: the ID resolves to nothing, and `catalog-lint` fails. A **misbinding**
resolves *perfectly* — to the wrong dimension. Nothing dangles, nothing fails, and the review reads
as if it worked.

**It is live, in a repo running this suite right now.** That repo's `SEC-8` is *CSRF & Cookie-Auth
Web Hardening*. The baseline's `SEC-8` is *Object-Level Authorization (IDOR) & Tenant Isolation*.
Its whole `SEC-8…SEC-13` block is **shifted** against the baseline:

| ID | in that repo | in the baseline |
|---|---|---|
| `SEC-8` | CSRF & Cookie-Auth Hardening | Object-Level Authorization (IDOR) |
| `SEC-9` | MFA / Strong Auth Factors | Rate Limiting & Abuse Defense |
| `SEC-10` | Object-Level Authorization (IDOR) | Session & Token Lifecycle |
| `SEC-11` | Rate Limiting & Abuse Defense | SSRF & Outbound-Request Safety |
| `SEC-13` | SSRF & Outbound-Request Safety | Abuse & Fraud Surface of the Token Economy |

A vendored skill that cites `SEC-8` for an IDOR finding — which is exactly what `review-lenses.md`
does — therefore files it, in that repo, **under CSRF**. The finding is real, the citation resolves,
and the anchor is wrong.

**Three ways this has already cost time**, all the same shape — the danger is invisible *at the
moment of action*, because it looks exactly like applying an upstream fix, which is what one is
supposed to do:

1. Applying the baseline's **retirement list** literally would have deleted two live, load-bearing
   local dimensions.
2. A defensive note written *because* of the collision (`` `MAINT-6` → `MAINT-1` ``) used the same
   arrow glyph the lint keys on — so the lint read two **live** dimensions as retired. The warning
   tripped the tool built to catch the thing it warned about.
3. An upstream fix re-pointed a `ci.yml` comment from `MAINT-6` to `MAINT-3`. **Correct upstream.**
   Ported down it would have been **wrong**, because locally `MAINT-6` *is* the lint gate.

**What is mechanical, and now enforced** (`catalog-lint`): a copied template may not cite a bare ID
at all; a locally-minted dimension must be ≥ 100 or declared.

**Two debts, and they are not the same debt.** A catalog that has drifted carries both, and only one
of them is fixable:

- **`## Local IDs`** — numbers this repo *minted*. Forward-only repair: mint at ≥ 100 from now on. A
  lint enforces it.
- **`## Reused Baseline IDs`** — baseline numbers given a *different meaning* here. **There is no
  repair.** This section IS the translation table, and it must exist for as long as the repo does. No
  lint can find these; the reference resolves.

Writing both into one section is how the translation table disappears inside a list of things that are
already handled.

**And the boundary that actually holds the line** — because a lint cannot:

> An ID arriving **from upstream** (a commit message, a skill, a template, a retirement list) is
> **baseline space** until proven otherwise. This repo's docs, CI config, ADRs and PR bodies are
> **local space**. **Never copy an ID across that boundary — translate it, or drop it.**

**What is not, and never will be:** whether two dimensions on one number *mean* the same thing. That
is semantics. A script that ruled on it would have to guess, and a check that renders a verdict it
cannot justify is how a lint gets switched off. **`wai-init` makes that call on every reconcile,
and reports it — it does not decide it.**

When they diverge, both repairs are permanent and neither is free:

- **Adopt the baseline's meaning** → every past finding, ADR and PR comment that cited the number now
  says something else. The history is silently rewritten.
- **Keep the local meaning** → the number lies to every vendored skill that cites it, forever.

That is a human's decision. Put both meanings side by side, name the cost of each, and wait.
