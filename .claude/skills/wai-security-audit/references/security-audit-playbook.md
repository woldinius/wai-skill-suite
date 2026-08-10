# Security Audit Playbook — tooling, method & threat checklist

> Reference for `wai-security-audit`. The SKILL describes *what* to audit and the output
> format; this file gives the *how* — the tooling commands per stack, the attack-surface mapping
> method, the per-class threat checklist with probes and red flags, and the safe-testing/
> redaction rules. Adapt to the repo you are actually in; run tools ad-hoc (you do **not** need
> them wired into CI to use them once).

---

## 0. Safe-testing & redaction rules (read first)

- **Never run a real exploit against production or real user data.** Prove exploitability by
  reading code + a *local/dry* probe, or a request against a disposable/test environment — not
  by attacking the live system.
- **Never publish a live secret or a working exploit payload.** Reports and issues are often
  world-readable (public repo). Redact keys (`sk-…✂`), truncate payloads, describe the class not
  the weapon. A committed secret → tell the human to **rotate + purge history** immediately;
  don't paste it.
- **Prefer read-only/ad-hoc invocation** (`npx` — or the runner matching the lockfile: `pnpm dlx`,
  `yarn dlx`; `uvx`, `docker run`) so the audit
  adds nothing permanent to the repo.

---

## 1. Tooling pass — commands per stack

### Secrets (all stacks) — scan the working tree AND history
| Goal | Tool | Command |
| --- | --- | --- |
| Committed secrets (history) | gitleaks | `docker run --rm -v "$PWD:/p" zricethezav/gitleaks detect -s /p --redact` |
| Committed secrets (dir) | trufflehog | `docker run --rm -v "$PWD:/p" trufflesecurity/trufflehog filesystem /p --only-verified` |
| Quick grep | ripgrep | `rg -n -i "api[_-]?key|secret|bearer |private_key|BEGIN .*PRIVATE KEY"` |

### TypeScript / JavaScript (npm/pnpm/yarn; single package or monorepo)
| Goal | Tool | Ad-hoc command |
| --- | --- | --- |
| SAST | semgrep | `docker run --rm -v "$PWD:/src" returntocorp/semgrep semgrep --config p/typescript --config p/owasp-top-ten --config p/nodejs` |
| Dependency CVEs | osv-scanner | `docker run --rm -v "$PWD:/src" ghcr.io/google/osv-scanner scan -r /src` |
| Dependency CVEs (JS/TS) | the package manager's audit | `npm audit --audit-level=high` — or `pnpm audit` / `yarn npm audit`, matching the lockfile |
| Image CVEs | trivy | `trivy image <ghcr-image>:<tag>` (or `trivy fs .`) |
| Insecure regex / eval / etc. | semgrep | included in `p/javascript` ruleset |

### Python
| Goal | Tool | Command |
| --- | --- | --- |
| SAST | bandit / semgrep | `uvx bandit -r src/` · `semgrep --config p/python` |
| Dependency CVEs | pip-audit / osv | `uvx pip-audit` · `osv-scanner scan -r .` |

### Swift / iOS · Kotlin / Android (client repos)
| Goal | Tool | Command |
| --- | --- | --- |
| Secrets in binary/bundle | grep/strings | `strings <app-binary> \| rg -i "sk-|api[_-]?key|bearer"` |
| SAST (Swift) | semgrep | `semgrep --config p/swift` |
| SAST (Kotlin/Android) | semgrep / MobSF | `semgrep --config p/kotlin` · MobSF for a deeper mobile scan |
| Dependency CVEs (Android) | OWASP dep-check | `./gradlew dependencyCheckAnalyze` |
| Manifest/exported components | Android lint | `./gradlew lint` (exported activities/receivers, cleartext traffic) |

For **dependency CVEs specifically, prefer the deterministic wrapper** over eyeballing any single
command above: `sh scripts/dep-cve-scan.sh` walks every ecosystem present, runs its scanner if
installed, and emits `ran=true`/`not_measured` per ecosystem with an `exit 2` when any scan did not
run — so an un-run scan can never read as a clean 0. The commands in the tables are what it invokes
under the hood, and what to run by hand to dig into a specific finding. If it reports a gap, install
the cross-ecosystem scanner once — `brew install osv-scanner` (macOS) · `go install
github.com/google/osv-scanner/cmd/osv-scanner@latest` · or the `ghcr.io/google/osv-scanner` image
above (no install) — and re-run.

Tools find the **mechanical** layer (secrets, known CVEs, obvious injection sinks). The
**logic** layer (IDOR, broken authZ, fraud, prompt injection) needs the dimension walk below —
no scanner finds "this endpoint trusts the client's tenant id".

---

## 2. Attack-surface mapping method

Before hunting, chart the surface so the walk is exhaustive, not random:

1. **Entry points** — enumerate every route (grep the router/controllers). For each: auth
   required? which role/scope? does it cost tokens/AI? mutating? Mark the **unauthenticated** and
   **expensive** ones — that intersection is prime attack surface.
