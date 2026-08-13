---
name: wai-security-audit
description: >-
  Periodic, whole-codebase security audit — an adversarial "how would an attacker break this" sweep:
  authN/authZ and IDOR, secrets, injection (incl. prompt), SSRF, rate limiting, session/token
  lifecycle, dependency CVEs, crypto/TLS, tenant isolation, token-economy fraud, PII exposure.
  Report-only and redacted. Chains findings into ranked end-to-end attack paths. Use it to assess
  posture as a whole: "security audit", "pentest", "threat model", "check the attack surface", "are
  we secure", "find vulnerabilities". Run periodically and before a release. Not for structural
  health (wai-architecture-audit), a single diff (wai-pr-review) or a fix (wai-implementation).
license: MIT
---

# Security Audit (adversarial, whole-codebase)

Audit the **whole system as an attacker would** — not "is the code clean" (that's
`wai-architecture-audit`), but **"how would someone break in, escalate, drain, or exfiltrate?"**
Security bugs don't announce themselves in a single diff; a missing ownership check, an
unthrottled expensive endpoint, a leaked key or a vulnerable transitive dependency accumulates
silently until exploited. This skill takes the attacker's stance, maps the attack surface, and
measures the posture as a **trend over time**.

## Platform context

*(The suite's home platform — the worked example these skills grew against, kept concrete on purpose. `wai-init` scopes the quality catalog to what **your** repo actually is; where your product has none of this — no token economy, no mobile clients, no AI orchestration — read the matching rules as not-applicable, not as findings.)*

A **multi-surface product** — cloud backend (AI orchestration + server-side token ledger) with
**Web, iOS and Android** clients, joined by a **versioned API contract**; each client sells
tokens. Four consequences shape every security audit:
- **The clients are publicly distributed and hostile-controllable** → nothing in a binary/bundle
  is secret (`CLIENT-1`/`SEC-1`); every protected call needs server-side authZ + attestation
  (`SEC-2`/`CLIENT-2`), never client-trusted state.
- **AI inference costs real money per token** → an unthrottled or unauthenticated expensive
  endpoint is a **financial** attack (cost-drain), not just a nuisance (`SEC-9`/`AI-9`).
- **Users upload content that reaches models** → prompt injection is a first-class threat class
  (`SEC-4`), and uploads/URLs are an SSRF and malware surface (`SEC-11`).
- **The token economy is a fraud target** → receipts, webhooks and refunds are money paths;
  forge/replay/refund-fraud are the adversarial view of `PAY-*` (`SEC-13`).

## Stance

- **Adversarial & whole-codebase.** Assume breach; think in attack paths, not checklists. Not a
  per-diff review (`wai-pr-review` / the `/security-review` command do that) — it sweeps the
  entire system periodically and on triggers.
- **Report + proposals only — never auto-fix.** Security fixes carry behavioral risk; the
  deliverable is a prioritized, evidence-backed report and remediation proposals handed to
  `wai-implementation`. **Edit nothing.** The one exception is escalation, not editing: a **live
  exposed secret** is surfaced to the human immediately (rotate + purge history) rather than
  quietly filed.
- **Evidence, safely.** Back each finding with a concrete path — the vulnerable file/line, the
  request that would exploit it, the tool output. **Never run a real exploit against production
  or real user data**, and **never put a live secret or a working exploit payload in a report or
  a public issue** — redact (`SEC-3`/`GDPR-5`).
- **Exploitability × impact, not severity theatre.** A theoretical issue behind three auth layers
  ranks lower than an unauthenticated one.
- **Chains over isolated findings.** After the dimension walk, synthesize the findings into
  end-to-end **attack paths** (entry → pivot → objective) and rank the *chain*, not only its
  parts. Composition can **elevate** — three "Minor" gaps that compose into a tenant takeover are
  a Blocker together — and reachability can **drop** a scary-looking finding that reaches no
  objective. Reasoned from code + tool evidence, **never executed against production or real
  data**. This is process step 5; the method is `references/security-audit-playbook.md §4`.
- **Proportional & honest.** A hardened codebase gets a short "posture is sound" report; don't
  manufacture findings. But be thorough where money, auth, PII and the contract meet.
- **Allowed to evolve the rules.** When a finding shows the catalog's `SEC-*` is missing a
  dimension, propose a new ID (separated from code findings).

## Process

Work through these in order. Scale depth to the change surface since the last security audit.
**Discovery and synthesis are two phases.** Steps 2-4 (map the surface, run the tools, walk the
dimensions) are **discovery** — independent lenses that may run in **parallel**, in any order.
Step 5 (attack-path synthesis) is a **join point**: it runs strictly *after* every discovery step
has reported — synthesize against a half-mapped surface and you miss the paths that cross the
parts you hadn't charted yet.

1. **Scope & baseline** — Find the previous security audit under
   `docs/architecture/security-audits/` (most recent dated file). Determine what changed since
   (git log since that date, or the last N merges) — especially **new auth, upload,
   outbound-fetch, payment or dependency** changes. Read the catalog's `SEC-*` (+ `GDPR-*`,
   `PAY-*`, `CLIENT-*`) and any threat-model doc as the intended posture. If the catalog is
   missing, note it once (suggest `wai-init`) and use the dimensions below as the standard.

