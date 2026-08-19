# `open-gap-check.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Two sides, because the ledger has no lock

The skill's own prose says why the ledger alone is not enough: the ledger is a single unlocked
file shared across every clone and worktree of a repo. Two concurrent sessions both read "no open
row" and both plant — so the working TREE (`git grep` for the gap marker) is the side that
actually catches a second gap, and the ledger is the side that catches a marker a human deleted
without solving. You need both.

## The exit code is not a bitmask

A tempting design folds "which side is open" into the exit code (2 = ledger-side open). That is
exactly the bug the merge gate exists to warn about: it steals the UNKNOWN code — the suite's
universal "could not verify, fail closed" — and makes the check misreport which of its own states
it is in. So the SIDE goes in stdout, where it is data, and 2 keeps its one meaning: something
could not be read.

## The detector used to contain its own marker

This script used to grep for the literal marker string, which meant the literal was IN this file —
so it matched itself, and it matched every other file that handles the marker as data (the hook
installer, the test fixtures). Since `.claude/skills/**` is committed in every repo install.sh has
touched, the result was that learning mode could NEVER plant a gap in a repo that vendors the
suite: exit 1, "resolve the open gap first", and nothing to resolve. Assembling the pattern at run
time is the fix that needs no path exclusions — and a blanket `:!.claude/skills/*` exclusion would
have been wrong anyway, because this repo is itself a project someone may legitimately be
learning on.

## The sweep used to stop at its own worktree

The ledger hangs off the repo and is shared across all worktrees; a working tree is not. This
script used to grep only the tree it ran in, so the two sides it compares had different reach —
and in the field (issue #13) that cost two days: a gap planted from a linked worktree was
invisible in the main checkout, the check reported only the ledger row, and flow B's "no marker +
no claim = expired" booked an exercise the human had never seen. "No marker HERE" and "no marker
ANYWHERE" are different facts — which is why a marker found in ANOTHER tree is reported as
misplaced (exit 1, its own line), never as expired, and an unreadable listed tree makes the
verdict UNKNOWN rather than being silently counted as clear.

## A green that named a side it never read

The no-argument default used to guess the `temp/` fallback path instead of asking ledger-locate.sh.
For a normal participant (whose ledger is under ~/.claude/learning/) the ledger side was therefore
skipped entirely while the output still announced "tree and ledger both clear". A green that names
a side it never read is the exact thing ADR-0002 forbids — and it is why the final verdict now
says exactly which sides were read: "both clear" when one side was never located is the claim this
script was caught making.
