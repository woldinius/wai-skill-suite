#!/usr/bin/env sh
# Inject the wAI skill suite into a project's .claude/skills/.
# Idempotent: safe to re-run to update.
#
# It only ever touches the suite's own skills: it installs/updates them and prunes
# suite skills that were renamed or removed upstream (tracked via a manifest) — it
# never removes your own skills. It does NOT create docs/architecture/ — the catalog
# and testing strategy are wai-init's job, because they must be scanned, scoped
# and sized to *your* repo (see step 7). The rest of your project is left untouched.
#
# Usage (run in your project root) — from a checkout you have read:
#   sh install.sh [target-project-dir]
# or, pinned to a release (tests/numbers-lint.sh checks this tag exists):
#   curl -fsSL https://raw.githubusercontent.com/woldinius/wai-skill-suite/v0.3.1/install.sh | SKILLS_REF=v0.3.1 sh
# or, unpinned (latest main):
#   curl -fsSL https://raw.githubusercontent.com/woldinius/wai-skill-suite/main/install.sh | sh
#
# The pinned form matters: the script and the tree it installs must be the same version. Fetching
# the script from a tag while it clones `main` would install code you did not read.
#
# Env overrides:
#   SKILLS_REPO=<git url>   (default: this repo)
#   SKILLS_REF=<branch/tag> (default: main)
set -eu

REPO="${SKILLS_REPO:-https://github.com/woldinius/wai-skill-suite.git}"
REF="${SKILLS_REF:-main}"
DEST="${1:-$PWD}"

# An empty destination would make every path below root-relative, and this script runs `rm -rf`.
[ -n "$DEST" ] || { echo "error: destination must not be empty" >&2; exit 1; }

SKILLS_DIR="$DEST/.claude/skills"
MANIFEST="$DEST/.claude/.wai-suite-manifest"

# 1. Where do the skills come from?
#
# If this script RUNS AS A FILE inside a checkout of the suite, install FROM THAT CHECKOUT. That
# is what makes the "clone it first, read it, then run it" path in the README honest: otherwise
# the careful user reviews a tree and then installs whatever is on the remote's default branch —
# which is not the tree they read. An explicit SKILLS_REPO always wins.
#
# "Runs as a file" is load-bearing, and it was the first-review blocker. Under `curl … | sh`,
# `$0` is the shell itself, so `dirname "$0"` is "." and HERE becomes the TARGET project — and a
# target that already has the suite installed has a `.claude/skills` too. The old check then took
# the destination for the source, and step 5's replace (rm -rf, then cp) deleted each skill and
# copied it from the directory it had just deleted. Every documented update run hit this. So:
# piped input never counts as a checkout, and a checkout must contain this script by name.
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

RUNS_AS_FILE=no
case "$(basename -- "$0")" in install.sh) [ -f "$HERE/install.sh" ] && RUNS_AS_FILE=yes ;; esac

if [ -z "${SKILLS_REPO:-}" ] && [ "$RUNS_AS_FILE" = yes ] && [ -d "$HERE/.claude/skills" ]; then
  SRC="$HERE/.claude/skills"
  SRC_SHA="$(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "source: this checkout ($HERE)"
else
  command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  git clone --depth 1 --branch "$REF" --quiet "$REPO" "$TMP"
  SRC="$TMP/.claude/skills"
  SRC_SHA="$(git -C "$TMP" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "source: $REPO@$REF"
fi

[ -d "$SRC" ] || { echo "error: no .claude/skills in $REPO@$REF" >&2; exit 1; }

# The rip cord, independent of how we got here: if source and destination are the same directory,
# step 5's replace would delete the source it is about to copy from. No mode is allowed to reach
# that state — refuse loudly instead of destroying anything. (This also catches running
# `sh install.sh` inside the suite repo with the repo itself as destination.)
SRC_CANON="$(CDPATH='' cd -- "$SRC" && pwd -P)"
DEST_CANON="$(CDPATH='' cd -- "$DEST" 2>/dev/null && pwd -P || true)"
if [ -n "$DEST_CANON" ] && [ "$SRC_CANON" = "$DEST_CANON/.claude/skills" ]; then
  echo "error: source and destination are the same directory ($SRC_CANON)." >&2
  echo "       Refusing — the update would delete each skill and then copy it from the" >&2
  echo "       directory it just deleted. If you meant to install into another project," >&2
  echo "       pass it as an argument: sh install.sh /path/to/project" >&2
  exit 1