2. **Map the attack surface** — Before hunting bugs, chart the entry points and trust boundaries.
   Enumerate: every **endpoint** (auth required? role? cost?), **upload/ingest** path, **webhook**
   (payment/RTDN/provider), **auth/session** flow, **outbound fetch** (user-influenced URLs), and
   every place **secrets, PII or tokens** flow. This map makes the dimension walk exhaustive
   rather than random.

3. **Tooling pass** — Run the security tools and capture output (commands per stack in
   `references/security-audit-playbook.md`): **secrets** (gitleaks over the history), **SAST**
   (semgrep with the security rulesets), **dependency CVEs**, plus targeted greps (see playbook).
   Tools find the mechanical layer; the dimension walk finds the logic layer.

   **For dependency CVEs, run the script — do not eyeball a scanner.** `sh
   scripts/dep-cve-scan.sh` walks each ecosystem present, runs its scanner *if installed*, and
   emits a per-ecosystem `ran=true`/`not_measured` line with counts; **exit 2 means at least one
   scan did not run.** `npm audit 2>/dev/null` returning empty looks identical whether it found
   **zero CVEs** or **never ran** — **a scan that did not run is `not measured`, NEVER
   "no CVEs".** If the script reports a gap, install the named scanner (`osv-scanner` covers
   most ecosystems) and re-run before you trust a zero — or report the gap honestly as
   unmeasured. The script owns *did it run and what did it find*; **you** own whether a found
   CVE is reachable/exploitable here. Its counts are timestamped evidence — a higher count next
   run may be a new disclosure, not a regression.

   **But `dep-cve-scan.sh` sees only ONE of three CVE surfaces — say so.** It scans **lockfile
   deps**; it cannot see **OS packages** or **runtime-bundled libraries** (e.g. Node's `undici`
   behind `fetch`, which ships in `node:*-alpine`); both run in production and need an **image
   scan** (`trivy image <img>` / grype). Run the image scan too, and report all three surfaces.
   Remediate **by source**: lockfile → update the package; OS/runtime-bundled → **bump/pin the
   base image, no package to update** (hand that to `wai-implementation`; the CI gate lives in
   `wai-cicd`). A real `undici` CVE reported 0 under `pnpm audit` and was caught only by the
   image scan.

