# Cross-Repo Handoff Protocol

> How one agent hands work to an agent in **another repo** without ever reaching into that repo.
> The platform lives in several repos — a backend+web monorepo, a native iOS repo, a native Android
> repo — joined by one versioned API contract (`contract-protocol.md`). A cross-surface feature
> therefore becomes coordinated work in repos that no single agent run owns. This file is the rule
> for that hand-off. It is **file-based and human-triggered by default**; an opt-in autonomous mode
> is described near the end as a bounded *future* option, not the default. The deterministic hygiene
> check is `sh .claude/skills/wai/scripts/handoff-lint.sh` (run from the repo root).

## The one invariant

**An agent never touches another repo's tracked files.** Not a commit, not a branch, not a staged
edit, not a `git` command run inside that repo's checkout. Across the boundary an agent may do
exactly two things, and both are confined to **gitignored** mailboxes:

- **write** a message into the counterpart repo's `temp/input/` (an outgoing request or a completed
  spec), and
- **read, then drain**, the counterpart repo's `temp/output/` (a reply the counterpart left there).

Everything else about the other repo is off-limits. The reason is the reason the git protocol
exists: the only way any branch — above all `main` — changes is through a reviewed PR opened *by an
agent that owns that repo's work*. An agent that could write another repo's tracked tree would be a
second, unreviewed path onto that repo's `main`, which is exactly what the suite is built to make
impossible. **A hand-off moves information, never commits.**

## The two mailboxes