2. **Ingest** — uploads, imports, webhooks (payment/RTDN/provider callbacks), any parser of
   external bytes.
3. **Outbound** — every server-side fetch whose URL/host is influenced by user input (SSRF).
4. **Trust boundaries** — client↔API, API↔DB, API↔model provider, API↔store/billing. A boundary
   is where a check must exist; a missing check at a boundary is the finding.
5. **Sensitive data flows** — where secrets, PII and token balances are read/written/logged/sent.

Persist this as the report's *attack-surface snapshot*; it is the security equivalent of the
architecture audit's capability map, and next audit diffs against it.

---

## 3. Per-class threat checklist (probes & red flags)

Cite the catalog ID in every finding. Probe = how to check; Red flag = the finding.

- **AuthN & session** (`SEC-1`/`SEC-10`) — *Probe:* how are tokens issued/verified? expiry,
  refresh rotation, revocation on logout/compromise? *Red flag:* long-lived non-revocable bearer;
  no session kill; JWT without expiry/`aud`/`iss` checks.
- **AuthZ / IDOR / tenant isolation** (`SEC-8`) — *Probe:* pick object-fetch endpoints
  (`GET /x/:id`); is ownership enforced **in the query** (`WHERE user_id = :me`) or only assumed?
  *Red flag:* an id from the request fetched without an ownership/tenant predicate → cross-tenant
  read/write.
- **Secrets & keys** (`SEC-3`) — *Probe:* gitleaks over history; grep configs/logs; inspect the
  client bundle. *Red flag:* any provider key/token in code/config/log/history/binary.
- **Injection** (`SEC-7`) — *Probe:* raw SQL string-building, shell exec with input, template
  eval. *Red flag:* concatenated SQL/command with user input; unparameterized queries.
- **Prompt injection** (`SEC-4`/`AI-3`) — *Probe:* does user/upload content reach the model in a
  position that can override system instructions? is model output validated before use/render?
  *Red flag:* uploaded text spliced into the system prompt; model output rendered as HTML/executed.
- **SSRF & outbound** (`SEC-11`) — *Probe:* find server-side `fetch`/`http` calls with a
  user-influenced URL. *Red flag:* no allow-list; internal-network / `169.254.169.254` metadata
  reachable; no timeout/size cap.
- **Rate limiting & abuse** (`SEC-9`/`AI-9`) — *Probe:* is there a limiter on auth and on
  expensive/AI endpoints? cost caps? *Red flag:* an unauthenticated or per-token-costly endpoint
  with no throttle → cost-drain, enumeration, credential stuffing.
- **Supply chain & CVEs** (`SEC-5`) — *Probe:* osv-scanner/audit output; lockfile
  pinned? *Red flag:* known critical/high CVE in a runtime dep; unpinned or typosquat-risky deps;
  no CVE gate in CI.
- **Crypto & transport** (`SEC-6`) — *Probe:* TLS everywhere incl. **to the DB**; secrets at
  rest; any custom crypto? *Red flag:* plaintext DB connection; home-grown crypto; sensitive data
  unencrypted at rest.
- **Client attestation & binary** (`SEC-2`/`CLIENT-1`/`CLIENT-2`) — *Probe:* do protected/
  expensive calls require App Attest / Play Integrity? *Red flag:* a protected call accepted
  without attestation; a secret shipped in the binary.
- **Token-economy fraud** (`SEC-13`/`PAY-*`) — *Probe:* are store receipts / webhooks signature-
  verified server-side? can a replay double-credit? refund clawback? *Red flag:* purchase trusted
  from the client; webhook without signature check; no replay/idempotency key on credit.
- **PII exposure** (`GDPR-5`/`OBS-1`) — *Probe:* grep logs/traces/error handlers for user content
  and PII. *Red flag:* plaintext PII or prompt/response content in logs or third-party sinks.

---

## 4. Attack-path / kill-chain synthesis method

The dimension walk (§3) produces a *list*. An attacker does not exploit a list — they compose a
*path*. This section is how you turn findings into ranked end-to-end attack paths. It is the audit's
**join point**: run it only **after** the surface map (§2), the tooling pass (§1) and the whole
dimension walk (§3) have reported, because a chain is built from their combined output. Synthesize
against a half-mapped surface and you will miss the paths that cross the parts you hadn't charted.

