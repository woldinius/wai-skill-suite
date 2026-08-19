# `cross-issue-digest.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## Why a re-read and not the model's memory

A long run touches many issues in passing: it references #this from a comment on #that, it learns
that #A actually depends on #B, it discovers a real problem on an issue it is not working. The
landing rule says a genuine finding gets FILED — but the raw material for that decision is
scattered across every issue the run brushed against, and asking a model to remember, at report
time, every comment it made three hours ago on an issue outside the set is the please-remember
pattern ADR-0002 retired. So a script re-reads the backlog for edits since the run's start
timestamp, on issues outside the worked set, and hands back the candidates; the model only
curates, and nothing is filed automatically.