4. **Adversarial dimension walk** — Go through the attack classes below; cite the **catalog ID**
   in every finding (read the playbook for the per-class red flags and probes). Evaluate what the
   surface actually exposes — don't demand completeness everywhere.
   - **AuthN & session** (`SEC-1`/`SEC-10`) — token issuance/rotation/revocation, expiry,
     logout kills the session, no long-lived non-revocable bearer.
   - **AuthZ & object-level access / IDOR** (`SEC-8`) — every object access checks
     ownership **in the query** (WHERE user/tenant), not just at the route; no cross-tenant reach.
   - **Secrets & keys** (`SEC-3`) — none in code/config/logs/history/binary; rotation possible;
     provider keys server-side only (`CLIENT-1`).
   - **Injection** (`SEC-7`/`SEC-4`/`AI-3`) — SQL/command/template injection; **prompt injection**
     from uploaded/user content overriding system instructions; model output rendered safely.
   - **SSRF & outbound safety** (`SEC-11`) — user-influenced fetches constrained; no
     internal-network / cloud-metadata reachability; size/type/timeout limits.
   - **Rate limiting & abuse** (`SEC-9`/`AI-9`) — throttling on auth and expensive/AI endpoints,
     cost caps tied to attestation, brute-force/enumeration defense.
   - **Supply chain & CVEs** (`SEC-5`) — known-vuln dependencies, unpinned/typosquat
     risk, CVE scan present and acted on.
   - **Crypto & transport** (`SEC-6`) — TLS in transit incl. **to the database**, sensitive data
     at rest, no home-grown crypto.
   - **Client attestation & binary** (`SEC-2`/`CLIENT-1`/`CLIENT-2`) — protected/expensive calls
     carry App Attest / Play Integrity; no secret in the binary/bundle.
   - **Token-economy fraud** (`SEC-13`/`PAY-*`) — receipt/webhook signatures verified, replay/
     duplicate-credit impossible, refund/revocation clawed back, no client-trusted balance.
   - **PII exposure** (`GDPR-5`/`OBS-1`) — no plaintext PII/user content in logs, traces, error
     messages or third-party sinks.

   **Give every finding a report-local handle.** Tag each finding `F1, F2, …` in find-order —
   the linking primitive step 5 chains against, deliberately **ephemeral and report-local**:
   namespace-distinct from a catalog ID (which names a *dimension*, not a finding), and **never
   cited across reports or repos** (ADR-0003 — last quarter's `F3` is a different finding). The
   catalog ID still rides on every finding as its dimension; `F<n>` is only the local address.

5. **Attack-path / kill-chain synthesis** — Compose the findings. Walk the attack-surface map
   and, for each objective an attacker wants (another tenant's data, the token ledger, RCE, mass
   PII), ask **which chain of findings reaches it**: entry → pivot → objective, each hop crossing
   a trust boundary from the surface map. Write each chain as an ordered list of links where
   **every link cites its finding handle (`F<n>`), the boundary it crosses, and the reachability
   reason** — the load-bearing part, not the link count. Then:
   - **Give the whole chain a severity** by whole-path exploitability × impact. It can **elevate**
     above the max of its links (composition) or **drop** below it (an unreachable link, or a
     control the path must pass). Justify the delta in one line.
   - **Mark the cheapest link to break** (`⛓✂`) — the single hop whose fix is smallest yet severs
     the whole chain. Remediation leads with it.
   - **Account for every Blocker/Major finding**: it appears in ≥1 chain, or it is listed
     **standalone** — a real finding that, on today's surface, reaches no objective (still a
     hardening item, ranked below the reaching chains).
   Inferring chains from finding *text* would manufacture false paths, so the discipline is
   inverted: each link **emits** its evidence and `scripts/attack-path-lint.sh` form-checks it
   (see References). This stage is **report-only and reasoned, never executed** — a probe that
   actually walks a chain belongs only against a **disposable/staging environment with synthetic
   data** and is named solely as a **bounded, human-activated future opt-in** (the excluded
   domains still gate it; nothing runs against production or real user data). Method + worked
   example: `references/security-audit-playbook.md §4`.

6. **Rank & trend** — Rank the **attack paths first, then the standalone findings** — the chain
   is the unit that decides posture. Assign each finding *and each chain* a severity (below)
   **and a trend tag** vs the last audit (`new` / `worsening` / `stable` / `improving`; a chain
   is `new` if any link is new). A `new`/`worsening` reaching chain outranks a `stable` hardening
   gap, and the **worst attack path drives the Posture line**.

7. **Remediation proposals** — Order proposals by chain rank, and for each chain **lead with the
   cheapest link to break** (`⛓✂` from step 5). Each fix is concrete and handed to
   `wai-implementation` (or `wai-cicd` for a CVE-scan gate, `wai-testing` for a security
   regression test). Group defense-in-depth hardening separately from the chains and standalone
   exploitable bugs.

8. **Check the repo's visibility BEFORE you write anything down.**
   `gh repo view --json visibility`. This decides where the detail of an unfixed vulnerability
   may live — resolve it first, not at filing time. **A PR diff is as public as an issue**:
   world-readable, emailed to every watcher, permanent. Redacting the issue while committing the
   exploit to `docs/` in the same run protects nothing.

   - **Public repo** → **do not commit the exploitable detail.** The committed report is
     **class-level only**: severity, catalog ID, affected capability, impact — the *class*, never
     the *weapon* (no reproduction, no payload, no exact bypass, no vulnerable line). The detail
     goes to the human directly, in the run output, plus whichever private channel they name; the
     right home for it on GitHub is a **draft security advisory** (Security tab, or
     `gh api --method POST /repos/{owner}/{repo}/security-advisories`), which is private until
     published — **not** `gh issue create`, which is public by definition.
   - **Private repo** → the full detail may be committed in the report as usual. Everyone who can
     read the report can already read the code.

