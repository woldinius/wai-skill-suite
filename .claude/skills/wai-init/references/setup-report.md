# Setup report — output format

> Reference for `wai-init` (process step 14). Read it when you are ready to report; it is
> the shape of the hand-off, not a decision you make earlier.

---

## Output format — setup report

Use exactly this structure:

```
## Platform init: [repo name]

**Status:** [Newly initialized | Already present → change proposal | Reset on request]
**Project:** [greenfield (N commits) | grown (N commits, M files) — detected, not asked]
**Repo mode:** [solo | team — how many humans commit here; drives the merge gate]
**Surface:** [backend+web | iOS | Android — which surface this repo is]
**Detected stack:** [languages · frameworks · API style/contract · DB · AI provider · billing · infra]
**Forge:** [GitHub — full suite | GitLab/other — see *Forge* below; the suite is GitHub-only by design]
**Catalog:** [tier: minimal | compact | standard | full — why · ~N lines, ~N IDs · docs language: en | de]
**Catalog scope:** [sections kept — shared core (`SEC`/`GDPR`/`API`/`MAINT`) + `PAY-*` + the surface's sections]
**Fit:** [full | partial (what differs) | low (why)]

### Created / Changed
- docs/architecture/quality-attributes.md — [new at tier X | diff proposal | kept unchanged]
- docs/architecture/testing-strategy.md — [new at tier X | diff proposal | kept unchanged]

### Tailoring (deviations from the baseline)
- Adopted: [dimensions/rows]
- Scoped out (other surfaces): [sections dropped because this repo isn't that surface]
- Softened/removed: [ID — reason]
- Added: [new ID — attribute — why]
- Existing Red Flags (grown repos): [ID — where the code violates this dimension *today*]
- Prioritization adjusted: [...]

### Forge & connection
- **Git remote:** [origin on GitHub `owner/repo` | GitLab/other → what still works, what doesn't | none — `git remote add origin <url>`]
- **`gh` CLI:** [installed & authenticated | missing → install + `gh auth login` | unauthenticated → `gh auth login`]
- **Issues:** [enabled & reachable | disabled → enable for the Issues round-trip | n/a]
- **Status:** [Ready | Setup needed → steps above | Optional bits missing (suite still works via proposed commits/PRs)]

### AI-readiness (proposals — apply them yourself)
- **CLAUDE.md:** [present & names stack + build/test commands | missing → proposed content]
- **Ignored dirs:** [clean | `node_modules`/`dist`/… tracked → poisons every agent search, propose .gitignore]
- **Secrets:** [none found | ⚠️ `<file>` committed — rotate, don't just delete: it's in the history]
- **Reproducible install:** [lockfile + pinned toolchain | missing → agents install a different tree than you]

### Setup decisions
- **Repo mode:** [solo | team → written to the catalog header; in team mode: auto-merge becomes
  `gh pr merge --auto` + 1 human approval, CODEOWNERS lists the team's contract owners]
- **`main` protection:** [PR-only, ruleset proposed/applied (team: + require 1 approval) |
  PR-only, but plan can't enforce → advisory gate only (git protocol is the wall) |
  human declined]
- **Docs language:** [English (default — the skills quote the catalog's IDs and stay English) |
  <language> for the prose; IDs and section names stay English and stable either way]
- **Tier:** [minimal | compact | standard | full — why; the catalog is read at runtime by nine
  skills, so this is the suite's main token cost]
- **Learning mode:** [active for <the human who ran init>, personal ledger under
  `~/.claude/learning/` (no repo-wide switch; colleagues unaffected) | not used]

### Tuning (re-run with history only)
- [what the trail shows: dimensions that never fired, Red Flags the code keeps tripping,
  strategy levels nobody writes — each as a proposed diff. Guardrails (merge gate, approve ban,
  decision point, personal state, audit scope) are excluded by design and are not listed here.]

### To verify (human)
- [assumptions from the scan that should be confirmed]

### Next steps
- Suite ready to use: wai-requirements-planning · wai-implementation · wai-pr-review
- [open items, e.g. apply the AI-readiness proposals; wire the connection if flagged above]
```

Omit sections that don't apply. With an existing catalog the output ends with the
diff proposal and waits for the "go".

