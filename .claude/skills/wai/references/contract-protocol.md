# API Contract Protocol

> The shared rule for how the platform's surfaces stay compatible. The backend and the three
> clients (Web, iOS, Android) live in different repos but share **one versioned API contract**
> as their spine. The lifecycle skills (`wai-requirements-planning`,
> `wai-implementation`, `wai-testing`, `wai-pr-review`) follow this so a
> cross-surface feature stays compatible across repos and releases. This file is the
> authoritative version; if the backend repo has `docs/architecture/contract-protocol.md`, that
> mirror is the live copy — keep them in sync.

## The one rule that matters

**The API contract is the single source of truth between backend and clients, and it is
backward-compatible.** The three clients cannot be force-updated, so the server must keep
serving the versions in the field. A change that the contract doesn't allow is not done.

## Where it lives

- The canonical contract is an **OpenAPI spec in the backend repo** (recommended:
  `docs/contract/openapi.yaml`), generated from or verified against the API implementation —
  not a hand-maintained document that drifts from the code.
- It is **versioned** and published so each client repo can pin and codegen against a known
  version.

## Versioning & backward compatibility (`API-1`/`API-2`/`API-4`/`CLIENT-3`)

- **Additive only within a version.** New optional fields/endpoints are fine; removing or
  renaming fields, tightening types, or changing semantics is **breaking**.
- **Breaking change → new version** (e.g. `/v2`), and the old version keeps being served until
  the clients in the field have migrated. Never break an existing endpoint in place.
- **Min-version / force-update** (`API-2`) is the escape hatch: the server can signal a client
  it is too old, but that is a deliberate, user-visible step — not a substitute for back-compat.
- **Remote config** (`MAINT-5`/`PAY-9`): behaviour, prices and SKUs come from the server so they
  change without an app release.

## Codegen — clients consume, don't reinvent

- Each client **generates its API client from the contract** (TS for Web, Swift for iOS, Kotlin
  for Android) rather than hand-writing request/response models that silently drift.
- The generated/pinned contract version is committed in the client repo, so a contract bump is a
  visible, reviewable change there.

## Contract tests both sides (`API-4`/`MAINT-2`)

- **Provider side (backend):** a test proves the API honours the published contract (shape,
  status codes, error format).
- **Consumer side (each client):** a test proves the client works against the contract / the
  generated client. These are mandatory for the **token/billing** surface (`PAY-*`).

## Cross-repo change flow

1. A cross-surface feature is planned once (`wai-requirements-planning`) and decomposed into
   a **contract change + per-repo tasks**; use the **same branch slug** (`agent/<handle>/<type>-<slug>`)
   in every affected repo so the PRs are correlatable.
2. The **contract change merges in the backend first** and **backward-compatible**, so a deployed
   backend serves both the new clients and the old apps still in store review / staged rollout.
3. Clients then adopt the new contract version on their own branches/PRs.
4. **Release train:** the backend deploys continuously (gated merge → release); mobile releases
   are batched behind store review, which is exactly why step 2's back-compat is non-negotiable.

## Contract-completeness checklist — the initiator's first cross-repo spec

A cross-surface feature is planned once, then cut into per-repo work. The **initiator** — the
backend, which owns the OpenAPI spec — writes the **first** version of the contract change, and
every gap it leaves becomes a round-trip: a client hits it mid-implementation, stops, and waits for
the backend to answer. Most of those round-trips are avoidable, and this checklist is how the
initiator removes them **before** hand-off. Run it against the spec change while it is still on the
drawing board. The deterministic structural floor is
`sh .claude/skills/wai-pr-review/scripts/contract-completeness.sh` (schema present on every
response, one error schema referenced, a security scheme defined and referenced, a version present).
Obey its exit code: `exit 0` = the floor is met — name-heuristic **WARN** advisories may still
print, and they never move the exit · `exit 1` = a floor check failed and the hole is named — close
it before the hand-off, because every hole becomes a client's round-trip · `exit 2` = **UNKNOWN**:
not an OpenAPI document this line reader can read (a minified JSON, say) — it verified *nothing*, so
treat the floor as unmet, never as met. The judgment calls below are yours.

- **Concrete encodings, never "a string".** Every field states its type *and* its shape — a
  timestamp declares `format: date-time`, money declares its unit and precision (minor units as an
  integer, not a float), an identifier declares its format. "The client will figure out the
  encoding" *is* the round-trip.
