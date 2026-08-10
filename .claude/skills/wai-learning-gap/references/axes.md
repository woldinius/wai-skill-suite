# Learning axes — the detail behind the three KINDS of gap

A **box** decides *how hard* a gap is (the Leitner schedule); an **axis** decides *which kind* of
line it lands on. They are orthogonal — a topic has both, and one never constrains the other. The
`SKILL.md` section *Learning axes* is the summary; this file is the working detail: the fail-visibly
contract per axis, the architecture-gap forms with their own difficulty ladder, and the combine-tier
ingredient guidance.

Each axis is carried in the ledger's `## Learning axes` table with its own level:

- `off` — that axis plants nothing.
- `basics` — eligible, ordinary weight.
- `focus` — eligible, weighted above `basics` in topic selection.

The axis a candidate line belongs to is **model judgment**. `ledger-lint.sh` checks only that the
recorded label is a valid enum member (`tech-stack` · `architecture` · `domain-implementation`) and
that every enabled axis has a level — never that the label is the *right* one for the line. Obey its
exit code: `exit 0` = consistent, **or** a divergent human-authored ledger it correctly declined to
lint · `exit 1` = a check failed, with the offending row and the repair printed — fix the ledger
before planting against it · `exit 2` = the ledger could not be read at all (**UNKNOWN**) — nothing
was verified, so find the file first. It reports and never rewrites: the ledger is the human's.

## 1. Per-axis fail-visibly contract

Every gap must fail **visibly** — a silent success teaches nothing and rots undetected. What
"visible" means differs by axis:

| Axis | The gap lands on… | Fails visibly as… | Confirmed by |
| --- | --- | --- | --- |
| tech-stack | a language/framework idiom, syntax, a library API, build/config semantics | a **compile or type error** (or a build failure) | `verify-gap-breaks.sh --form cloze` → red |
| domain-implementation | a business rule the code encodes | a **red test on a line the suite already covers** | `verify-gap-breaks.sh --form cloze` (or `--form structural`) → red |
| architecture | a structural pattern (layering, dependency direction, module boundary, protocol/interface conformance, DI registration) | **preferably a build-breaking structural line**; only if none exists, a **Socratic gap that stays green** | structural → `verify-gap-breaks.sh --form structural` → red; **Socratic → NOT probed** (green by design) |

`verify-gap-breaks.sh`'s verdict is not advisory: `exit 0` = the gap breaks visibly as intended — or
the form is `socratic`, where the probe is N/A and skips · `exit 1` = the tree is **still green**: the removed
line failed silently, so replant it somewhere it bites rather than handing the human a gap they will
never notice · `exit 2` = the test command could not be run at all (**UNKNOWN**) — fail closed, an
unrun probe is never a pass.

Two consequences worth stating plainly:

- **Domain gaps need coverage.** If no existing test exercises the line, removing it fails *silently*
  and the gap is worthless. When you cannot find a covered line for a due domain topic, do not invent
  a test to justify the gap — choose a different line, or a different axis.
- **Architecture is the only axis with a non-removal fallback.** tech-stack and domain gaps always
  remove code and always go red. Architecture prefers the same, and only drops to the Socratic form
  when the structure offers no line whose removal breaks the build.

## 2. Architecture-gap forms

### 2a. Structural-first (preferred — stays a red gap)

Whenever the change touched a structural line whose removal breaks the build, use it. It behaves like
any other code-removal gap and rides the normal three-rung ladder (restore / combine / reconstruct).
Generic examples of such lines:

- a **protocol / interface conformance** declaration whose removal makes a consumer fail to compile;
- a **dependency-injection registration** whose removal makes resolution fail at build or first use;
- a **layer-boundary call** (e.g. a use-case invoked from a controller) whose removal breaks a
  covered path;
- a **module export / public surface** line a covered importer depends on.

Confirm it goes red with `verify-gap-breaks.sh --form structural`. Record `Form: structural` and the
original line in the gap log, exactly as for a tech-stack gap.

### 2b. Socratic fallback (only when no structural line breaks the build)

Some architecture lessons have **no** single line whose removal fails visibly — the shape is spread
across files, or the "wrong" alternative still compiles and still passes tests. Forcing a red gap
here would mean deleting something unrelated, which teaches the wrong thing. In that case, plant a
**Socratic gap**: a marker that poses a question about the structure and leaves the tree **green**.

The Socratic gap has **its own difficulty ladder, scaled by box** — it does **not** use the
combine/reconstruct rungs, and the ingredient machinery and `shuffle-ingredients.sh` never apply to
it:

| Box | Rung | The question asks the human to… |
| --- | --- | --- |
| 1–2 | **locate** | point to where the pattern lives (which file/type enforces the boundary?) |
| 3 | **trace** | follow the dependency/flow through the layers (what calls what, in which direction?) |
| 4+ | **why** | justify the structure (why this boundary? what breaks if it is crossed?) |

Every Socratic gap **records an expected answer** in the gap log — in the `Original` column, which
for a `socratic` form holds the answer text, not code. Flow B assesses the human's written
explanation against that recorded answer. A solve is always an explicit claim **plus** that answer,
never inferred from the (green) tree; marker gone with no answer → `expired`, box unchanged.
`ledger-lint.sh` enforces that a `socratic` row records an expected answer at all.

### The Socratic pre-commit blind spot (restated)

Because a Socratic gap keeps the tree green from planting to close, the personal pre-commit hook and
CI provide **no backstop**: deleting the marker without answering removes the gap silently, and
`verify-gap-breaks.sh` must **not** be run against it (it would wrongly reject a gap that is green by
design — pass `--form socratic` and it skips rather than failing). The *only* thing that closes a
Socratic gap is Flow B's comparison against the recorded expected answer. This is the one gap form
with no mechanical safety net, so it is opt-in per axis: use it only when the architecture axis is
enabled at a wanting level and no structural line breaks the build.

## 3. Combine-tier ingredient guidance (box 3, all code-removal axes)

At box 3 the line(s) are removed and the marker lists the **ingredients** needed to rebuild them as
an **unordered** set — the assembly *is* the exercise. Bucket the ingredients into three groups:

- **calls/keywords** — function/method names, language keywords, control-flow words;
- **variables** — the identifiers the line reads or writes;
- **operators/math** — operators, assignment, comparison, arithmetic.

Two rules keep the tier honest:

- **Keep the set complete.** Every token needed to reconstruct the line appears in exactly one
  bucket. A missing ingredient turns "combine" into "guess", which is not the exercise.
- **Omit usage order and nesting.** The buckets carry *what*, never *in what arrangement*. Order and
  nesting are precisely what the human must supply, so they must not leak from the presentation.

Order-neutralisation is mechanical: `shuffle-ingredients.sh` sorts deterministically **within each
bucket** so presentation order never signals usage order. `exit 0` = the neutralised buckets are on
stdout · `exit 1` = malformed input (an ingredient before any bucket header, or no ingredients at
all) — nothing was neutralised, so fix the buckets and re-run; never paste the raw, usage-ordered
list into the marker, it hands over the answer. The **bucketing itself stays judgment** — a
lexer across the open range of languages is brittle and out of scope; the model assigns each token to
a bucket. Record `Form: cloze` and the original line in the gap log.

## ADR-0003 at the axis boundary

When a gap teaches a cross-cutting concern that the repo's quality catalog names, refer to that
dimension **by its name**, never by a bare catalog ID — a bare number is meaningless outside the
catalog that minted it, and this file (like the ledger) is personal and travels with the human, not
the repo.