**Precondition.** Every finding already carries a **report-local handle** `F<n>` (assigned in
find-order during the dimension walk) and a catalog ID (its dimension). The handle is the linking
primitive here; the catalog ID is not — a chain links *findings*, not dimensions, and handles are
ephemeral and never cross a report boundary (ADR-0003; last quarter's `F3` is a different finding).

**The model — entry → pivot → objective.** For each thing an attacker wants (another tenant's data,
the token ledger / billing path, code execution, mass PII egress), ask which ordered chain of
findings reaches it. Each **link** is one finding and one **hop across a trust boundary** from the
surface map (client→API, API→DB, API→model provider, API→store/billing). A chain is valid only if
every hop is *reachable from the previous one* — the reachability reason is the load-bearing part,
not the link count.

**Evidence rule (why this stays judgment, not a script).** Inferring chains from the *text* of
findings manufactures false paths — the "these three sound related" fallacy. So the discipline is
inverted: **each link must EMIT its evidence** — the finding handle, the boundary crossed, and one
concrete sentence of why the hop is reachable. A chain you cannot write those three things for is a
chain you have not proven. `scripts/attack-path-lint.sh` then checks that this *form* is present and
internally consistent (handles resolve, each chain is well-formed, every Blocker/Major is chained or
standalone) — it validates **form, not truth**, and says so on every run. It cannot tell you a chain
is real; only you can.

**Emergent severity — a worked example.** Three findings, each *Minor* in isolation:
- `F4` — `GET /export/:id` checks route auth but not row ownership (IDOR, `SEC-8`); it returns only
  a non-sensitive display name, so *low impact* alone.
- `F7` — that display name is reflected unescaped into an admin-only log viewer (stored XSS,
  `SEC-7`); the viewer is admin-only, so *low reachability* alone.
- `F9` — the admin session cookie lacks `HttpOnly` (`SEC-10`); a hardening *nit* alone.

Chained: `F4` enumerates other tenants and one sets their display name to an XSS payload → an admin
opens the log viewer and `F7` fires *in an admin context* → `F9` lets the payload lift the admin
session cookie → **full admin takeover**. Three Minors compose into a **Blocker** chain: the
whole-path severity (exploitability × impact) *exceeds the max of its links*. That is emergent
severity, and it is the entire reason synthesis exists. Conversely, a lone finding whose chain
reaches no objective (an SSRF into a network segment with nothing behind it) **drops** to a
standalone hardening item.

**Cheapest link to break (`⛓✂`).** A chain is a conjunction — break **any one** link and the whole
path fails. So remediation does not fix every link; it finds the **cheapest** hop to sever and leads
with it. Heuristic for "cheapest": prefer a one-line, low-behavioral-risk, well-understood fix (add
the ownership predicate to `F4`'s query; set `HttpOnly` on the cookie) over a broad refactor; prefer
the link nearest the entry (kills the path earliest); prefer a fix that also breaks *other* chains
through the same finding. Mark that link `⛓✂` and make it remediation item 1 for the chain.
Defense-in-depth may still fix the other links — but the chain is *defeated* at the cheapest one.

**Standalone accounting.** Every Blocker/Major finding must be *accounted for*: it appears in at
least one chain, or it is listed on the **Standalone** line as a finding that — on today's surface —
reaches no objective. Standalone findings are real and still ranked, but below reaching chains. A
Blocker that is neither chained nor standalone is a gap in the synthesis, not a pass — which is
exactly what `attack-path-lint.sh` checks.

**Report-only boundary.** Everything here is **reasoned from code + tool evidence, never executed.**
You do not walk the chain against the running system; it is proven on paper (reachability reasons),
not by exploitation — the same safe-testing rule as §0.

**Future opt-in — the safe-probe.** A bounded *validation* probe that actually walks a chain has
value, but only under strict conditions, and it is **not** part of this audit today. It is named
here as a future, **human-activated** option: it may run **only** against a disposable/staging
environment seeded with **synthetic** data — never production, never real user data; the excluded
domains still gate it; and it is armed explicitly by a human, never by the skill. Until that exists,
a chain's status is "reasoned", and the report says so.

---

## 5. Trend method

Diff against the most recent `docs/architecture/security-audits/*.md`: count of open findings by
severity, dependency-CVE counts (crit/high), secret hits, and per-class deltas. Tag each finding
`new` / `worsening` / `stable` / `improving`. The persisted history is what turns "are we more or
less exposed than last quarter?" from a guess into an answer. When a `SEC-*` rule itself is the
thing that's missing a class, propose the new ID in the report's **Security catalog proposals**
section — don't silently widen scope.

**Diff the attack-path set, not only the finding list.** Since §4 the audit's ranked unit is the
*chain*, so the trend has to track chains too — and a chain can move even when no single finding
does. Compare this run's **### Attack paths** against the previous report's:
- **A new chain** whose individual findings all existed last time but were not composed → the
  posture *worsened* even though the finding list is unchanged. That is exactly the composition
  synthesis exists to catch; tag the chain `new`.
- **A broken chain** — a link was remediated (its `⛓✂` fix landed) so the path no longer reaches
  its objective → `improving`, even if the other links (now standalone) remain open.
- **A re-formed chain** — a previously broken path that a new finding re-connects → `worsening`.
- **Standalone ⇄ chained transitions** — a finding that was standalone last quarter and now
  completes a chain is a worsening signal worth calling out.
Because `F<n>` handles are report-local and do not carry across reports, match chains by their
**objective and boundary crossings**, not by last quarter's handles.
