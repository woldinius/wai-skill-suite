# Invocation log

Every row is a wai-* skill INVOCATION, appended mechanically by a harness hook the developer
opted into (`invocation-log.sh --snippet`). This is the **denominator**: it counts starts and
judges nothing — there is deliberately **no outcome column**, and there never will be. The
model-written numerator with outcomes is `run-log.md`; the difference between the two files is
per-skill prompt-contract compliance (`retro-compliance.sh` reports it). **Never merge the two:**
a row without an outcome is not a subset of the run log, it is a forgery of one.

**APPEND-ONLY**, like the ledger and the run log. A gap here means the hook was not installed
(opt-in, per developer) — it never means "nothing ran".

| when (UTC) | skill |
|---|---|
| 2026-09-13T12:34Z | wai-pr-review |
