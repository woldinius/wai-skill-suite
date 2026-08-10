# Templates: ledger and pre-commit hook

Moved out of `SKILL.md` — both are one-time artifacts (a ledger is created once per repo, the hook
installed once per participant), while the skill body is read on every invocation. The marker
templates stay in `SKILL.md` because planting a marker is the every-phase action.

## Ledger (`~/.claude/learning/<repo-slug>/ledger.md`)

For a **new** ledger only. An existing one keeps its own shape (see *Ledger location* in
`SKILL.md`).

```markdown
# Learning progress (Leitner) — <repo-slug>

> Managed by the `wai-learning-gap` skill. **Personal and deliberately outside the repo**: it belongs
> to the human, not to the project, and no colleague sees it. Its mere existence is the consent to
> learning mode — deleting it means opting out.
> Box 1 = new/shaky … Box 5 = mastered.

## Repo identity

The slug in the path is derived and can drift (a transfer to an org, a rename, a fork, `gh` not
authenticated). These fields are what actually identify the repo — match on them before concluding
that a human never opted in.

| Field | Value |
| --- | --- |
| nameWithOwner | <owner>/<repo> |
| Remote URL | <git remote origin url> |
| Previous slugs | <filled in on a rename/transfer> |

## Stack profile

| Technology | Self-assessment | Starting box | Source (manifest) |
| --- | --- | --- | --- |

## Learning axes

Which KIND of line a gap may land on, each with its own level (`off` · `basics` · `focus`).
Orthogonal to the box. See *Learning axes* in `SKILL.md` and `references/axes.md`.

| Axis | Level | Notes |
| --- | --- | --- |
| tech-stack | basics | |
| architecture | off | |
| domain-implementation | off | |

## Topic boxes

| Topic | Axis | Box | Last practised (gap #) | Notes |
| --- | --- | --- | --- | --- |

## Gap log

`Original` is what flow B verifies the restoration against — without it, a `git restore` is
indistinguishable from a solve.

| # | Date | File:lines | Topic | Axis | Form | Difficulty | Original | Hints | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

_Status: open · solved · solved-with-hint · solved-with-solution · expired · resolved (Claude)_
_Form: cloze · structural · socratic — for a **socratic** gap the `Original` column holds the
recorded **expected answer**, not code._

## Project notes (for choosing gaps)

Optional, but the most useful section once it exists: the repo's **no-go zones** (paths where a
gap must never be planted), the **verification commands** to hand the human with each gap, and the
areas that make **good** gaps.
```

## Pre-commit hook (the fallback shape)

**Prefer `scripts/install-hook.sh`** — it writes this hook into the directory git actually runs
(`core.hooksPath`-aware), chains a pre-existing hook instead of replacing it, refuses to write into
a repo-committed hooks dir, and embeds the ledger path. The template below is what it installs, for
standalone reading and for environments where the script cannot run. The hook is **local and
personal** (`.git/hooks/` is neither cloned nor shared): colleagues without a ledger never get it.

```sh
#!/bin/sh
# Blocks commits containing an open learning gap — see .claude/skills/wai-learning-gap
LEDGER="$HOME/.claude/learning/<repo-slug>/ledger.md"

# No ledger → the human opted out. The hook makes itself inert instead of blocking
# their commits forever with no ledger left to explain why.
[ -f "$LEDGER" ] || exit 0

# Grep the staged CONTENT, not the added lines. `git diff --cached | grep '^+'` would miss
# a marker that is already in HEAD (it shows up as context, never as an addition), so a gap
# that once slipped through would ride along in every later commit, unseen forever.
# Docs are exempt: gaps live in code/config, never in markdown.
if git grep --cached -I -q -e 'LEARN #[0-9]' -- . ':!*.md' ':!*.mdx' ':!*.markdown'; then
  echo "✋ Commit blocked: an open learning gap (LEARN #) is staged." >&2
  echo "   Solve it (see $LEDGER) — or ask Claude for a hint or the solution." >&2
  exit 1
fi
exit 0
```
