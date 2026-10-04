# `invocation-log.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## The prompt-written tier was measured and had gaps (#29)

This script was decided in issue #29 on 2026-08-18. The run log's two tiers were measured in the
field: the script-written tier logged 9 of 9; every prompt-written tier had gaps —
architecture-audit 0 rows with a committed report, learning-gap 0 rows with a ledger entry,
implementation 4 of 5. Self-logging that depends on the model is not a measurement. The fix is
the two artifacts the script's header names — this mechanical start log with no outcome column,
and run-log.md as the model-written subject record — never merged.

## A crafted skill name forged start-log rows

The skill name is the one field a row takes from the hook payload, and a name carrying '|' forged
extra columns — a crafted skill name minted rows with a fake timestamp and skill, corrupting the
very start count this log exists to make trustworthy. Hence the table-safe sanitisation
(run-log.sh's cell() shape) before the append.

## A plugin install gets no snippet

`--snippet` printed the hook command `sh .claude/skills/wai/scripts/invocation-log.sh`. In a
plugin install the skills live in the plugin cache, so that path does not exist in the repo: the
hook exited 127 on every Skill call, the start log stayed empty, and `retro-compliance.sh` reported
the hook as not installed (#123). An absolute path into the cache holds only until the next update,
because the cache path carries the version. An update installs the next version beside the old
one and removes the old directory 14 days later, so such a hook first runs a stale copy, then fails.

The decision (#123): in a plugin install, `--snippet` prints no hook and says plainly that the
start log needs a repo install (exit 1). It keeps the hook a per-developer opt-in and relies on no
internal path of Claude Code. The alternatives weighed:

- **A plugin `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}`.** The documented stable path into a
  plugin, but it resolves only in the plugin's own components, and a hook there runs for every
  user of the plugin. Kept opt-in only if the script checks a per-developer switch (an `env` entry
  in `.claude/settings.local.json`) and exits silently without it: every plugin user still runs
  the hook process on every Skill call.
- **Resolve the current version at hook time**, from `~/.claude/plugins/installed_plugins.json` or
  a glob over the cache. A user-level hook can do it, but it depends on Claude Code's internal
  file layout, and a glob would also match the old versions that stay on disk until they are removed.
- **Copy the script to a stable per-developer path** (say `~/.claude/wai/`) and hook that copy. It
  survives updates, but it never updates itself, so a fix to the script would not reach the hook.
