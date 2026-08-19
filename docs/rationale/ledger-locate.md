# `ledger-locate.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## A derived slug drifts, and the gate goes silent

The consent gate is load-bearing, and it has one invisible failure mode the skill's own prose
warns about: a slug is DERIVED (from the remote, or the folder), and derived things drift — the
repo is transferred to an org, renamed, forked; the folder is moved. A naive path check then finds
no ledger at the new slug and concludes "this human never opted in" — going silent, orphaning
their Leitner state, and by the very design of the gate NOBODY is told. That failure mode is why
the gate is a lookup and not a path check: what a ledger RECORDS about its repo (the remote URL,
the owner/repo) does not drift when the path does.
