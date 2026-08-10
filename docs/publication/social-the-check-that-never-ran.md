# Social posts — "The check that never ran"

Pick one angle per platform. They lead with different findings on purpose — don't post all of them.

---

## X / Twitter — thread (the strongest hook)

**1/**
Every code review my agent has ever run was told:

"look up the Red Flag for this catalog ID."

Last week I counted.

55 of 89 dimensions had no Red Flag at all.

62% of the document it was told to consult had nothing to consult.

**2/**
Here's what makes it worth writing about.

When the model is told to look up something that isn't there, it either
(a) invents a standard for that session, or
(b) quietly drops the finding.

You cannot tell which from the output.

A clean review looks identical either way.

**3/**
Two of the missing ones were "idempotent token consumption" and "no plaintext PII in logs."

Both marked in my own testing strategy as *mandatory targets*.

The two I was most sure were covered.

**4/**
Why did nobody notice?

A knowledge base has three operations: ingest, query, lint.

My suite writes docs. It reads docs.

It had never once **linted** them.

That's the whole story. Not a bad prompt. A missing operation.

**5/**
Same shape, one layer up: the merge gate.

Six conditions the model had to remember on every run.

And "the model checked" is not something you can audit. You can't grep it. You can't diff it.

**6/**
So I moved it out of the prompt and into 50 lines of shell.

The gate is now an exit code:

GO / NO-GO / UNKNOWN

Fail-closed: there is no path from "I couldn't check" to "go."

**7/**
Then my own gate failed OPEN.

zsh doesn't expand a variable as a glob inside `case` (needs GLOB_SUBST).

Under zsh, every contract-domain path matched *nothing*. A billing PR would have been reported clean.

A gate that fails open on the wrong shell is worse than no gate.

**8/**
The lesson isn't "scripts are safe."

It's that determinism buys you something you can **test** — and then you have to actually test it, in the direction that hurts.

**9/**
The rule I'd take away:

**A rule in a prompt is not a rule. It's a hope.**

It becomes a rule the moment something fails when it's broken.

**10/**
So: find the confident assertions in your prompts that nothing checks.

"Look up the Red Flag."
"Verify the approval rule is enforced."
"Never reuse a retired ID."

Then ask: *if that were false right now, what would tell me?*

If the answer is nothing, you don't have a rule. You have a sentence.

[link]

---

## LinkedIn (longer, professional register)

**A quiet failure mode in agent systems: rules nobody checks.**

Every code review my agent skill suite has performed was instructed to "cite the catalog ID and look up the Red Flag for that dimension" — the one-line description of what failure actually looks like.

Last week I counted. **Of 89 dimensions, 55 had no Red Flag at all.**

What makes this worth sharing isn't the number. It's the failure mode.

When a model is told to look up something that doesn't exist, it either invents a standard for that session — so the same finding is judged against a different bar every run — or it quietly declines to raise the finding at all. **And you cannot tell which happened from the output.** A review that found nothing looks identical whether the code was clean or whether the reviewer had no standard to measure it against.

Two of the missing ones were idempotent billing and "no plaintext PII in logs" — both marked in my own testing strategy as mandatory targets.

The reason nobody noticed is structural. A knowledge base has three operations: **ingest, query, lint.** My system wrote documents and read them. It had never once linted them.

I suspect this is very common. We are all writing markdown that other prompts are told to consult, and almost nobody has a check that asks: *does the thing you're telling the model to look up actually exist?*

The same shape appeared one layer up, in the merge gate — six conditions the model had to remember on every run. "The model checked" is not something you can audit six months later.

So I moved both out of the prompt and into two small shell scripts: one that returns an exit code for the merge gate, one that lints the catalog. The design that made it work: **the script owns mechanics, the model owns judgment.** No shell script can decide whether a finding is a blocker — and it shouldn't try. Both verdicts have to be green.

Then my own gate failed open under zsh (it does not expand a variable as a glob inside `case`), and would have reported a billing PR as clean. Which is its own lesson: determinism doesn't make you safe. It makes you **testable** — and then you still have to run the test in the direction that hurts.

Full write-up, both scripts and the commit history: [link]

---

## Short standalone variants (pick per platform)

**A — the counting hook**
> "Look up the Red Flag for that ID."
> 55 of the 89 IDs had no Red Flag.
> The model either invented one or dropped the finding — and the output looks the same either way.
> A rule nothing checks isn't a rule.

**B — the audit hook**
> "The model checked" is not a thing you can audit.
> You can't grep it. You can't diff it. Six months later you cannot answer whether it happened.
> So I moved the merge gate out of the prompt and into an exit code.

**C — the self-own (most honest, probably the best-performing)**
> I spent two days writing about how prompts fail invisibly.
> Then I shipped a merge gate that failed invisibly.
> zsh doesn't expand a variable as a glob inside `case`. Under zsh, every protected path matched nothing — and a billing PR would have come back clean.
> A gate that fails open on the wrong shell is worse than no gate.

**D — the anti-hype angle**
> I designed a 90-file restructuring of my agent's knowledge base.
> Then I did the arithmetic and reversed my own recommendation: the split would have made my most
> expensive runs *more* expensive, not less.
> The actual fix was one word in a config header.
> "Do the simplest thing that works" is doing a lot of work in that sentence.
>
> (The exact percentage lived in a conversation and was never written down, so it does not go in
> the post. That is the whole rule, applied to the post that argues for it.)

---

## Notes before posting

- **Test 0 in the empirical plan can falsify the central claim.** If the model turns out to ignore the
  script and check from memory anyway, the "determinism" framing is wrong and this needs rewriting.
  **Run that test before publishing.**
- Variant C is the most honest and probably the most engaging — self-critical technical posts travel
  further than "here's what I built."
- Don't post the thread *and* the LinkedIn post the same day; they share the same hook.