- **Closed sets are enums, not free strings.** A status, a kind, a role, a currency — anything with
  a known, finite set of values — is an `enum` in the schema, so the three generated clients get a
  type they can switch on exhaustively. A bare `string` where an enum was meant is a silent breaking
  change waiting to happen: a new value nobody's client handles.
- **Security bindings are explicit, and replay-protected.** State which security scheme each mutating
  operation requires (not "auth is handled elsewhere"), and for anything that moves money or state,
  how a **replayed** request is rejected — an idempotency key, a nonce, a short-lived token. The
  scheme is *defined once* and *referenced by every operation that needs it*; a referenced-but-
  undefined scheme is a hole.
- **One canonical error envelope, plus a status table.** All errors share a single documented shape
  (a machine-readable `code`, a human `message`, optional `details`), and the contract lists **which
  status codes each operation returns and what each means** — including the 4xx/5xx the clients must
  render. Three clients inventing three error UIs against an undocumented error body is the most
  expensive round-trip of all.
- **Idempotency for every retriable mutation.** A create/charge/debit a flaky network can deliver
  twice declares its idempotency key, and the contract states that a repeat is a no-op returning the
  first result — the rule the token ledger already lives by (`PAY-*`).
- **Additive-only within a version, and say so.** New optional fields/endpoints only; removing,
  renaming, tightening a type or changing semantics is **breaking → new version** (per *Versioning &
  backward compatibility* above). The three clients cannot be force-updated.
- **A written back-compat statement travels with the change.** One explicit sentence: *no breaking
  change*, or *v2 added, v1 served until the field has migrated*. Absence of the statement is **not**
  "no break" — it is an unanswered question the client repo inherits.
- **Catalog IDs cited as ID + dimension name (ADR-0003).** A cross-cutting concern the contract
  carries (`API-…`, `PAY-…`, a security dimension) is named as **ID + the dimension's name**, and a
  two-digit **baseline** ID is never copied onto a repo-**local** concern (a repo mints its own at
  ≥ 100). The contract is the most-copied artifact in the suite; a bare number that means one thing
  upstream and another in a client repo is exactly the misbinding ADR-0003 exists to stop.

The hand-off mechanics themselves — how the completed spec crosses the repo boundary without leaking
a secret — are `references/cross-repo-handoff.md`.

## The one round-trip the checklist cannot remove

The checklist kills *avoidable* round-trips. It does not promise zero. One class is **irreducible**:
a **security binding whose correctness depends on the counterpart's domain** — the client's token
storage and attestation on one side, the backend's verification and revocation on the other — cannot
be settled by the initiator alone, because neither side owns both halves. That is a genuine
**cross-domain review**, not a spec gap, and it happens once, deliberately, with both sides (and the
human) present.

So the contract flow has two different waits, and only one is waste:

- an *avoidable* round-trip is a field the initiator could have specified and didn't — the checklist
  removes it;
- the *irreducible* round-trip is the security binding — you schedule it, you don't try to delete it.

This composes with the gate below: a contract change is human-gated for merge **and** the
security-binding review is human-run. The skill never signs off a cross-domain security binding on
its own.

## Contract domain = human-gated

Changes to the contract for **API, Auth/Login, Token/Billing** are a **contract domain**: their
PRs are left for the human to merge (no auto-merge), per the suite's merge gate
(`references/agent-git-protocol.md`). A token/billing contract change touches three provider
integrations plus the ledger — treat it with payment-grade care.

The contract domain is a **subset of the excluded domains** — the set that stays the human's even
under an autonomy mandate — defined canonically in `references/agent-git-protocol.md §"Excluded
domains"`. This file does **not** restate that set: a contract change is therefore always human-gated
for merge **and** always excluded from any autonomous drain. Cite the canonical section; never keep
a second copy of the list here that could drift from it.

## Graceful fallback

- **No contract yet:** don't block — note it and propose creating the OpenAPI spec + codegen as
  a follow-up (a `wai-requirements-planning`/`wai-implementation` task in the backend
  repo). Degrade to "make the contract explicit," never to "let clients drift."
- **Contract and code disagree:** that is drift (`MAINT-8`) — fix the code or deliberately
  version the contract; never silently bend one to the other.
