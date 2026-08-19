# `contract-lint.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Fifteen findings, one absent operation

ADR-0002 moved the mechanics into scripts and left the judgment in the prompts. That split created
a JOINT, and a joint is a thing that drifts: at the time this check was written ~23 scripts and
~30 prompt files described each other (28 and 33 as of 2026-08-19), and NOTHING had ever checked
that the two sides still said the same thing. A script gets a third
exit code, a prompt keeps documenting two. A skill is renamed, a documented path stops resolving.
A script is superseded and nobody deletes it, because nothing reports that nobody calls it.

The 2026-08-03 architecture audit found FIFTEEN findings of exactly this shape — not one of
them a hard bug, every one of them a place where the model is told something that is no longer
true. That is the worst failure mode this suite has: the prompt is the instruction, so a stale
prompt does not crash, it QUIETLY INSTRUCTS THE WRONG THING, and the good run and the bad run
produce identical output. Fifteen findings, one absent operation. This is the operation.

## Every script path a prompt names must resolve

A prompt is an INSTRUCTION. `sh scripts/foo.sh` that does not exist from where the prompt is read
does not fail loudly — the model improvises, or silently drops the step, and the run looks normal.

TWO BASES ARE ACCEPTED, because two are legitimately used: the REPO ROOT (where an agent's shell
actually sits) and the referencing SKILL's own directory (`scripts/foo.sh` inside that skill's
SKILL.md). Anything else is reported — and the finding NAMES the base it does resolve from, so the
repair is a prefix, not an investigation.

THE FALSE-POSITIVE THIS AVOIDS, and it is the whole reason for the basename test below: the suite
tells a target repo to create files (`deploy.sh`, a project's own `scripts/…`). Those paths are
SUPPOSED not to resolve here. So a path whose basename is not one of this suite's own scripts can
only ever be a WARNING — it may be a broken link, it may be an instruction about somebody else's
repo, and this script structurally cannot tell which. It does not change the exit code.

## Every exit code is documented where the script is invoked

This is the one that fails open. A prompt that documents 0 and 1 for a script that also returns 2
does not tell the model "you may see a 2" — so on a 2 the model decides for itself, and the odds
are it decides the run was fine. That is precisely how a fail-CLOSED gate becomes fail-OPEN, and
it produces no error, no log line, and no difference in output.

COLLECTING THE CODES IS THE PRECISE HALF, and it has to be: a naive `grep 'exit [0-9]'` reads
`# pytest's exit 5 is "no tests were collected"` out of post-merge-verify.sh's COMMENTS and its
message STRINGS, and reports a convention violation that does not exist. So full-line comments and
quoted strings are removed before literal `exit N` statements are read, and the only comment form
trusted is the suite's own contract header (`#   exit 2  UNKNOWN — …`), which is the script side
of this very contract. Codes hidden behind `exit "$VERDICT"` are invisible to both — a script that
declares neither is counted and reported, never silently passed.

## How a code counts as documented

Is a code documented in any prompt that names the script?  (basename, code, file list)

SCOPE IS THE MARKDOWN BLOCK — heading, numbered step, or top-level bullet — and every part of that
was chosen against real output. WHOLE-FILE scope is worthless: `wai-learning-gap/SKILL.md` documents
`ledger-locate.sh`'s three codes, and at file scope that silently vouches for `ledger-lint.sh`,
`rank-pr-candidates.sh` and `verify-gap-breaks.sh` too — four scripts, one contract, three of them
unchecked and green. SECTION scope is barely better: one `## Process` runs 250 lines and lets an
UNKNOWN written about the merge gate stand as documentation for a script mentioned 40 lines away.
A FIXED WINDOW (±n lines) breaks the other way and cries wolf — `merge-gate.sh` is invoked
nineteen lines above its own `exit 0/1/2` list, and that is correct documentation.

The step/bullet block is the unit a human actually reads as "this paragraph is about this script".
Measured on this repo, tightening from section to block turned 11 findings into 23 — and all 12 of
the new ones were verified by hand as real. Where a block still names several scripts the
attribution is by proximity, not by parsing: that is counted and said out loud, never silently
counted as coverage.
