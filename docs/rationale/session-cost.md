# `session-cost.sh` — why it is written this way

> The reasons behind the rules in the script's header, written with the script on 2026-09-26.
> Every number here was measured on the author's machine that day, over this repo's own session
> transcripts, and ages with them.


## Q5 had no instrument

Q5 in [`open-questions.md`](../open-questions.md) asks what a lifecycle run costs in context, and its
answer was "Not measured": the token numbers of an earlier retrospective were preserved nowhere.
Claude Code keeps what was missing. It appends one JSON line per event to
`<dir>/<session-id>.jsonl`, and a subagent's lines to `<dir>/<session-id>/subagents/*.jsonl`; every
API response lands there with the usage record the API returned. The script sums those records.

What it measures is a **session**, not a lifecycle run: a session holds any number of skill runs,
and a usage record says how large a call was, not which files filled it. So Q5 gets a first
number, and stays open. The split it asks for — SKILL.md against references against the catalog
— needs the sizes of what each call loaded, and the transcript does not record that per call.

The script is an extractor in the retro's sense (ADR-0002): it counts and prints, it renders no
verdict, and it writes nothing — no run-log row, since a row would claim a skill run that did not
happen.

## A response is a requestId, not a line

Claude Code writes one line per content block, so one response is often several lines — and
while it streams, the lines disagree. In the one completed session measured, 3,852 lines carried
a usage record for 1,205 request IDs; 1,061 of those responses spanned more than one line, and
for 342 of them the lines disagreed on `output_tokens`. Summing lines overcounts, and taking the
first line undercounts. The line with the largest `output_tokens` is the last snapshot of that
response, so the script keeps its usage. The key is the `requestId`; `message.id` is the fallback,
and a line with neither counts once, on its own.

Not every usage record is a response. Claude Code writes placeholder lines itself, with the model
`<synthetic>` and every counter at zero: twelve in this repo's transcripts that day — nine rate
limits, two server errors, one interrupted turn. Counted as responses, they would pull the
average context down for calls that never happened. They are skipped, and the skip prints its
own count.

### Why a walk over the JSON, not a pattern

Three things in the real files defeat a substring match:

- **Quoted transcripts.** A tool result that quotes transcript lines carries them as a JSON string,
  so their quotes are escaped: `\"usage\":{`. The session this script was written in held 1,020
  of them on 27 lines — mostly the development of this very script. They are string content and
  must never count.
- **Tool inputs are objects.** A `tool_use` input is structured JSON, not a string, and in the
  message it comes before `usage` — so a key named like a usage key can precede the real one.
- **Two key orders.** An ordinary line puts the top-level `"type":"assistant"` after the `message`
  object and the `requestId`; the placeholder lines put it before. Position cannot say which
  `type` is the top-level one; only depth can.

Inside the usage object there are two more traps: `output_tokens_details` begins like
`output_tokens`, `cache_creation_input_tokens` ends like `input_tokens`, and a nested `iterations`
array repeats all four keys. Keys are therefore compared whole, and only at the usage object's own
depth.

The walk stays in awk and in one streamed pass: drop every escape pair (a backslash and the
character after it), and no quote is left inside a string; splitting the line at quotes then
alternates between text outside strings and string contents, so the bracket depth can be counted
in the outside parts alone. The escape pairs are dropped, not unescaped: an unescaped `\"` becomes
a real quote, and the test with an odd number of escaped quotes shows what that does to every
count after it.

## Counters, no clock and no price

Fresh input (`input_tokens + cache_creation_input_tokens`) and cache reads are printed apart,
because the two are billed at different rates, and one "input" number would hide which one
grew. The average context per response — (fresh input + cache read) / responses — is the size of
what each call carried, and printing it for the main thread and the subagents separately is what
shows the context a delegation keeps out of the main thread.

No price and no cost share: prices are not in the transcript, and a price table inside the
script would go stale with nothing to notice it. The footer says so in the style of
`retro-compliance.sh`'s COUNTS ONLY line.

No message content and no time data: every transcript line carries a timestamp, and none of it
reaches the output. The counters need no clock, and a session's times are personal data the
suite has no use for — a standing rule of this repo. A test holds it: every fixture line carries
a timestamp and a message text, and the output must match neither a clock time, nor a date, nor
the text.

## The default dir

Claude Code names a project's transcript dir after the path it runs in, with every character
outside `[A-Za-z0-9]` replaced by `-`. The rule was first written down as "every `/` and `.`";
the dirs on the author's machine showed it is wider — a path with a space and a non-ASCII letter
maps both to `-`, one per character. The script replaces every character outside
the set, and counts characters the way a JavaScript string does (a two- or three-byte UTF-8
character is one `-`, a four-byte one two), with byte classes under `LC_ALL=C` so the result does
not depend on the caller's locale. A path the rule still misses is one `--dir` away, and exit 2
names the path that was tried.

The script derives the path from the repo toplevel, and a linked worktree has a toplevel of its
own. A worktree agent's transcript lives in the parent session's dir, under `subagents/`: this
script was written in a linked worktree under `.claude/worktrees/`, and that worktree's own slug
had no dir. So where the worktree's slug has no dir, the main checkout's slug is tried next, and
exit 2 names both paths.

A response met in two files counts once, for the file read first — main transcripts before
subagent transcripts, so a response a subagent's file might repeat stays with the main thread.
No request ID occurred in two files that day. With `--session`, only that session's files are
read, so a response it shares with another session counts for it.
