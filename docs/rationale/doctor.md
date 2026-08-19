# `doctor.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The report cadence used to be enforced by mood

The honest field observation (issue #8): reports happen when someone asks. Roughly 250 verdicts
of friction produced zero reports in between — the suite's own core sentence ("the difference is
whether a mechanical check existed") applied to its own feedback channel, and failing. So
gate-stats.sh --report --mark appends a marker line when a report is cut, and doctor counts the
verdicts since. ADVISORY in both directions, never drift: WHEN to report is a threshold, but
WHAT is worth reporting stays judgment (ADR-0002) — a doctor that exits 1 over an overdue
retrospective teaches people to stop running doctor.

## A present conf is not a configured conf

The template ships CONTRACT_PATHS, MIGRATION_PATHS and ERASURE_PATHS all EMPTY — correctly, since
only the repo knows its own risky paths — and the classifier SKIPS any test whose key is empty
(`[ -n "$CONTRACT_PATHS" ] && …`). Both halves are right on their own. Together they make a third
state nobody named: a conf that EXISTS, passes every presence check in this script and in the
gate, and checks almost nothing. The presence test above says "configured"; it can only see the
file.

CONTRACT_PATHS empty is DRIFT. It is the key that decides "is this billing / auth / API-surface,
i.e. the human's alone?" — empty means NO path is contract-domain, so a billing PR classifies
CLEAN and is eligible to be agent-merged. The hardcoded GUARDRAIL floor in the classifier still
protects the suite's OWN files, which is exactly what makes this invisible: the gate keeps saying
sensible things about `.claude/**` while the repo's real contract surface is unguarded.

ERASURE_PATHS empty is an ADVISORY, and the difference is a real one, not a softening: the
classifier's EX-GDPR check greps the WHOLE diff for erasure statements whether or not the key is
set, so an ad-hoc `DELETE FROM users` is still caught by the backstop. Empty here degrades a
primary anchor to a grep; empty CONTRACT_PATHS degrades a check to nothing.

MIGRATION_PATHS is deliberately NOT judged. Empty is the common, honest answer (no database), and
the destructive-DDL escalation it gates is scoped to migration files by construction.

## The classifier’s presence became load-bearing

merge-gate.sh no longer decides "is this an excluded domain?" itself. Since the §5 refactor it
CALLS `../../wai/scripts/excluded-domains.sh` — one definition for the everyday gate,
pr-review and wai-team's drain, so three copies cannot disagree about what is human-only.
The cost of that single source is a single point of failure: the gate FAILS CLOSED when the file
is not there, so a missing classifier is UNKNOWN on EVERY PR, forever.

And an UNKNOWN gate emits no merges — which is precisely what a healthy gate looks like on a quiet
week. This is that same incident with a new missing file in it, so it gets the same verdict: DRIFT,
not an advisory.

LOOKED UP RELATIVE TO THE REPO, NEVER TO $0. doctor is routinely run from a suite CHECKOUT against
a foreign target — install.sh's last line does exactly that. Resolving the classifier next to THIS
script would find the checkout's own copy and pronounce the target healthy. The only question that
matters is what the TARGET's merge-gate.sh will find when it runs there, and it resolves the path
from its own location inside the target: .claude/skills/wai/scripts/excluded-domains.sh.

## Autonomy config: absent is a legitimate answer

coordination.conf decides what an agent may do WITHOUT a human. Its every default is the SAFE
state, and an ABSENT file means exactly what those defaults mean: autonomy off, comms none. So a
missing file is NOT drift — it is the fail-closed default working as designed, and reporting it as
a feature "silently off" would be false: off is the feature.

The drift is the other shape, and it is invisible in both directions. AUTONOMY_ENABLED is
affirmative — the human believes autonomy is armed and stops expecting to be asked — but the
allowlist that AUTHORISES it is empty, or no human ever affirmed the blast radius. Autonomy
eligibility is "every touched path is provably inside a human-affirmed safe set", never "the
blocklist did not trip", so an empty AUTONOMY_SAFE_PATHS authorises NOTHING: the drain silently
holds every PR and looks like an agent with nothing to do. coordination-lint.sh judges this
properly when it runs — but it runs at SETUP time, and this file can rot at any time after.

Read as affirmative: yes/true/on/1. The canonical value coordination-lint enforces is "yes", but a
human who wrote `true` believes autonomy is on, and doctor's whole job is the gap between what the
human believes is switched on and what actually is.
