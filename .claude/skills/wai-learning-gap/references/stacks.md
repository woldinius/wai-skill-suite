# Stack detection — manifests by platform, and what to do when none match

Read this when creating the ledger's **Stack profile** (SKILL.md, *Ground rules*). It exists so the
detection step is concrete without pretending the list is complete.

> **The list is a shortcut, not the contract.** It covers the common ground so the frequent cases
> need no interview. It will never be exhaustive, and a stack it does not name is a **normal case,
> not a failure** — see *When nothing matches*, which is the part that actually makes this skill
> work on any repo.

## The manifests

**Web** — `package.json` (+ `tsconfig.json`, `deno.json`, `bun.lockb`); a framework config next to
it (`next.config.*`, `vite.config.*`, `angular.json`, `svelte.config.*`) names the idiom set more
precisely than the runtime does.

**Desktop** — usually a web or native manifest **plus a shell**, and the shell is the thing to
notice: `package.json` with an `electron` dependency, or `src-tauri/tauri.conf.json` beside a
`Cargo.toml` (Tauri), `*.csproj`/`*.sln` (.NET / WPF / WinUI), `pubspec.yaml` (Flutter desktop),
`CMakeLists.txt`/`*.pro` (Qt), `Package.swift`/`*.xcodeproj` for a native macOS app. A desktop app
that is Electron is **not** "a web app": packaging, auto-update and OS integration are its own
idioms, and they are where the interesting gaps live.

**iOS / macOS** — `Package.swift`, `*.xcodeproj`, `*.xcworkspace`, `Podfile`.

**Android** — `build.gradle` / `build.gradle.kts`, `settings.gradle*`, `gradle/libs.versions.toml`.

**Server & tooling** — `go.mod` · `Cargo.toml` · `pyproject.toml` (or `requirements.txt`,
`pytest.ini`) · `pom.xml` · `composer.json` · `Gemfile` · `mix.exs` · `*.csproj` · `Makefile`.

**Monorepos** — `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, a Cargo or Go
workspace. Detect the **package the human is working in**, not the repo root: a gap belongs to the
stack of the file it is planted in.

## When nothing matches

This is the important half. Do **not** guess, and do not skip the stack profile:

1. **Say what you did find** — the file names, verbatim. "I see `deps.edn` and `bb.edn`, which I
   don't recognise" is useful; "I could not detect the stack" is not.
2. **Ask two questions**, once: *what is this stack?* and *how does the project build and test?*
3. **Record both in the ledger** — the technology under *Stack profile*, the command in *Project
   notes*. Every later gap needs that command: `verify-gap-breaks.sh` deliberately **refuses to
   guess it** and returns UNKNOWN without one, because a gap that cannot be shown to break is not a
   gap.
4. From then on the unknown stack behaves like any other: topics, boxes, axes and gap forms are all
   stack-independent. **Only the detection shortcut was missing, never the capability.**

If a manifest turns up repeatedly that this file does not name, that is worth adding here — but the
fallback above is what makes the skill correct in the meantime, and it is why the list never has to
be finished.

## What detection is *for*

Two things only: naming the technologies as **topics** for the Leitner boxes, and finding the
**build/test command**. It is not a project audit — the architecture and domain axes come from the
human's answers and the code they touch, not from a manifest.
