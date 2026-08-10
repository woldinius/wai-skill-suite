# The check that never ran

*Two shell scripts, and what they found in an agent skill suite.*

---

Every code review my agent has ever performed was told to do the same thing:

> *"Cite the affected catalog ID in every finding. Read the reference when you need the Red Flag for that dimension."*

The Red Flag is the operative part — the one-line description of what failure actually looks like. `SEC-8`'s is *"an ID from the request is fetched without an ownership predicate."* That's what makes a finding decidable instead of a matter of taste.

Last week I counted. **Of 89 dimensions in the catalog, 55 had no Red Flag at all.**

Sixty-two percent of the document the reviewer was told to look things up in had nothing to look up.

---

## The failure looked exactly like the success

Here's what makes this worth writing about. When the model is told *"look up the Red Flag for `PAY-4`"* and `PAY-4` has none, it does one of two things:

1. **It invents one for that session.** The billing finding then gets judged against a bar nobody agreed to — a different bar every run.
2. **It quietly doesn't raise the finding.** The dimension is decoration.

And here's the part that kept it alive: **you cannot tell from the output which one happened.** A review that found nothing looks identical whether the code was clean or whether the reviewer had no standard to measure it against. There is no error, no warning, no smell. The system reports success either way.

Two of the missing ones were `PAY-4` (atomic, idempotent token consumption) and `GDPR-5` (no plaintext PII in logs) — both marked in my own testing strategy as *mandatory targets*. The things I was most sure were covered.

It gets better. I'd shipped a "sizing" feature the week before that lets you shrink the catalog for smaller projects. Its smallest tier is defined as **"ID + name + Red Flag, one line."** For 62% of the catalog, that tier was ID + name and nothing else. I had built a dial that promised to preserve the one thing that was mostly absent.

---

## Why nobody noticed

A knowledge base has three operations: **ingest, query, lint.**

My suite writes documents (a setup skill authors the catalog; audit skills write reports). It reads them (nine skills load the catalog at runtime). And it had **never once linted them.**

That's the whole story. Not a bug in the prose. Not a bad prompt. A missing operation.

I suspect this is extremely common in agent setups. We're all writing markdown that other prompts are told to consult, and almost nobody has a check that says *"does the thing you're telling the model to look up actually exist?"*

---

## The same shape, one layer up

While I was in there, I found the same pattern in the part of the system I'd have sworn was the most careful: the merge gate.

The rule was that an agent may merge a pull request only when it is clean, touches no contract domain (auth, billing, the API surface), has no destructive migration, and CI is green. In `team` mode it must not merge at all — it arms GitHub's auto-merge and waits for a second human's approval.

That was **six checks the model had to remember, every run, forever.**

And *"the model checked"* is not a thing you can audit. You cannot grep for it. You cannot diff it. Six months later you cannot answer the question *"was the approval rule actually verified on PR #211, or did the model just say it was?"*

Anthropic's own [context engineering guidance](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) names this directly:

> *"Engineers hardcoding complex, brittle logic in their prompts to elicit exact agentic behavior. This approach creates fragility and increases maintenance complexity over time."*

The instinct when you read that is to write better prose. That's the wrong lesson. **If the logic must be exact, the answer is not to phrase it better. It's to take it out of the prompt.**

---

## Two scripts

### `merge-gate.sh` — the gate is an exit code

It checks the mechanical preconditions and returns a verdict:

```
$ sh merge-gate.sh 24
merge-gate: PR #24 (owner/repo → main, mode: solo)
  ✓ quality catalog present
  ✓ repo mode: solo
  ✗ no CI checks report on this PR — zero checks is not 'green'
  ? no merge-gate.conf — cannot tell which paths are contract-domain
VERDICT: UNKNOWN — a precondition could not be verified. Leave the PR for the human.
```

Three design decisions did the actual work:

**1. The gate is a conjunction, and the split is the point.** The script owns *mechanics*: does the catalog exist, are there required checks and are they green, is an approval rule genuinely enforced on the base branch, does the diff touch a contract-domain path, is there a destructive migration. The model owns *judgment*: is this finding a Blocker? No shell script can decide that, and it shouldn't try. **Both verdicts must be green.** The script doesn't replace the reviewer. It removes the reviewer's need to remember.

