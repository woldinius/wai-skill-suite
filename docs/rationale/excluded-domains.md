# `excluded-domains.sh` — why it is written this way

> The narrative that used to live in this script's long comment blocks. Moved here on
> 2026-08-19: a comment is billed to the context window every time a model opens the file, and it
> does — when a skill says "run it", when something breaks, when anyone edits the check. The
> operative rule stayed in the script, where an editor sees it; the incident that bought the rule
> is here, still citable and no longer billed per run. **Nothing was deleted.**


## One classifier, because two copies fail open

The suite had this logic in two places drifting apart: the merge gate's §5-6 path check (the
everyday "a human merges this") and a proposed autonomy guard (the "an agent must NOT touch this
unwatched"). Two copies of the most load-bearing safety question in the suite is two copies to
forget to widen. This is the single answer both callers ask, homed next to doctor.sh so nothing
keeps a private copy of the domain set. merge-gate.sh §5-6 delegate here; §4 (team-approval
enforcement) stays in merge-gate.sh — it is not this script's remit.

## Which repository do we ask about

WHICH repository do we ask about? `--repo OWNER/NAME`, else $GH_REPO, else gh's own default
(the local git remote).

THIS EXISTED NOWHERE AND IT WAS THE GATE'S ONE FAIL-OPEN PATH. `merge-gate.sh` gained a --repo
selector and threaded it through every check it makes itself — then delegated here with only
`--pr <n>`, and this script resolved the diff from the LOCAL remote. Against a checkout whose
`origin` points elsewhere (the field case that produced --repo in the first place), the gate
judged one repository while this classifier read a PR of the same NUMBER in another — and
reported CLEAR on a diff it had never seen.

Every other unresolvable state in this script returns 2 and holds. That one returned "clean".

## The citation dial: why unanchored citations stopped gating

Is a family ANCHORED — does this repo declare paths that belong to it? (#30, decided 2026-08-18.)
EX-GDPR anchors on a non-empty ERASURE_PATHS. EX-PAY/AUTH/API/SEC anchor on a CONTRACT_PATHS glob
whose SHAPE classifies into that family (the same contract_subtags read used for tagging); a glob
whose shape is indeterminate (EX-CONTRACT) anchors nothing — the paths themselves stay fully
protected by the path check regardless, this only scopes the advisory citation channel.

WHY: the widening rule ("a citation may only widen") was safe and it was measured expensive — in
a repo declaring no paths for a family, the false alarm stood ALONE three times, and the cheapest
route to a green gate became "don't cite catalog IDs": the exact opposite of what the suite asks
for. Where a family has no declared surface, a citation is documentation, not contact — it is
still REPORTED (an advisory line, visible in the verdict) but no longer DECIDES. Where the family
IS anchored, nothing changes. Paths and diff statements remain authoritative everywhere; under
--autonomy the advisory set still HOLDS the drain (autonomy errs closed, always).

## Three text channels, one reach

Besides the path list, the classifier reads text in three places: the erasure regex (EX-GDPR), the
catalog-ID citation scan, and the PR's own metadata. Until #67 the three had **inconsistent
reach**, fourteen lines apart in the same script. The erasure regex read *added* lines, but from
*every* file — prose, ledger and run log included. The citation scan read the **whole diff file**
— context lines the author never touched, removed lines — plus the PR **title and body**. And the
variable holding title + body + labels was named for labels alone, so its detail line said
"widened by a gdpr/erasure label" when the trigger was the word *gdpr* in a paragraph, under a
single label named `ready-to-merge`.

WHY it changed is a measurement, not a taste. A field repo classified its last 64 merged PRs one
by one (field report of 2026-08-31 § 1c; its balance of 2026-09-06 over 259 verdicts):

- 10 PRs were tagged `EX-GDPR`. **9 came through the citation channel** — not one of them touched
  an erasure path; 1 came through `ERASURE_PATHS` (correct); 0 through the erasure regex.
- In **6 of the 10** it was the **only** exclusion reason — a GO otherwise.
- By trigger, across the PRs the report itemised: 5 from a **context line**, 2 from an added line
  of a **prose file**, 1 from **title and body alone** (no citation in the diff), 1 from an added
  **code** line (correct), 3 from `ERASURE_PATHS` (correct).
- Over the balance's 259 verdicts: 14 false positives, **12 of them this root cause**.

The shape matters more than the count. `wai-pr-review` cites the affected catalog ID in every
finding — the suite *requires* it — and the field repo's convention carries its run log and gate
ledger in most PRs as context. So the classifier tripped on the suite's **own mandatory citation**,
in the files the repo's **own convention** carries along, and the cheapest route to a green gate
was, once again, to cite less. That is the dial's incident (#30) a second time, one layer down: the
dial had scoped *which families* a citation may decide for; it had not asked *which lines* a
citation may be read from.

Three restrictions, all with the same thought — **a cited ID shows what the author means; it is not
a finding in itself** — and one rule about their reach:

1. **The citation scan decides from added code lines only.** Not a context line, not a removed
   line, not the title or body. `added_code_lines()` tracks the current file from the diff's `+++
   b/<path>` header; a diff captured without headers is all code. Where a file *begins* is the one
   question a content line must never answer: an added line whose text begins with `++ b/x.md`
   renders exactly like a header, and read as one it relabelled the rest of a code file as prose
   and turned a `DELETE FROM users` two lines later into an advisory. The fresh-context reviews of
   #71 found that hole twice — first inside a hunk, then through a blank context line that git's
   `diff.suppressBlankEmpty` writes as an empty line, which desynced the hunk counting built to
   close the first. The second fix does not count harder. In a **git-format** diff (every `gh pr
   diff` and `git diff`) the file boundary is the `diff --git` line itself, which no content line
   can start with because every content line carries a one-character prefix; the `+++` header is
   read only between that line and the file's first `@@`. Only a **bare** diff (`diff -u`, the test
   fixtures) still relies on hunk counts, and there every desync the parser can see — a line that
   fits no rule inside a hunk, an `@@` while counts remain, a content-shaped line between hunks —
   latches the rest of the diff to code. A bare diff is trusted as far as its generator's counts. A
   `+++` line outside a git header region (a `diff -u` section appended to a `git diff`) turns that
   line and the rest of that file to code, and a diff whose lines begin with terminal colour codes
   is UNKNOWN — an escape byte inside content is content (the third review of #71 found both; the
   fourth anchored the colour check to the start of a line). awk,
   the one tool this split adds to the deciding path, fails closed: a non-zero exit, no awk at all,
   or no work directory to record the failure in is UNKNOWN — a text channel that did not run is
   not a clean one.
2. **Prose is a deny-list, and its incompleteness points at the gate.** `.md .markdown .txt .rst
   .adoc .rdoc .textile` are prose; an extension nobody listed — and a file with none — is **code**,
   so the channel keeps reading it and keeps widening. An allow-list of code extensions would fail
   the other way, on exactly the file type nobody thought of. `.mdx` and `.org`, which the field's
   list carried, are deliberately *not* prose here: MDX embeds JSX and org files run babel blocks — a
   format that can execute is code. And a `.md` runbook whose SQL a human is meant to paste is
   advisory like any other document; `ERASURE_PATHS` is the declared way to gate a documented
   erasure path.
3. **Labels widen, descriptions do not.** A label is a declaration a human attached; a body is the
   text the suite told the author to fill with IDs. The variable is `LABELS`, and it holds labels;
   the title and body are no longer requested from `gh` at all — the test reads the stub's call log
   to prove it.

And the reach: **an added prose line is advisory, never deciding** — a citation or an erasure
statement in a `.md` is reported with its reason (`cited in prose, not code`; `in prose, not
code`), rides the verdict and the ledger row, and still holds the unattended `--autonomy` drain,
which errs closed as before. The field repo's own fix went one step further on one side and one
step less on the other — it dropped prose from the citation scan entirely and left the erasure
regex reading prose as gating; the suite chose one rule for both channels: visible, not gating.
Re-measured by the field repo against all 19 PRs it had ever tagged: **15 tags drop, 4 remain** —
the three erasure-module PRs and the one added code line — and no case in which the change hides a
real hit.

Unchanged, and pinned by the tests around this section: the path channel (`CONTRACT_PATHS`,
`ERASURE_PATHS`, `MIGRATION_PATHS`, the `EX-GUARD` floor), the destructive-migration grep (already
AND-gated on a migration path, so it needs no file-kind split), the dial's anchoring rule, and
`--autonomy`'s hold on the advisory set. `widen()` now names its tag in the anchored detail line
too — "widened by a cited PAY- family id" without an `EX-PAY` in front left the reader to infer
which tag had just been widened.

The field repo had carried this fix in its vendored copy of the script — a folder the next suite
update overwrites — with one red test as the only brake. That is why the change belongs here.

## Un-anchoring was silent

The citation dial makes a family's citations decide only where the family is anchored, and
anchoring is derived from the SHAPE of the `CONTRACT_PATHS` globs (and a non-empty
`ERASURE_PATHS`). That makes the set a side effect of an unrelated edit. Reported from a field repo
(2026-08-31), not yet written up here: `server/schema.js` was the only `*schema*` path in its
`merge-gate.conf`; when it was removed from the list, `EX-API` stopped being anchored, every `API-`
citation in added code turned advisory, and nothing said so — the verdicts simply changed
character.

So the set is now output. Every classified default-mode run prints `ANCHORED-DOMAINS: <tags>` (or
`ANCHORED-DOMAINS: none`) beside `EXCLUDED-DOMAINS:` / `ADVISORY-DOMAINS:`; the `--autonomy` HELD
branches print it too. The name is the output token; the internal shell variable `ANCHORED` is
unchanged and never printed under that name, so no caller's `grep '^ANCHORED'` can confuse the
two. `merge-gate.sh` states it as one terminal line — *citations decide here: …* — and keeps it
out of the ledger row on purpose: it is a property of the conf, not of the PR the row is about, and
a row is capped at 400 characters that belong to the verdict's reasons.

## Four reads that failed open

Four issues, one shape (#111, #112, #122, #78): the classifier read a path or a diff as *smaller*
than it was, and smaller read as CLEAR — under `--autonomy`, as AUTONOMY-ELIGIBLE. All four were
found by reading the script, in reviews and in PR #121. The review of their fix (#134) found four
more of the same shape: a quoted name, a Unicode case fold, a symlink to a directory, and hunks read
past their counts. Each now reads the whole change or says it cannot.

**A rename has two sides (#111).** In `--pr` mode the file list comes from `gh pr diff
--name-only`, which names a rename's destination only (so does `git diff --name-only`; checked on
this repo's PR #5, the review's own reproduction). `src/billing/charge.ts` moved to
`src/util/charge.ts` with an edit classified CLEAR; an agent file moved out of the floor did too.
The classifier now reads the diff's `rename from` / `rename to` headers and classifies both sides
with the file list. The set is only ever added to. A header line exists only between `diff --git`
and the file's first `@@`, where no content line can be, because every content line carries a
one-character prefix. The `--autonomy` allowlist reads the same set: a move *out of* an unsafe path
touches that path.

**A quoted name (the review of #134).** `gh pr diff --name-only`, `git diff --name-only` and
every git header quote a path that holds a non-ASCII byte (`core.quotePath`):
`"src/billing/caf\303\251.ts"`, with the leading `"` kept. The list was matched as printed, so one
accented letter took `.claude/agents/évil.md` or a billing file past every glob — on the
gate's own `--pr` path, ever since the list was first read. Each entry of the list, and each path a header
names, is now decoded once (`\ooo`, `\\`, `\"`). An entry that does not decode — an unbalanced
quote, another escape, a control character — is still matched as printed, and the run is UNKNOWN.
A decoded name is bytes and need not be UTF-8, which a UTF-8 locale's `tr`, `sed` and `sort` reject
mid-pipeline: an empty key matched nothing, and the whole list read CLEAR. The script therefore
runs in the C locale.

**Case and symlinks (#112).** macOS's default file system ignores case: a clone puts
`.Claude/agents/evil.md` into the directory `.claude/agents/` resolves to, where Claude Code loads
it, and the floor matched byte for byte. The blocklist — the floor and the `CONTRACT_PATHS`,
`MIGRATION_PATHS` and `ERASURE_PATHS` globs — now folds case on both sides. ASCII case alone was
not enough (the review of #134): APFS folds the long s `ſ`, the Kelvin sign, both sharp s and
the ligatures `ﬀ ﬁ ﬂ ﬃ ﬄ ﬅ ﬆ` to ASCII, so `.mcp.jſon` opens
`.mcp.json`; NTFS upper-cases the dotless `ı` to `I`; HFS+ ignores the zero-width and
bidi-control code points git's own HFS check skips. Those are mapped byte-wise before the ASCII fold.
Every other non-ASCII letter folds to a non-ASCII one, so it cannot reach an ASCII glob; a
non-ASCII letter *in* a conf glob gets the ASCII fold only, and composed and decomposed accents
are not unified. The cost, named: a case-sensitive repo whose `Src/Billing/` is not billing is held
for a human, a false positive on the side the suite errs toward. The `AUTONOMY_SAFE_PATHS`
allowlist does *not* fold: there a fold could only make more paths "safe", and on a case-sensitive
file system `Docs/` is not the `docs/` a human affirmed.

A bare `apps/web/.claude` in a file list is a symlink in the directory's place (the review of
#109, round 5): Claude Code reads through it, so a package's whole configuration moved to an
unguarded path and classified CLEAR. The blocklist now reads every path as a directory too
(`path/`), so `.claude/*` holds the bare `.claude`, and `src/billing/*` holds a link at
`src/billing`. A symlink anywhere is classified as the path it points at: git marks it with mode
`120000`, its one added line is the target, resolved against the link's directory — and read as a
directory as well, so `src/util/paylink -> ../billing` is billing (the review of #134). A target
that is absolute, empty, climbs out of the repository or points at its root cannot be classified,
and the run is UNKNOWN. The allowlist reads neither as a directory.

What it still cannot see, because each needs the repository and not the diff: a bare diff
(`diff -u`) carries no file modes, so a symlink there reads as an ordinary file; a target that is
itself an existing symlink is resolved one step only; a pure rename of a symlink carries no mode
line, so its (unchanged) target is not re-read.

**The wrong cwd (#122).** With no override and no git work tree, the config base is the cwd. From
a skill's directory in a plugin install — the plugin cache, not a git repo — there is no
`docs/architecture/merge-gate.conf`, `CONTRACT_PATHS` reads as empty, and `src/billing/pay.ts`
printed `ANCHORED-DOMAINS: none` and `VERDICT: CLEAR`, exit 0, where the same call from the repo
root said `EX-PAY`. PR #121 moved the one documented call that ran this way to the repo root; the
script itself still did not refuse the wrong cwd. Now `--files` / `--pr` with no
`EXCLUDED_DOMAINS_MERGE_CONF`, no git work tree and no `docs/architecture/` in the cwd is UNKNOWN,
exit 2. `--list-domains` reads no config and works from anywhere. The test is the directory, not
the conf file: a repo root without `merge-gate.conf` is a state the gate already reports itself
(UNKNOWN in `merge-gate.sh`, drift in `doctor.sh`), and the gate's non-git test fixtures carry
their conf in the cwd.

**A word diff is not a unified diff (#78).** `git diff --word-diff=plain` writes an added line as
`{+…+}` with no `+` prefix, so an added `DELETE FROM users` was never scanned and the run read
CLEAR. `--color-words` with `color.diff.meta` and `color.diff.frag` set to `normal` read the same:
no line begins with an escape sequence, so the colour guard does not fire. Only a local capture
passed with `--files/--diff` can carry one; `gh pr diff` emits a unified diff. The classifier does
not parse word diffs; it checks the unified form, and a breach is UNKNOWN through a marker in the
work directory, the way a failed awk is. In a git-format diff a hunk runs exactly as far as its
`@@ -o,l +n,m @@` counts, and three rules hold:

1. Every line inside it starts with `+`, `-`, a space or `\`, or is empty or a lone CR.
2. Its counts come out exact: the space and `-` lines make `l`, the space and `+` lines make `m`,
   neither overshoots. A word diff writes one line where unified writes a `-` and a `+` line, so its
   counts do not come out — the YAML in-line edit beside a `- name:` context line the review of
   #134 reproduced included.
3. One line at least is `+` or `-`. An in-line edit inside an indented block passes the first two
   — every line starts with a space, the counts match — and fails this one.

A line after the counts run out is no hunk's: the signature `git format-patch` writes, the next
commit of `git log -p`. Those captures read UNKNOWN while the rules ran to the next header (the
review of #134); they classify now. A bare diff keeps its count-based latch rules and adds the
first rule; in a bare diff that rule replaces the latch to code the parser applied to such a line —
UNKNOWN is the stricter answer. The message names the form that broke, not a tool: which tool
wrote a capture is not knowable from it.

Still open, named: a word diff whose lines all start with `+`, `-` or a space *and* whose counts
come out exact *and* which has a `+` or `-` line would pass. No such capture was found, and the
classifier is a check on the unified form, not a word-diff reader (#78). Capture with
`--no-color` and without `--word-diff`.
