# Test Patterns — reusable shapes for the mandatory targets

> Reference for `wai-testing`. The SKILL says *which* targets are mandatory; this file gives
> the *shape* of the tests that actually prove them. Stack-agnostic — translate the pseudocode to
> the repo's runner, ORM and storage.

---

## Erasure (`GDPR-*`) — "no artifact survives, anywhere"

The bug this pattern exists for is never "delete didn't run". It is: **delete ran, and missed a
store.** The rows are gone, and the user's data is still in the blob bucket, the payload archive,
the search index, the cache, the audit log, the analytics export, the backup of the queue job that
carried it. Each of those was added by a PR that never thought about deletion — and a test that
only asserts `SELECT ... = 0 rows` passes happily while the data sits in object storage.

So the assertion is not "the rows are gone". It is **"enumerate every store that can hold this
user's data, and assert each one is empty."**

### The pattern

```
test "erasing a user leaves no artifact in any store":
    user = seed_user_with_data_in_every_store()      # ← the load-bearing helper
    #   …at minimum: primary rows, child/owned rows, uploaded files,
    #   cached entries, search-index documents, archived request/response payloads,
    #   queued jobs carrying their content, exported/derived artifacts.

    erase_user(user.id)                              # the real production path, not a fixture

    for store in ALL_STORES:                         # ← the enumeration IS the test
        assert store.artifacts_for(user.id) == empty, f"{store.name} still holds user data"
```

### What makes it work (and what makes it rot)

- **Enumerate stores in one place.** A single `ALL_STORES` list (or an interface every store
  implements: `artifacts_for(user_id)`). Both the erasure implementation and the test read it.
  The point of the shared list is that adding a store forces you past it.
- **Make a new store fail loudly.** The list is the fitness function: when someone adds object
  storage, a cache or an index and does not implement `artifacts_for` / does not add it to the
  erasure path, the build should break — not the audit, eighteen months later. If the language
  allows it, make the interface non-optional (exhaustive enum/sealed type) rather than a list
  someone can forget.
- **Seed *before* deleting, and seed via the real write paths.** A user seeded straight into the
  DB never touches the blob store, so a test built that way can never catch the blob-store miss —
  it will pass forever and prove nothing. Drive the actual upload/generate/cache paths.
- **Use a real database.** Cascades, `ON DELETE` behavior and constraint order are SQL semantics;
  a mocked repository asserts your assumptions back at you (see §*Real infrastructure*).
- **Assert the file is gone from disk/bucket**, not just that a delete call was issued. "The mock
  was called" is the classic false green here.

### Adjacent assertions worth having in the same test

- **Retention**, not just deletion: data past its retention window is gone by the same path.
- **No plaintext PII in logs** produced by the erasure run itself.
- **Erasure is idempotent** — running it twice does not fail, and a replay after a partial failure
  completes rather than getting stuck.

---

## Real infrastructure vs. mocks

Mock at the **boundaries you don't own** (model providers, payment/store APIs, third-party HTTP).
Use the **real thing** for infrastructure whose *semantics* you are testing:

| You are testing | Use |
|---|---|
| SQL semantics — constraints, cascades, unique-index races, transaction isolation | a real (ephemeral) database with migrations applied |
| Model output handling, cost, latency | a deterministic fake provider |
| Purchase verification, webhooks | the store sandbox + signed fake webhooks — **never** real billing |

A mocked repository cannot fail a unique-index race, cannot cascade, and cannot violate a
constraint. Testing those against a mock tests your beliefs, not the database.

### Bound the parallelism of a heavy tier

A test tier with an **expensive per-file setup** — a real database booted per file, a container, a
WASM runtime, applied migrations — is fine at three files and starts timing out somewhere around
ten, when the runner boots all of them at once and they contend for CPU and memory.

**Check the runner's worker cap when you introduce the tier, not after the flake.** The fix is a
parallelism cap in the runner config (or a shared/pooled instance across files). It is **never** a
raised timeout: a longer timeout hides the contention until the CI box is a little busier, and
then it comes back as a flake in a PR that has nothing to do with it — eroding exactly the merge
gate these tests exist to feed.

---

## Idempotency (`RES-3`) and replay (`PAY-3`/`PAY-4`)

The property is "applying it twice equals applying it once", and the honest test does the second
apply **concurrently**, not sequentially — a sequential retry passes against a naive pre-check
(`if exists: return`) that a race walks straight through.

```
test "a replayed request applies exactly once":
    run_concurrently(2, () => submit(request, idempotency_key = "k"))
    assert effect_count(request) == 1        # one row credited / one job enqueued / one charge
    assert both_responses_succeeded()        # the loser returns the winner's result, not a 500
```

Against a real database, the pre-check→insert window is provokable, and the assertion that
actually holds the line is the **unique constraint** — so assert the effect count, not that the
code took the "already handled" branch.

## Verify through the code path the real thing uses

A test that **re-implements** the thing it is testing is a second implementation — and it can be the
one that is wrong. This is not a subtlety; it is the most common way a green test lies.

It cost four times in one week, in this suite's own repo:

- A verification harness re-implemented a glob matcher with an **unquoted** variable, so the shell
  expanded it as a pathname. The harness confidently reported a **working** fix as broken.
- `rc=$?` was read twice **after a pipe** — capturing the exit code of `tail` and of `head`, not of
  the thing under test. Both times the answer was `0`, and both times it meant nothing.
- A test of a `pre-commit` hook ran `git stash -u` first, which swept the still-untracked hook out of
  the tree. **No hook ran.** The test passed, and the commit it was supposed to block went through.
- `shellcheck` passed a `case … esac` inside `$( )`. Valid POSIX; `dash` runs it. It is a **syntax
  error in bash 3.2**, which is what `/bin/sh` *is* on macOS. **A linter is not a test.**

The rule, and it is cheap:

> **Invoke the real artifact. Capture its real exit code. Assert on its real output.**
> Not a re-derivation of what it *should* do — the thing itself, through the interface its caller uses.

And the corollary, for anything with a pass/fail verdict:

> **Test that it PASSES.** Everyone tests the block path; it is easy, and it fails safe. Almost nobody
> tests the pass path — and that is the one carrying the whole value. A gate you have never seen say
> GO is not a validated gate. It is an untested branch that happens to be failing closed.
