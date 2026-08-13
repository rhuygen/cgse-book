# Chapter 3 Repository Tour

*Where to find things, and why they live there.*

This chapter is the map. By the end of it you should be able to take any module name mentioned later in the book — or any module name you stumble on while reading CGSE source — and know which package it lives in and why it's there, without grepping the whole tree blind. It closes out Part I: Chapter 4 onward assumes you can navigate the workspace and starts going deep on individual modules.

## 1. The Monorepo Rationale

*Why one `uv` workspace instead of many small repos.*

Revisit, briefly and concretely, the monorepo decision already introduced at the philosophy level in Chapter 1 — this section should ground it in what the workspace layout actually buys day to day: atomic commits across `libs/` and `projects/` when a shared module's contract changes, one CI/test run instead of N, no publish-then-bump-the-pin cycle between `cgse-common` and everything that depends on it. Should explicitly cross-reference Chapter 1's `egse.*` (library) vs `cgse_*` (CLI/distribution) split rather than re-deriving it — this chapter is where that split becomes visible on disk.

## 2. The `uv` Workspace

*How the root `pyproject.toml` wires everything together.*

Walk through the root `pyproject.toml`'s `[tool.uv.workspace]` block: `members = ["libs/cgse-common", "libs/cgse-coordinates", "libs/cgse-core", "libs/cgse-gui", "projects/generic/*", "projects/plato/*", "projects/ariel/*", "projects/ivs/*"]`, and the parallel `[tool.uv.sources]` block that pins each member package as `{ workspace = true }` so `uv sync` resolves siblings from their local path instead of a published index. Cover what `uv sync` and `uv run` actually do across a workspace this shape, the root-level `[project.scripts] cgse = 'cgse_common.cgse:app'` entry point, and the `default-groups = ["dev", "docs"]` setting. Practical note: this is also where a reader would look to answer "is package X part of this workspace at all?"

## 3. The `libs` Directory

*The shared foundation every project depends on.*

Introduce the four `libs/` packages at a glance — `cgse-common`, `cgse-core`, `cgse-coordinates`, `cgse-gui` — and the line drawn between `cgse-common` (zero dependency on any running service — Settings, Setup, env, device I/O primitives) and `cgse-core` (the control-server/proxy/registry machinery that turns those primitives into long-running services). Worth stating explicitly that this book's own Part II/III (`cgse-common`) vs Part II-opening/Part IV (`cgse-core`) split mirrors this exact distinction, so the reader can use "is this a `-common` or `-core` concern?" as a standing orientation question. Note `cgse-coordinates` and `cgse-gui` are deliberately out of scope for this book (see Section 8) but should still be named here so their absence later isn't a surprise.

## 4. The `projects` Directory

*Where hardware drivers and mission-specific code live.*

Cover the `projects/generic/*` vs `projects/{plato,ariel,ivs}/*` split: generic packages are one per device or instrument, usable by any mission (`symetrie-hexapod`, `keithley-tempcontrol`, `lakeshore-tempcontrol`, `kikusui-power-supply`, `digilent`, `aim-tti-awg`, plus the `cgse-tools` utility package); mission packages are specific to one campaign or facility (`plato-fits`, `plato-hdf5`, `plato-spw`; `ariel-facility`, `ariel-tcu`; `ivs/tvac`). Explain what "generic" buys in practice — a test setup installs only the device packages it actually has hardware for, and a generic driver is reusable across missions without modification. State plainly that these packages are out of scope for deep chapters in this book (Section 8), so this section is inventory, not a preview of content to come.

## 5. Anatomy of a Package

*Worked example: `projects/generic/symetrie-hexapod`.*

Use one real package as a concrete walkthrough of the shape every project follows: a per-package `pyproject.toml` (its own `[project.scripts]`, its own `[tool.uv.sources]` entry back in the root), a `settings.yaml`, and a `src/` tree split across two things that look similar but aren't — `src/egse/hexapod/...` (driver code contributed into the *shared* `egse` namespace) versus `src/symetrie_hexapod/...` (the package's own distribution-local code: `cgse_explore.py`, `cgse_services.py`). The distinction between those two halves is the payoff of this section and feeds directly into Section 6.