Every repo has two, both under a **gitignored `temp/`** — they are scratch, not repo state (the same
`temp/` the suite uses for every draft and working file; `~/git` holds only repos, drafts live in
the repo's ignored `temp/`).

| Mailbox (a repo's…) | Written by | Read + drained by | Holds |
|---|---|---|---|
| `temp/input/` (inbox) | the **counterpart** agent | this repo's agent | requests addressed to this repo |
| `temp/output/` (outbox) | this repo's agent | the **counterpart** agent | replies this repo produced |

So from one agent's point of view a cross-repo exchange is a clean send/receive pair: **to send**,
write the counterpart's `temp/input/`; **to receive the reply**, read-and-drain the counterpart's
`temp/output/`. Its own inbox and outbox it reads and writes as ordinary local scratch.

`handoff-lint.sh` (deterministic, `wai/scripts/`) checks that `temp/` is gitignored and that no
file under it is tracked. A tracked mailbox file would leak scratch into review and, worse, could
carry a secret into history. If `temp/` is ever not ignored, that is a repo-hygiene bug to fix
before any hand-off — not a thing to work around.

## Why file-based

- **Auditable.** A message is a file with a timestamp and a correlation key. The whole exchange sits
  on disk — readable after the fact, diffable — not an ephemeral chat the next session cannot see.
- **Secret-free by construction.** A message is a *pointer*, never a payload (below), so nothing
  sensitive is written into a mailbox in the first place.
- **Human-triggered by default.** A hand-off happens because a human ran the sender, then ran the
  recipient — **no agent wakes another.** The default topology is therefore **one agent at a time**.

## A hand-off, end to end (human-triggered)

A backend feature needs a matching iOS change. The human drives it:

1. **Backend agent finishes the contract change** (the initiator's checklist in
   `contract-protocol.md` is done) and writes a **request** into the **iOS repo's `temp/input/`**:
   `temp/input/2026-08-02T14-30Z__req__contract-v2-token-budget.md`. Writing into a sibling repo's
   gitignored mailbox touches no tracked file — the invariant holds.
2. **The human runs the iOS agent.** That is the trigger: the human sequenced the two runs; nothing
   automated crossed the boundary. One agent at a time.
3. **iOS agent reads its `temp/input/`**, resolves the pointer (checks out the contract version,
   reads the OpenAPI spec at the path the message names), does the work on its **own** `agent/**`
   branch in its **own** repo, opens its **own** PR, writes a **reply** into its **own**
   `temp/output/` (`…__resp__contract-v2-token-budget.md` — pointer: *adopted in the client PR, back-compat
   confirmed*), and **drains** the consumed request from its `temp/input/`.
4. **Backend agent, next time the human runs it, reads-and-drains** the reply from the **iOS repo's
   `temp/output/`** — and now knows the client landed.

The correlation key (`contract-v2-token-budget`) ties request to reply across both repos, so a later
reader reconstructs the whole exchange from two files.

## The message envelope — a pointer, never a payload

**Filename** carries the routing, sortably: an ISO-8601 UTC timestamp, a kind, and a correlation key.

    <timestamp>__<kind>__<correlation-key>.md
    2026-08-02T14-30Z__req__contract-v2-token-budget.md
    kind in { req | resp | ack }

**Header fields** — a short front block:

    From:        <sender repo> · <branch or PR>
    To:          <recipient repo> · <surface>
    Correlation: <key>          # ties req and resp across repos
    Kind:        req | resp | ack
    Gated:       human          # who triggered this hand-off

**The body is a POINTER.** It says *where the authoritative thing lives and what to do with it* — a
branch name, a PR number, a path to the OpenAPI spec, a catalog ID **and its dimension name**. It
**never** inlines:

- a **secret** — no token, key, credential, connection string, or webhook URL with a secret in it.
  A message points at the **env-var name** that holds a secret, never the value (the same `SEC-3`
  rule the coordination config lives by).
- a **spec or a diff in full** — the contract lives in the contract repo; the message points there.
  Copying the spec into a mailbox creates a second, drifting copy of the source of truth.

`handoff-lint.sh --message <file>` checks the envelope: the filename matches the schema, the required
headers are present, the body reads as a pointer, and there is **no known-token-shape secret**
(private-key headers, `sk-…`, `AKIA…`, a bearer token). A generic high-entropy string is a **WARN**,
not a hard fail — a base64 correlation hash is not a secret, and a gate that fails on it cries wolf.
The lint checks **hygiene, structure and secret-absence**; it does **not** decide whether a message
should be sent, what it means, or whether excluded-domain gating applies.

Both modes share one contract, and it is fail-closed: `exit 0` = clean, the message may be sent (or
the mailbox hygiene holds) · `exit 1` = a violation, printed — a tracked `temp/` file, an
off-schema or incomplete envelope, an inlined payload, or a known-shape secret; **do not send**,
repair first · `exit 2` = it could not check at all (not a git repo, or the message file is
unreadable) — held, never waved through, because "I could not look" is not "it is fine".

## ADR-0003 at the boundary

A cross-repo message is precisely the "across the boundary" ADR-0003 warns about. An ID arriving in
a message is **not** this repo's number until proven so.

- Cite every catalog ID as **ID + the dimension's name** — `PAY-2 (server-side receipt
  verification)`, never a bare `PAY-2`. The name is what survives the crossing when the numbers do
  not.
- **Two-digit IDs are baseline space; a repo mints its own at ≥ 100.** A three-digit ID in a message
  is the *sender's* local number and means nothing in the recipient's catalog.
- **Translate it, or drop it — never copy it.** The recipient resolves an incoming concern against
  **its own** catalog by dimension *name*, not by pasting the number in. A misbinding *resolves* (the
  reference is valid) and points at the wrong dimension — the one failure no lint can catch.

## It stays human-gated

By default a hand-off is a human action, and the **excluded domains stay the human's on both sides**.
A message may *announce* a contract, auth, billing, security, destructive-migration or GDPR-erasure
change — but adopting it is still a human-gated merge in the recipient repo, and nothing about
crossing the boundary lowers that gate. The excluded-domain set is defined canonically in
`agent-git-protocol.md §"Excluded domains"`; this file keeps no copy of it.

## The opt-in autonomous-comms mode (a future option, not the default)

The file-based, human-carried default is the whole protocol today. A **later, opt-in** mode can let
the sender *wake* the recipient instead of the human sequencing the two runs — set down here so the
design is bounded before it is built, not to enable it now.

- **Tool-agnostic.** A shared channel plus a wake-signal, over whatever transport a repo configured
  (`COMMS_TOOL` in `coordination.conf` — `none` is the default and means file-based). The channel
  only **notifies**; the authoritative artifacts stay in-repo, in the mailboxes.
- **Pointer-not-payload on the channel too.** The same envelope rule holds: the wake-signal points at
  a mailbox file and a branch/PR; no secret and no spec ever goes onto the channel.
- **Excluded domains still stay human-gated.** An autonomous wake never authorizes an autonomous
  merge, and it never applies to an excluded domain — those remain the human's exactly as in every
  other mode. Autonomous comms changes *who carries the file*, never *what may merge without a human*.
- **Guardrails carry over.** `handoff-lint.sh` still gates every message; drain-on-consume still
  holds; the one-agent-at-a-time default relaxes only as far as the human explicitly opted in.

The comms question, its `none` default, and the degradation back to file-based hand-off are owned by
`wai-init` (the coordination config); this file describes the mechanic, not its configuration.

## The drain-on-consume race

Two agents must never both consume the same request. The default topology avoids the race entirely —
**one agent at a time**, a single reader draining what it consumed. If a future run ever has two
agents reading one `temp/input/`, draining must be **atomic**: claim the message (rename it to a
processing marker) *before* acting on it, so a second reader sees it is taken. Until that is built
and tested, the safe rule is the default: **one agent at a time.** A message half-processed because
two agents grabbed it is worse than a message that waits.

## Graceful fallback

- **No `temp/` yet:** create `temp/input/` and `temp/output/` and confirm `temp/` is gitignored
  (`.git/info/exclude` for a purely personal setup) before writing a message; never write a mailbox
  file into a tracked path.
- **Non-GitHub forge, or `gh` missing:** the mechanic is unchanged — files in mailboxes, pointers
  not payloads. Only the *pointer target* changes (a branch and a diff link instead of a PR number).
- **A pointer that no longer resolves** (branch deleted, PR closed): treat it as a stale message —
  the recipient reports the dangling pointer back and does **not** guess the intent. A hand-off that
  cannot be resolved is handed back, never improvised.
- **`COMMS_TOOL=none` / channel unreachable:** fall back to the file-based, human-carried default. It
  is always available and is the baseline the autonomous mode degrades to.