fi

# 2. The current suite = every skill dir in the master repo.
NEW_SET="$(cd "$SRC" && ls -1)"
mkdir -p "$SKILLS_DIR" "$DEST/.claude"

# 2b. Migration: the suite lived in the `platform` namespace before it became `wai`.
#
# Without this, a repo that already has the old suite gets the new one installed BESIDE it —
# eleven pairs of skills with near-identical descriptions, which is the documented way to make
# skill routing pick the wrong one, in the repos most likely to update first.
#
# The rule from step 3 is unchanged: ONLY A MANIFEST CONFERS OWNERSHIP. We prune what the OLD
# manifest lists, nothing else — plus a namespace check, so a hand-edited manifest still cannot
# talk this script into deleting someone else's skill.
LEGACY_MANIFEST="$DEST/.claude/.platform-suite-manifest"
LEGACY_VERSION="$DEST/.claude/.platform-suite-version"
if [ ! -f "$MANIFEST" ] && [ -f "$LEGACY_MANIFEST" ]; then
  echo "migrating: the suite moved from the 'platform' namespace to 'wai'."
  while IFS= read -r old || [ -n "$old" ]; do
    [ -n "$old" ] || continue
    case "$old" in
      platform|platform-*|learning-gap) ;;
      *) echo "  kept (not a name this suite ever installed): $old"; continue ;;
    esac
    if [ -d "$SKILLS_DIR/$old" ]; then
      rm -rf "${SKILLS_DIR:?}/$old"
      echo "  pruned (renamed into the wai namespace): $old"
    fi
  done < "$LEGACY_MANIFEST"
  rm -f "$LEGACY_MANIFEST" "$LEGACY_VERSION"
fi

# 3. Which suite skills do we already own in the target? (for pruning renames/removals)
#
# ONLY the manifest confers ownership. Without one we own nothing, so we prune nothing:
# a directory is not ours just because its name starts with `wai-`. Guessing ownership
# from the name would delete a `wai-onboarding` that someone else wrote — the one
# mistake this script must never make, because it is not undoable.
if [ -f "$MANIFEST" ]; then
  OWNED="$(cat "$MANIFEST")"
else
  OWNED=""
  # First run: warn about name collisions instead of deleting. These dirs are about to be
  # OVERWRITTEN by the suite skill of the same name, which is the standard install behaviour —
  # but if one of them is yours, stop now and rename it.
  for s in $NEW_SET; do
    if [ -d "$SKILLS_DIR/$s" ]; then
      echo "warning: $SKILLS_DIR/$s already exists and will be overwritten by the suite's skill." >&2
      echo "         If that skill is yours, press Ctrl-C and rename it first." >&2
    fi
  done
fi

# THE LEDGER GUARANTEE — stated here because this is where the deletions live (steps 4 and 5).
#
# Everything under $DEST/docs is USER DATA, above all docs/architecture/gate-ledger.md and
# docs/architecture/run-log.md: append-only experience that cannot be reconstructed. A field repo
# lost its entire pre-2026-07-22 ledger to a suite update (issue #10) — weeks of verdicts, gone,
# and the report window shrank with them. So the rule, permanent: every `rm -rf` in this script
# stays inside "$SKILLS_DIR", and this script NEVER writes to or removes anything under
# "$DEST/docs" — a suite update is a migration path for the ledger, not a file operation on it.
# tests/run.sh holds this as a test: an update into a repo with a populated ledger and run log
# must leave both byte-identical. Whoever teaches this script to "clean up" docs/ goes red there.

