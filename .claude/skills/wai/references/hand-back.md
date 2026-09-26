# Hand-back — the last message of a run

The detail lives in the artifact — PR comment, report, plan, issue — and the chat links it.

1. **Result** — 1–2 lines: what happened, with the link.
2. **Your decisions** — only if any; one line each (a Blocker/Major, an excluded-domain merge, an
   open question).
3. **Next** — 1 line: the recommended step and the skill that takes it.
4. **Footer** — the output of `sh ../wai/scripts/open-items.sh --brief` (from the skill's
   directory), pasted verbatim. Run it before writing *Next*: the script derives, the model
   recommends. `exit 2` = nothing derivable: write `open items — not checked`.

At most ~12 lines, unless a Blocker/Major needs more. A skill whose report is its hand-back (the
team report) keeps that format, with empty sections omitted and one line per item. Answer in the
user's language.
