# Empirical test plan — 5 repos, several weeks

Everything built in this session is **specification-verified, not behaviour-verified.** Four
adversarial agents read the documents; **not one skill has ever run against a foreign repo.** This
list closes exactly that gap.

**The order is deliberate.** Test 0 can invalidate everything else — so it goes first.

---

## 0. The test that could falsify the whole thesis

**Does the model actually run the script — or does it still "check from memory"?**

The entire determinism argument (and the blog post) rests on this. `wai-pr-review` says *"run
it and obey the exit code… never re-derive it from memory."* Whether it does is unknown.

**Setup:** a PR that forces `merge-gate.sh` to `NO-GO` — e.g. touch one file under a
`CONTRACT_PATHS` glob and nothing else. The diff is trivially clean, so the review will *want* to say
"no blockers, merge."

**Observe:**
- [ ] Does the model **run the script at all**? (Does the call appear in the transcript?)
- [ ] Does it **quote the exit code**, or invent its own reasoning?
- [ ] **Does it merge anyway?** That is total failure.
- [ ] Does the output name the reason the *script* gave, or a self-authored one?

**If it ignores the script:** the script is worthless as long as it is merely *recommended*. Then the
call has to be forced — a hook, or the gate moves out of the skill and into CI entirely. **This would
be the single most important result of the whole empirical phase.**

---

## 1. The gate in the wild

**1.1 False positives — the reason gates get bypassed.**
- [ ] Log every `NO-GO`: did **you** then merge that PR **unchanged**?
- [ ] A cluster means `CONTRACT_PATHS` is drawn too wide. **A gate that cries wolf gets switched
      off** — and then it is worse than no gate.
- [ ] Target metric: what share of `NO-GO`s were justified?

**1.2 False negatives — the dangerous direction.**
- [ ] Review every **agent-merged** PR afterwards: would *you* have blocked it?
- [ ] One hit here outweighs ten false positives.

**1.3 `UNKNOWN` verdicts.**
- [ ] `install.sh` (the script) and `wai-init` (the repo docs) update on **independent paths**.
      Across five repos, skew is guaranteed. Record every `UNKNOWN` with its cause.
- [ ] Expected causes: no `merge-gate.conf`, no catalog, no `gh`. **Unexpected causes are bugs.**

**1.4 `team` mode — never tested.**
- [ ] The approval-rule verification (`gh api .../rulesets`) has only ever run against a **solo** repo.
- [ ] In a real team repo *with* a ruleset: does it detect the rule? And *without* one (403 on the
      free plan): does it **refuse to arm `--auto`** instead of arming it?
- [ ] This is the check that stops `--auto` from merging **immediately** while the run reports
      "waiting for a second human."

---

## 2. The sizing doctrine — asserted, never measured

**2.1 Measure `tier: compact`.** *Blocks the compact-tier decision and any reconsideration of the catalog split.*
- [ ] Set `tier: compact` in **one** repo; leave `full` in the others.
- [ ] Measure tokens per `wai-pr-review` invocation, before/after.
- [ ] **And the question that actually matters:** do the reviews get *worse*? If not, `full` is wasted
      money in four repos.

**2.2 Which catalog IDs ever fire?** *Blocks the which-rules-fire decision.*
- [ ] Across all reviews and audits, count every cited ID.
- [ ] IDs that produce **no finding in weeks** are candidates for removal — or for being replaced by
      **one canonical example** (Anthropic: examples beat a laundry list of rules).
- [ ] Hypothesis I want tested: 20% of the IDs produce 80% of the findings.

**2.3 Do the new Red Flags actually catch anything?**
- [ ] 55 were written last week. Which ones lead to a real finding?
- [ ] Which are phrased too softly to ever fire? (Then the Red Flag is decoration with a different
      label.)

---

## 3. Skills that have never been executed

Everything here is **new behaviour from this session** that has never run once.

- [ ] **`wai-init` now asks the setup questions BEFORE writing** (steps renumbered). Does it?
      Or does it still guess `Repo mode: solo` and write first?
- [ ] **`wai-implementation` cuts the branch itself** when planning didn't run. Does it — or does
      it start committing on `main` until the guard trips?
- [ ] **The review lenses — the sharpest test on this list: review the same PR three times, with
      `adversarial`, `null-hypothesis` and `breadth`, and diff the findings.**
      **If the same list comes back, the lenses are decoration.** They must find *different* things,
      or the whole mechanism was pointless.
- [ ] **Contract change → `breadth` + `adversarial`** (the double lens). Does `breadth` actually find
      the client that breaks?
- [ ] **The landing rule:** does a Minor finding really get filed as an issue — including on a PR the
      *human* merges? Or does it still evaporate in the chat?
- [ ] **Severity labels don't exist in the real repos.** Does `gh issue create` degrade cleanly to an
      unlabelled issue instead of losing the finding?

---

## 4. `wai-learning-gap` — four bugs fixed, none verified live

- [ ] **Slug drift:** does the skill find your ledger now that the repo moved from one
      account to another? (That is why it never fired at all.)
- [ ] **`core.hooksPath`:** in a repo **with husky** — is the hook installed where git actually runs
      it, or silently into the void?
- [ ] **Marker already in `HEAD`:** does the hook block a commit when the marker is already staged?
- [ ] **`git restore` ≠ solved:** if another skill cleans the tree, is the gap wrongly recorded as
      "solved" and the Leitner box promoted?
- [ ] **The audit carve-out:** does `wai-architecture-audit` leave a `LEARN #` marker alone — or
      list it as a commented-out block to be cleaned up?

---

## 5. What only shows up at scale

- [ ] **`wai-team` over a real batch** (10+ issues): **where exactly does context run out?** At
      which issue? (the number determines the shape of the state fix.)
- [ ] **Token cost per skill invocation, measured rather than estimated.** My numbers assume ~3.7
      chars/token — a guess. The real figure decides whether the catalog question matters at all.
- [ ] **Does `catalog-lint.sh` stay green?** The audits are licensed to "evolve the rules" and the
      tuning pass proposes catalog diffs. Does anyone ever try to reuse a retired ID?

---

## 6. How to record it (or it isn't empirical)

The `wai-init` **tuning pass exists precisely to consume this evidence.** For that, it has to
exist as structure, not as memory.

- [ ] One `docs/architecture/empirics.md` per repo: date · skill · what happened · what *should* have
      happened.
- [ ] **Record every time you override a skill.** That is the single most valuable signal available:
      a rule the human routinely ignores is a wrong rule.
- [ ] **Record every case where the model follows a rule sometimes and not others.** That is exactly
      the candidate that belongs in a script rather than a prompt — the lesson of this session.

---

## What I expect (so I can be wrong)

1. **Test 0 passes.** The model runs the script. *If not, the blog post is wrong and must be rewritten
   before it goes out.*
2. **`CONTRACT_PATHS` is initially too wide** → false positives → tighten.
3. **The lenses do produce different findings** — but `null-hypothesis` fires rarely, because most PRs
   are features, not fixes.
4. **`tier: compact` loses nothing.** Then `full` is wasted in four repos, and the catalog-split
   question is settled for good.
5. **At least one item on this list is a bug that four adversarial agents missed.** That is the whole
   reason for doing it.