# 3b. THE NO-OP ANSWER (field-reported, 2026-08-17): "does this update change anything for me?"
# A field repo computed this by hand — hashed its installed tree against the suite's — and got it
# subtly wrong: the hash covered ALL of .claude/skills, including the repo's own skills the
# installer never touches, so the number compared against nothing upstream. The honest comparison
# is exactly the set this script owns: the manifest's skills, content vs the source. When they are
# byte-identical the install still proceeds (the stamp advances — doctor's staleness checks want
# the newest commit), but the run SAYS the truth: zero behavioral change. A version stamp that
# advances silently over zero delta reads as "something happened", and the next audit inherits
# that misread.
if [ -n "$OWNED" ]; then
  NOOP=yes
  for s in $NEW_SET; do
    if ! printf '%s
' "$OWNED" | grep -qx "$s"; then NOOP=no; break; fi     # a new skill = change
    if [ ! -d "$SKILLS_DIR/$s" ] || ! diff -rq "$SRC/$s" "$SKILLS_DIR/$s" >/dev/null 2>&1; then
      NOOP=no; break
    fi
  done
  # a skill we own that upstream dropped is also a change (it is about to be pruned)
  if [ "$NOOP" = yes ]; then
    for old in $OWNED; do
      printf '%s
' "$NEW_SET" | grep -qx "$old" || { NOOP=no; break; }
    done
  fi
  if [ "$NOOP" = yes ]; then
    echo "no behavioral change: the installed suite skills are byte-identical to this source — only the version stamp advances."
  fi
fi

# 4. Prune skills WE installed that no longer exist upstream (renamed or removed).
for old in $OWNED; do
  if ! printf '%s\n' "$NEW_SET" | grep -qx "$old"; then
    rm -rf "${SKILLS_DIR:?}/$old"
    echo "pruned (renamed/removed upstream): $old"
  fi
done

# 5. Install/update each current suite skill (full replace also drops files removed within a skill).
for s in $NEW_SET; do
  rm -rf "${SKILLS_DIR:?}/$s"
  cp -R "$SRC/$s" "$SKILLS_DIR/$s"
  echo "installed: $s"
done

# 6. Record what we own now — this is what the next run prunes against.
printf '%s\n' "$NEW_SET" > "$MANIFEST"

# 6b. Stamp the suite version (the commit just installed). doctor.sh reads this at update time;
#     A later phase will compare a generated artifact's own stamp against it to detect a stale
#     artifact (one written from an older template). Kept in a SEPARATE file, not the manifest,
#     which is word-split as a skill-name list.
printf '%s  (ref %s)\n' "$SRC_SHA" "$REF" > "$DEST/.claude/.wai-suite-version"

# 7. Deliberately NO seeding of docs/architecture/.
#    The catalog and testing strategy are wai-init's job: it scans the repo, scopes the
#    catalog to the surface it actually is, sizes it (tier), and asks for the language and the
#    repo mode. Copying this repo's LIVE catalog here would drop an 87-ID multi-surface document
#    with a pre-answered header into a foreign project — and wai-init, seeing a catalog that
#    already exists, would keep it and never ask any of those questions. The suite would silently
#    run on someone else's tailoring. wai-init carries the baseline it needs.

echo ""
echo "✔ wAI skill suite installed into $SKILLS_DIR  (version $SRC_SHA)"
echo "  Next: in Claude Code run 'refresh skills' (or restart), then run wai-init if this repo"
echo "  is not set up yet — it scans the repo and writes docs/architecture/ (catalog + strategy)."
echo ""
echo "── doctor: does this repo's state still match the updated suite? ──"
# This is the mechanism that replaces the old "NOTE: re-run wai-cicd" sentence. The update
# changed the SKILLS; this checks whether the repo's expected artifacts and contract state kept up
# — a missing merge-gate.conf (the gate then returns UNKNOWN on every PR), a legacy learning ledger
# — because a missing file looks exactly like a repo nobody has touched. It reports PRESENCE
# (Phase A). STALENESS of an artifact that WAS generated (a ci.yml written before the latest
# template fix) still needs a `wai-cicd` re-run, which diffs it and proposes the delta.
sh "$SKILLS_DIR/wai/scripts/doctor.sh" "$DEST" || true