## 6. Naming Conventions and Navigation

*Given a module name, how to find it without guessing.*

Make the `egse.*` vs `cgse_*` convention from Chapter 1 concrete and actionable: `egse.*` is a namespace package that many different distributions (`cgse-common`, `cgse-core`, and every device/mission project) all contribute modules into, so `egse.foo` importing successfully doesn't tell you which package installed it — only this chapter's map does. `cgse_*` (`cgse_common`, `cgse_core`, `symetrie_hexapod`, ...) is always one distribution's own private package, never shared. Should give the reader a concrete recipe for "I see `egse.something` mentioned — where is it really?" (e.g. `grep -rl` across `libs/*/src/egse` and `projects/*/*/src/egse`, or check which package's `pyproject.toml` lists it). This is also the section to explain how this book's own "Modules: `egse/x.py`" chapter-index lines map back to a real path.

This section should first establish the premise the governance point below depends on: CGSE is deliberately designed so a new device driver doesn't require merging into the `cgse` monorepo at all. That's the actual point of the entry-point discovery mechanism (Section 7) — `cgse-core` finds device packages through `cgse.*` entry points, not hard imports, so a contributor can write, package, and register a driver entirely from their own separate repo and have it work alongside monorepo-native packages. Once that's on the table, the naming convention split makes sense as a consequence of it, not an arbitrary rule.

Inside the monorepo, contributing driver code into the shared `egse.*` namespace works because everything lives in one repo — one CI run, one set of reviewers, so a name collision between two packages' `egse/` trees gets caught before it merges. But `egse` is a PEP 420 implicit namespace package: at install time, Python silently merges whatever `egse/` directories show up across every installed distribution, with no built-in check for collisions. A contributor maintaining their own device-driver repo outside the monorepo isn't part of that CI/review process — if their package also drops files under `egse.`, it could silently shadow or overwrite a module from the monorepo (or from someone else's external package), with nothing catching it. So the rule is scoped by where the package is developed, not by what kind of package it is: inside the monorepo, use `egse.*` for driver code as usual, the same way every package in `libs/` and `projects/` does today; outside it, don't — keep everything under your own distribution's package name instead, and rely on entry points (Section 7), not the shared namespace, to plug into CGSE.

## 7. Package Discovery via Entry Points

*How optional packages plug into `cgse-core` without being hard-imported.*

Cover the problem entry points solve — `cgse-core` shouldn't need a hard import of `symetrie-hexapod` to know it exists — and walk through the concrete entry-point groups actually defined in the workspace: `cgse.version`, `cgse.settings` (the reader has already met this one, informally, in Chapter 4's Settings plugin model — cross-reference forward/back explicitly rather than re-explaining), `cgse.service.core_command`, `cgse.explore`, `cgse.resource`, `cgse.extension.setup_provider`, `cgse.process_management.core_services`. Note how a leaf package like `symetrie-hexapod` participates via its own `cgse_explore.py` / `cgse_services.py` and `[project.entry-points.*]` declarations. Keep this at "what problem this solves and where the wiring lives" — the actual discovery mechanism (`egse/plugin.py`) gets its own full treatment later in Part III and shouldn't be duplicated here.

## 8. Scope of This Book

*What's covered in depth, what's deliberately out.*

Close with an explicit, honest scoping statement: this book covers `cgse-common` (Part II/III) and `cgse-core` (Part II's opening chapters plus all of Part IV) in depth; `cgse-coordinates`, `cgse-gui`, the generic device-driver projects, and the mission-specific projects are named and located (Sections 3-4) but not drafted as standalone chapters, at least not in this pass. Point the reader at the chapter index for the current, authoritative inventory rather than duplicating it here, since that list will keep changing as later passes add coverage.

TBW.
