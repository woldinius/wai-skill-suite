# `tests/run.sh` (wai-learning-gap) — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The suite paid twice for shell gates before these rules existed

These scripts are the ADR-0002 mechanics of a skill that had none, and the harness's two governing
rules were not designed in the abstract: the suite had already paid, twice, for the two ways a
shell gate ships broken. Once for a `case … esac` inside `$( )` — a syntax error in bash 3.2,
which is what /bin/sh is on macOS, and which shellcheck passes — hence every case runs under both
dash and bash 3.2. And once for a gate that had only ever been seen failing, which is not a
validated gate — hence every script is exercised on its GO path (exit 0) as deliberately as on
its NO path.

## The marker that sat invisible in a linked worktree

The worktree sweep exists because of a field incident (issue #13): the ledger is shared across
every worktree but the trees are not, so a check that grepped only its own tree compared two
sides with different reach — and a marker planted from a linked worktree sat invisible for two
days while flow B booked it "expired". The test cases pin both halves of the fix: a marker in
another worktree is reported as misplaced (not expired), and a clean multi-worktree repo is still
a clear.