9. **Write the dated report, commit on a branch, hand off** — Persist to
   `docs/architecture/security-audits/<YYYY-MM-DD>.md` (create the folder if needed) using the
   output format below, at the redaction level step 8 established — **never a live secret or a
   working exploit**, in any repo. Per the git protocol, commit the report on an
   `agent/<handle>/chore-security-audit-<YYYY-MM-DD>` branch and open a PR; never touch `main`.
   **Blocker/Major findings are the human's decision point** (present with a recommendation and
   wait). Then the **landing rule** applies (`issues-protocol.md` §*Where a finding lands* and
   §*Security findings*): a finding that is neither fixed nor deliberately rejected is **filed**
   as a `security`-labelled issue — severity, catalog ID, affected capability and a pointer, at
   the same redaction level as the report. "Don't publish the exploit" limits what the issue
   *says*; it never means the finding goes untracked. **Read existing issues first**
   (`gh issue list --label security`). Without `gh`, list the would-be issues with their
   commands.
   (The run-log row for this skill is written by `dep-cve-scan.sh` itself — do not log it again.)
   **Then derive the closing state:** run `sh ../wai/scripts/open-items.sh` (from this skill's
   directory), paste its output verbatim beneath the ▶ Recommended next block, then give your
   recommendation — in that order: the script derives (exit 0 = emitted; exit 2 = nothing
   derivable — then say `not checked` yourself), the model recommends.

## Severity & trend (security-framed)

- **Blocker** — exploitable now, high impact: auth bypass (`SEC-1`), IDOR to another tenant's
  data (`SEC-8`), a secret committed in the repo/history (`SEC-3`), RCE/SQL injection (`SEC-4`),
  an unauthenticated expensive endpoint enabling cost-drain (`SEC-9`), a purchase path that
  credits on client trust (`SEC-13`).
- **Major** — exploitable under conditions, or a missing defense on a money/auth/PII path:
  no rate limit on an expensive endpoint (`SEC-9`), a known-CVE dependency in the runtime
  (`SEC-11`), prompt injection with a real sink (`SEC-4`), missing attestation on a protected
  call (`CLIENT-2`), plaintext PII in logs (`GDPR-5`).
- **Minor** — hardening / defense-in-depth: missing security header, over-broad token scope,
  no CVE-scan gate (advisory), verbose error leakage without direct impact.
- **Nit** — cosmetic/optional.
- **Trend:** `new` | `worsening` | `stable` | `improving` — versus the previous security audit.
- **Chain severity** — an attack path's severity is **whole-path** exploitability × impact and
  can **exceed the maximum severity of its links**: findings each Minor alone can compose into a
  Blocker chain. Conversely, an alarming-looking finding that chains out to no objective is a
  **standalone hardening item**, not a Blocker. Rank the chain, then its links.

Assign honestly. A hardened codebase gets a short, clear "posture sound" — don't inflate.

## Output format

Use exactly this structure for `docs/architecture/security-audits/<YYYY-MM-DD>.md`:

```
## Security Audit: [repo] · [YYYY-MM-DD]

**Scope:** [since <last audit date> / last N merges · surfaces covered · triggers]
**Posture:** [Sound | Hardening needed | At risk | Critical exposure] (driven by the worst attack path)
**Trend vs last audit:** [improving | stable | worsening — one line on what moved]

### Attack-surface snapshot
- Endpoints: [N · M unauthenticated · K expensive/AI]
- Ingest/upload: [paths] · Webhooks: [payment/RTDN/provider]
- Outbound fetches (user-influenced): [N] · Secret/PII flows: [where]

### Tooling snapshot
- Secrets (gitleaks): [N] · SAST (semgrep): [N by severity] · Dep CVEs: [crit/high/med **per
  ecosystem, or `not measured` — never a bare 0 for a scan that did not run**; from
  `dep-cve-scan.sh`]

### Findings
[Each finding carries a report-local handle [F<n>] in find-order — the address the attack paths
 below chain against. Ephemeral; never cited across reports/repos (ADR-0003). The catalog ID names
 the dimension; F<n> names this finding.]
#### Blocker
- [F<n>] · [File/path] · [Catalog ID] · [Trend] — [Attack] → [Impact] → [Fix]  (redacted)
#### Major
- ...
#### Minor
- ...
#### Nits
- ...

### Attack paths (kill-chains)
[Omit this whole section when no chain reaches an objective — and say so in Posture ("no composed
 path reaches an objective"). Reaching chains first (ranked), then the Standalone line. Match
 chains across audits by objective + boundaries crossed, not by handle (handles are report-local).]
- AP-1 · [severity] · [Trend] — [objective reached]
  1. [F<a>] [entry] — crosses [trust boundary] · reachable: [reason]
  2. [F<b>] [pivot] — crosses [trust boundary] · reachable: [reason]   ⛓✂ cheapest to break
  3. [F<c>] [objective] — [impact]
  ↑ chain severity above its links: [why composition elevates it]
- AP-2 · ...
- Standalone (reach no objective yet): [F<x>], [F<y>] — hardening items, ranked below the chains.

### Defense-in-depth (hardening, lower urgency)
- [Catalog ID] — [gap → recommended hardening]

### Security catalog proposals
- [New SEC-* / revised wording · why the current rule misses this class]

### Positives — what's holding up
- [Named strong controls, with the ID they satisfy]

### ▶ Recommended next (ranked actions)
1. [Break the top chain — remediate the cheapest link (⛓✂) of the worst-ranked attack path; with no
   reaching chain, the highest-exploitability standalone fix. Name the skill that takes it:
   wai-implementation for a code fix, wai-cicd for a CVE-scan gate, wai-testing for a
   security regression test, wai-init if a SEC-* catalog change is warranted. Live-secret
   exposure → rotate now.]
2. ...
```

