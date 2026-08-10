# Review Lenses — the three stances a PR review can take

> Detail for `wai-pr-review` §*Review lens*. A lens is a **stance**, not a checklist: it
> decides what you go looking for *first* and what you refuse to take on trust. Read the section
> for the lens that is active — you do not need the other two.
>
> A lens is **additive**. It never replaces the base process (understand → classify → catalog
> dimensions → severity → merge gate), never narrows the dimension walk, and **never changes the
> merge gate** — the contract-domain gate, the Blocker/Major decision point, the green-checks
> condition and the absolute rule that skills never approve a PR are all lens-independent. A lens
> can only make a review *sharper*, never *laxer*.

---

## `null-hypothesis` — "assume this change does nothing"

**Stance:** the diff is guilty until it proves itself. The null hypothesis is *"this PR has no
effect on the behavior it claims to change"* — your job is to find the evidence that rejects it.
If you cannot point at the line that makes the claimed behavior happen, and at the test that
would go red without it, the hypothesis stands and that is a finding.

**Hunt for:**
- **A fix that doesn't fix.** The PR claims to fix a defect. Trace the reported failure path
  through the *patched* code: does it now take a different branch? Or does the fix sit on a path
  the bug never travelled?
- **A test that would pass without the change.** Mentally revert the source hunks and keep the
  test hunks. Which tests still pass? Those tests prove nothing — they are decoration.
- **A test that asserts the mock.** The assertion checks that the stub was called, not that the
  behavior happened. Common where a fake was introduced in the same PR.
- **Code that is never reached.** A new branch behind a flag/config/env that is never enabled;
  a guard clause upstream that returns before the new code; a handler that is registered but not
  routed; a migration written but not run.
- **The old path survives.** The new validated/idempotent/authorized path was added *next to*
  the old one, and the old one is still callable — from another endpoint, another client, a job,
  a retry.
- **The claim is broader than the diff.** The PR body says "all uploads are now idempotent";
  the diff touches one of three upload routes.

**Typical severities:** a fix that doesn't fix, or a mandatory-target path that is still reachable
unguarded, is a **Blocker/Major** — not a Nit, even though nothing is "wrong" in the code as
written. Anchor to the catalog ID of the property that was *claimed* but not delivered.

**How to say it:** state the counter-evidence, not a suspicion. "Reverting the source hunk in
`x.ts` leaves `x.spec.ts` green — the test does not cover the change" is a finding. "The tests
look thin" is not.

---

## `adversarial` — "assume someone wants to abuse this"

**Stance:** the change ships to a hostile internet. Every input is attacker-controlled until the
code proves otherwise; every trust boundary the diff crosses is an invitation. Don't audit the
codebase — audit **this diff's attack surface**. (The whole-codebase sweep is
`wai-security-audit`; this lens is that posture applied to one change.)

**Hunt for:**
- **AuthZ / IDOR.** The handler authenticates but never checks *ownership*. Can I pass another
  tenant's or user's ID and get their row? (`SEC-8` — object-level authorization & tenant
  isolation.)
- **Replay & double-spend.** A retried request, a duplicated webhook, two concurrent calls in the
  pre-check→insert window. Does anything credit/debit/grant twice? (`PAY-3`/`PAY-4`.)
- **Client-supplied truth.** A price, an entitlement, a token balance, a role, a receipt taken
  from the request body instead of verified server-side (`PAY-2`).
- **Injection.** SQL/command, and **prompt injection** where user content reaches a model that
  then drives a tool call or whose output is trusted downstream.
- **Resource exhaustion.** Unbounded page size/upload/expansion, an uncapped AI call, no rate
  limit on an expensive route — cost *is* an attack surface here.
- **Race windows.** Check-then-act without a constraint or a lock behind it.
- **Leaky failure paths.** The error message, the log line, or the 500 body carries the PII, the
  token, the stack, the internal ID.
- **Weakened gates.** The diff loosens a validation, widens a CORS/scope, adds a bypass "for
  tests", or ships a default that is unsafe when the env var is absent.

**Typical severities:** exploitable now with real impact → **Blocker**. Defense-in-depth gap that
needs a second failure to become exploitable → **Major/Minor**, and say which second failure.

**How to say it:** name the attacker, the input and the outcome. "Any authenticated caller who
guesses another tenant's `resourceId` can `GET /resources/:id` — the handler checks the session
but never the ownership edge (`SEC-8`) → cross-tenant data read" — not "authorization should be
checked".

---

## `breadth` — "assume the important part isn't in the diff"

**Stance:** the diff is the *epicenter*, not the blast radius. The failure mode this lens exists
for is a change that is locally perfect and globally broken: correct in the files it touches,
silently incompatible with the ones it doesn't. Go wide before you go deep — and read files
*outside* the diff.

**Hunt for:**
- **Other call sites.** A changed signature, return shape, nullability, thrown type or default.
  Grep for every caller; the compiler catches some of this and none of it in an untyped or
  cross-repo boundary.
- **The other surfaces.** A contract change lands in the backend — do Web, iOS and Android still
  work against it? The three clients **cannot be forced to update** (`API-1`/`CLIENT-3`): an
  additive-only change is fine, a narrowed response is not.
- **The contract artifacts.** OpenAPI/schema updated in the same PR? Contract tests? Version
  bumped? Docs in `docs/api/*`? A contract change without its artifacts is drift, not a change.
- **Data.** A new NOT NULL column without a backfill; a migration without a rollback; a rename
  that leaves the old column read by something else; retention/deletion paths that now miss a
  store (`GDPR-*`).
- **Config & environment.** A new env var with no default, missing from the compose/CI/deploy
  template — green in CI, broken on the server.
- **Operational reality.** Rollback path, health check, observability for the new failure mode,
  feature-flag off-state.
- **The omission.** What *should* have been in this diff and isn't? A test, a migration, a client
  update, a doc, an index for the new query.

**Typical severities:** a break in a client the PR never touched is a **Blocker** (it ships to
users who cannot update). Missing docs/observability are **Minor**.

**How to say it:** name the file *outside* the diff. "The web client still reads the old field
name this PR renames in the response DTO — it breaks on deploy, and it is not in this diff" is a
finding (cite the actual path you found); "this might affect other clients" is not.

---

## Combining lenses

When the human asks for more than one, run them **in sequence, each with its own stance**, and
merge the findings into one severity-ordered list — do not run a blurred average of the three.
Deduplicate: the same defect found through two lenses is one finding (cite both angles in the
*why*), not two.

## Reporting the lens

The review's `**Lens:**` line names the lens(es) and, in one clause, *why* that lens — the
classification that selected it, or "requested". A review whose lens cannot be reconstructed
afterwards is not reproducible, and a gate you cannot reproduce is not a gate.