**2. Fail-closed, without exception.** No `gh`, no catalog, no config, an unreadable diff → `UNKNOWN` → the human merges. **There is no path from "I could not check" to "go."** This sounds obvious and is the single easiest thing to get wrong (see below).

**3. Logic in the tool, config in the repo.** Four of the six checks are generic — they query GitHub and the filesystem. Only two are repo-specific: *which paths are the contract domain*, and *where do migrations live*. Those are **globs, not code**. So the script ships once with the tooling, and a small `merge-gate.conf` in each repo holds the globs. Five repos get five configs, **not five drifting copies of security-critical logic.**

That third point had an immediate payoff. It turned out two different parts of my system independently defined "which paths are sensitive": this config, and the `CODEOWNERS` file that routes those paths to a human reviewer. Two lists of the same truth, never reconciled. The first time someone moves a module, they diverge — and then CODEOWNERS routes a billing PR to a human that the gate waved through. Or the reverse. Both files stay internally consistent. **Nobody notices.** Now one is generated from the other.

### `catalog-lint.sh` — the missing third operation

```
$ sh catalog-lint.sh          # before
  ✗ 89 dimensions but only 34 Red Flags — 55 are not decidable
  VERDICT: FAILED                                        → exit 1

$ sh catalog-lint.sh          # after
  ✓ 89 dimensions, 89 Red Flags — every dimension is decidable
  ✓ no duplicate IDs
  ✓ no retired ID reused (6 retired)
  ✓ every catalog ID cited by a consuming skill resolves
  VERDICT: OK                                            → exit 0
```

That last check deserves a note. IDs are the only linking primitive the system has — every review, plan, issue and audit report cites them. There's a "retired IDs" section that says *never reuse these numbers*, because reusing `SEC-12` would silently rewrite the meaning of every past finding that cited it. Until now, that rule was enforced **by discipline alone.** Now it's enforced by a script.

---

## My own gate failed open

I want to be precise about this, because it's the strongest argument in the piece.

The script matches file paths against globs from the config using a shell `case` statement. I tested it. It worked. Then I ran it under `zsh`.

**zsh does not expand a variable's contents as a glob pattern inside `case`** — that needs `GLOB_SUBST`. So under zsh, every contract-domain path matched **nothing**, and a billing PR would have been reported as clean.

**A gate that fails OPEN on the wrong shell is worse than no gate**, because it produces a confident green. The failure is silent and it points the wrong way. It now re-execs under `sh` and I verified identical output under sh, bash, zsh and direct execution.

I'd spent two days writing about how prompts fail invisibly, and then built a script that failed invisibly. The lesson isn't "scripts are safe." It's that **determinism buys you something you can test** — and then you have to actually test it, adversarially, in the direction that hurts.

While I was there I ran `shellcheck` — a foreign tool, deliberately, because the same hand wrote the installer and my own security-review skill, so they share blind spots. It found `SC2115` in the installer: `rm -rf "$DIR/$x"` expands to `rm -rf "/$x"` if the variable is ever empty. In the one script in the repo that had **already destroyed data once**, by inferring ownership from a directory name.

---

## What this is not

It is not a case for scripting everything. The gate's whole design rests on the opposite: the script decides mechanics, the model decides judgment, and neither is allowed to do the other's job. I also spent a day designing a large restructuring of the catalog — and then killed it, because the arithmetic said it would have made my most expensive runs materially more expensive. (The exact percentages from that estimate are not preserved — publishing a number I cannot show would be the same failure this post is about.) The fix turned out to be one word in a config header.

Anthropic's guidance ends with a line I keep coming back to: *"do the simplest thing that works."*

The lesson I'd take is narrower, and I think it generalizes:

> **A rule in a prompt is not a rule. It's a hope.** It becomes a rule the moment something fails when it's broken.

Find the assertions in your prompts that nothing checks. Not the vague ones — the *confident* ones. *"Look up the Red Flag."* *"Verify an approval rule is enforced."* *"Never reuse a retired ID."*

Then ask the only question that matters: **if that were false right now, what would tell me?**

If the answer is nothing, you don't have a rule. You have a sentence.

---

*The skill suite, both scripts and the full commit history are at [github.com/woldinius/wai-skill-suite](https://github.com/woldinius/wai-skill-suite).*
