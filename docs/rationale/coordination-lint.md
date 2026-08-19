# `coordination-lint.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Wrong in the unsafe direction looks identical to working

A config that is wrong in the SAFE direction (autonomy off) costs nothing. A config that is wrong
in the UNSAFE direction — a narrowed exclusion floor, an allowlist that authorises too much, a
webhook secret committed in the clear — costs everything, silently, and looks identical to a
working one. So the config gets the same treatment as the merge gate: a script owns the mechanical
checks, because "the model read the config and it looked fine" is not something anyone can audit.
