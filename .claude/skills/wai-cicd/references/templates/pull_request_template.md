<!-- TEMPLATE — wai-cicd writes this to .github/pull_request_template.md.
     The lifecycle skills fill it; the human reads it to merge. Keep it judgment-first. -->

## What & why
<!-- One paragraph: the change and the problem it solves. Link the plan: docs/planning/<slug>/plan.md -->

## Catalog IDs touched
<!-- The quality dimensions this change affects. Cite the IDs from THIS repo's
     docs/architecture/quality-attributes.md — no other catalog's numbers mean the same thing. -->

## API backward-compatibility (store clients cannot be force-updated)
- [ ] No breaking change to an existing endpoint, **or** a new version was added (old kept)
<!-- If breaking: describe the versioning / migration plan. This blocks auto-merge
     (API versioning; min-version / force-update). -->

## Tests
<!-- What wai-testing covered: levels + the mandatory targets (security, idempotency,
     privacy, output validation). -->

## Risk / blast radius
<!-- low / medium / high — which components/apps/clients. Note destructive migrations explicitly. -->

## Merge gate
- [ ] Required checks green (lint · typecheck · build · unit · integration/e2e · security)
- [ ] Touches no excluded domain **or** is left for the human to merge
<!-- Excluded domains (canonical set: the wAI git protocol, § Excluded domains): the contract
     domain, destructive migrations, erasure / data deletion, and the suite's guardrails. An
     approval does not make such a change agent-mergeable — the human merges it, always. -->