Omit empty sections. If the posture is sound, say so in `Posture` and keep it brief.

## References

- `references/security-audit-playbook.md` — per-stack security tooling commands (gitleaks,
  semgrep, osv-scanner, trivy, audit), the attack-surface mapping method, the per-class threat
  checklist with probes/red flags, and the safe-testing/redaction rules. **§4** is the
  attack-path / kill-chain synthesis method (with a worked emergent-severity example and the
  cheapest-break heuristic); **§5** is the trend method, which also diffs the **attack-path set**
  run-to-run.
- `scripts/attack-path-lint.sh` — lints the **### Attack paths** section for form and internal
  consistency: every cited `F<n>` resolves to a defined finding, each `AP-<n>` is well-formed
  (severity, ≥1 link, an objective, a cheapest-break marker), and every Blocker/Major finding is
  either chained or on the Standalone line. It checks **form/consistency, not truth** — a green
  lint is not a validated kill-chain, and it prints so on every run. Obey the exit code:
  `exit 0` = well-formed — or there is no Attack paths section *and* no Blocker/Major finding to
  account for · `exit 1` = a form/linkage check failed and each reason names its repair — fix
  the report before it is handed over · `exit 2` = the report could not be read (**UNKNOWN**) —
  nothing was checked, so do not call the synthesis linted.
- `docs/architecture/quality-attributes.md` — the live catalog; cite its `SEC-*`/`GDPR-*`/`PAY-*`
  IDs. If absent, note once and use the dimensions above (run `wai-init` to generate it).
- `references/contract-protocol.md` (in the `wai` skill) — the token/billing contract is a
  human-gated money surface; basis for the `SEC-13`/`PAY-*` fraud lens.

## Git & PR

**A PR diff is world-readable in a public repo.** Resolve visibility *first* (process step 8): in
a public repo the committed report is **class-level only**, and the exploitable detail goes to the
human and to a **private** draft advisory — never into a commit. **Never** publish a live secret
or a working exploit through git or the tracker.

**The authority is `references/agent-git-protocol.md` (in the `wai` skill).** Specific to *this*
skill: commit the **redacted** dated report on an
`agent/<handle>/chore-security-audit-<YYYY-MM-DD>` branch and open a PR. **Never commit, push or
merge to `main`.** Findings land per `issues-protocol.md` §*Where a finding lands* and
§*Security findings* — filed as `security`-labelled issues, redacted, deduped. No git or no `gh` →
write the report to the working tree and list the would-be issues with their commands.
(The Stance section above is also this skill's principles list.)

## Related Skills

This skill is the **periodic adversarial security stage**, the security counterpart to the
structural `wai-architecture-audit`:
- **wai-architecture-audit** — structural health; tenant isolation and DB-connection security
  appear in both — structure there, exploitability here.
- **wai-pr-review** / the **`/security-review`** command — per-diff security *before merge*; this
  skill audits the *whole system periodically*.
- **wai-implementation** — takes over fixing the findings; **wai-cicd** wires a
  CVE-scan/secret-scan merge gate; **wai-testing** adds security regression tests.
- **wai-init** — when a finding means the `SEC-*` catalog itself must change.
- **wai** — the suite router/overview.
- Shared source of truth: `docs/architecture/quality-attributes.md` (`SEC-*`/`GDPR-*`/`PAY-*`).
