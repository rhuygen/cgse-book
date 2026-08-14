# Chapter 3 Repository Tour

*Where to find things, and why they live there.*

This chapter is the map. By the end of it you should be able to take any module name mentioned later in the book — or any module name you stumble on while reading CGSE source code — and know which package it lives in and why it's there, without *grepping* the whole tree blind. This chapter closes out Part I. Chapter 4 onward assumes you can navigate the workspace and starts going deep on individual modules.

## 1. The Monorepo Rationale

*Why one `uv` workspace instead of many small repos.*

CGSE ships as a single repository, `IvS-KULeuven/cgse`, containing every library, every device driver, and every mission-specific package the framework has. That is a deliberate choice, not an accident of how the project happened to grow.  The rationale behind using a monorepo with distinct packages is that it ensures the source code remains synchronized and simplifies the process of making changes across different packages.

The clearest evidence of the choice is versioning: every package in the workspace — `cgse-common`, `cgse-core`, `symetrie-hexapod`, `plato-fits`, all of them — carries the exact same version number, currently `0.25.11`. A root-level script, `bump.py`, bumps every `pyproject.toml` in the workspace together in one commit; there is no per-package release cycle. That's only sensible when working within a monorepo. In a typical multi-repo setup, each downstream package pins a specific version of `cgse-common` in its own `pyproject.toml`, and that pin only moves when someone in that package's own repo decides to bump it — so `cgse-common` can ship a breaking change while a downstream package keeps running against the old, now-incompatible version indefinitely, with no CI anywhere failing to flag it. Lockstep versioning rules that out: every downstream package sits in the same repo, is exercised by the same CI run, and moves forward in the same commit or not at all. A change to a shared module's contract and the fix it forces in a downstream device driver land together, reviewed together, tested together, instead of one landing today and the other landing three weeks later when someone finally gets around to bumping a version pin.

This is also where Chapter 1's `egse.*` (library code) vs `cgse_*` (CLI/distribution) namespace split first becomes visible on disk rather than just as a principle: `libs/` and `projects/` are full of packages that each contain both an `egse/` tree and a `cgse_*`-or-similar tree side by side (Section 5 walks one in full). The monorepo is what makes that split practical — every package can safely assume the same `egse` namespace convention is in force everywhere else in the workspace, because everywhere else in the workspace is one `git clone` away.

The trade-off is dependency footprint at development time: `uv sync` at the root resolves and locks the *entire* workspace's dependencies into one `uv.lock`, even though any single deployed instrument PC only ever installs the one or two packages it actually needs (Section 2). That cost is paid once, by whoever works on the monorepo itself; it is not paid by a test setup that might only install `cgse-core` and `symetrie-hexapod`.

## 2. The `uv` Workspace

*How the root `pyproject.toml` wires everything together.*

How the workspace is wired together lives in the root `pyproject.toml`, in two linked tables:

```toml
[tool.uv.workspace]
members = [
    "libs/cgse-common",
    "libs/cgse-coordinates",
    "libs/cgse-core",
    "libs/cgse-gui",
    "projects/generic/*",
    "projects/plato/*",
    "projects/ariel/*",
    "projects/ivs/*",
]
exclude = ["docs/*"]

[tool.uv.sources]
cgse-common = { workspace = true }
cgse-core = { workspace = true }
cgse-coordinates = { workspace = true }
cgse-gui = { workspace = true }
cgse-tools = { workspace = true }
plato-spw = { workspace = true }
keithley-tempcontrol = { workspace = true }
lakeshore-tempcontrol = { workspace = true }
symetrie-hexapod = { workspace = true }
```

`[tool.uv.workspace].members` is the authoritative list of what counts as "in the workspace" — the four `libs/` packages are listed explicitly, while every `projects/{generic,plato,ariel,ivs}/*` glob picks up whatever package directories exist underneath. If a reader wants to know "is package X actually part of this workspace, or just sitting in the tree unused?", this table is the place to check.

`[tool.uv.sources]` isn't read by any CGSE code — it's `uv` itself that consumes it, when resolving where a declared dependency name should come from. Per `uv`'s workspace docs, sources declared in the *root* `pyproject.toml` are inherited as the default for every workspace member; a member can override a specific entry with its own `[tool.uv.sources]`, though nothing in this workspace actually does — the three member-level tables that exist (`cgse-core`, `cgse-coordinates`, `symetrie-hexapod`) all just restate what root already provides. `{ workspace = true }` tells `uv` to resolve that name from its local path in the workspace instead of fetching a published version from PyPI.

The table in the example isn't a complete list of workspace members (there are 17; only 9 appear), nor a strictly minimal one: a name needs an entry only if something in the workspace declares it as a dependency, which accounts for `cgse-common`, `cgse-core`, `cgse-gui`, `cgse-coordinates`, `cgse-tools`, and `plato-spw` — but `keithley-tempcontrol`, `lakeshore-tempcontrol`, and `symetrie-hexapod` are also listed despite nothing in the workspace depending on them, and there's no evident reason for those three being there beyond nobody having cleaned them up (Pitfalls appendix, P-011).

`uv sync` (and `uv run`, which syncs implicitly) resolves the *whole* workspace against one shared `uv.lock` at the root — every package's dependency graph is solved together, so two packages can never end up depending on incompatible versions of a third shared dependency. `default-groups = ["dev", "docs"]` means a plain `uv sync` also pulls in development and documentation tooling by default, on top of whatever each package's own runtime dependencies require.

One entry point deserves a mention here even though it belongs to `cgse-common`: the root-level `[project.scripts] cgse = 'cgse_common.cgse:app'` in `libs/cgse-common/pyproject.toml` is what installs the `cgse` command every reader will actually type — `cgse version`, `cgse core start`, and so on. It is the single user-facing entry point that the entry-point discovery mechanism (Section 7) assembles dynamically out of whatever packages happen to be installed.

## 3. The `libs` Directory

*The shared foundation every project depends on.*

`libs/` holds four packages, and every one of them is meant to be a dependency for other packages, never the other way around:

| Package | What it provides |
| ---------------- | ----------------------------------------------------------------------- |
| `cgse-common` | `Settings`, `Setup`, `env`, device I/O primitives, plugin/entry-point machinery — zero dependency on any running service |
| `cgse-core` | The control-server/proxy/registry machinery that turns `cgse-common`'s primitives into long-running, network-reachable services |
| `cgse-coordinates` | Coordinate systems and reference-frame transformations |
| `cgse-gui` | Small, generic GUI building blocks shared across device-specific GUIs |

The `cgse-common` / `cgse-core` line is the one worth internalizing early, because this book's own Part structure mirrors it exactly: Part II (opening chapters) and Part III cover `cgse-common` — configuration, environment, device primitives, everything that has *no* dependency on a running service — while Part II's later chapters and all of Part IV cover `cgse-core` — the client/server foundation and every deployed service built on it. "Is this a `-common` concern or a `-core` concern?" is a genuinely useful standing question to ask about any module you encounter later, not just a book-organization detail: it tracks a real architectural boundary in the code.

`cgse-coordinates` and `cgse-gui` are named here for completeness — a reader will see them imported and should know where they live — but neither gets a dedicated chapter in this pass (Section 8).

## 4. The `projects` Directory

*Where hardware drivers and mission-specific code live.*

`projects/` splits into two kinds of subdirectory, and the split is the point:

- **`projects/generic/*`** — one package per device or instrument, written to be usable by *any* mission or test setup, not tied to a particular spacecraft or facility: `symetrie-hexapod` (PUNA/ZONDA/JORAN positioning hexapods), `keithley-tempcontrol`, `lakeshore-tempcontrol`, `kikusui-power-supply`, `digilent`, `aim-tti-awg`, plus `cgse-tools`, a utility package rather than a device driver.
- **`projects/plato/*`, `projects/ariel/*`, `projects/ivs/*`** — packages specific to one mission or facility: `plato-fits`, `plato-hdf5`, `plato-spw` for PLATO; `ariel-facility`, `ariel-tcu` for ARIEL; `tvac` for IvS's own thermal-vacuum facility.

The practical payoff of "generic": a test setup installs only the device packages it actually has hardware for — a PLATO ground-support setup with a Symétrie hexapod on the bench pulls in `symetrie-hexapod` without pulling in anything ARIEL- or IvS-specific, and if a later ARIEL test campaign also happens to use a Symétrie hexapod, it reuses the same package unmodified rather than forking a copy under `projects/ariel/`. The three-way mission split (`plato` / `ariel` / `ivs`) exists precisely because that reuse boundary stops at mission-specific concerns: FITS/HDF5 export conventions, spacecraft-specific SpaceWire handling, and facility-specific TVAC control genuinely don't generalize.

None of the packages named in this section get a standalone chapter in this pass (Section 8) — this section is inventory, so their absence later isn't a surprise, not a preview of content still to come.

## 5. Anatomy of a Package

*Worked example: `projects/generic/symetrie-hexapod`.*

One real package, walked in full, is more useful than an abstract description, and every package in the workspace follows the same shape. `symetrie-hexapod` is a good representative because it is unambiguously "generic" (Section 4) and small enough to take in from end to end.

Its `pyproject.toml` declares what the built wheel actually contains:

```toml
[tool.hatch.build.targets.wheel]
packages = ["src/egse", "src/symetrie_hexapod"]
```

Two packages, from one `src/` tree, shipped in one wheel:

- **`src/egse/hexapod/...`** — the actual driver code: the PUNA/ZONDA/JORAN protocol implementations, the control-server and proxy classes for each device. This is contributed into the *shared* `egse` namespace (Section 6), the same namespace `cgse-common` and `cgse-core` contribute into, importable as `egse.hexapod....` from anywhere in the workspace.
- **`src/symetrie_hexapod/...`** — the package's own, private, never-shared surface: `settings.yaml` (device connection defaults — `HOSTNAME`, `PORT`, `CONTROLLER_TYPE` per hexapod, following the `Settings` conventions from Chapter 4), `cgse_explore.py` (a `show_processes()` function that lets `cgse explore` find this package's running processes by matching `puna|zonda|joran` against process command lines), and `cgse_services.py` (three `typer.Typer` sub-applications — `puna`, `zonda`, `joran` — each wrapping `subprocess.Popen` calls that start `egse.hexapod.symetrie.<name>_cs` as a background control-server process).

None of `symetrie_hexapod`'s own code is ever imported directly by another package. It exists solely to be *discovered* — its `pyproject.toml` registers `cgse_explore.py` and `cgse_services.py` under `cgse.explore` and `cgse.service.device_command` entry-point groups respectively (Section 7), which is how `cgse core status` and the `cgse` CLI's `puna`/`zonda`/`joran` subcommands come into existence without `cgse-core` ever importing `symetrie_hexapod` by name.

That two-halves shape — shared `egse.*` driver code plus a private, entry-point-facing distribution package — is the template every package in `libs/` and `projects/` follows, not just this one.

## 6. Naming Conventions and Navigation

*Given a module name, how to find it without guessing — and where an external contributor's package should put its code instead.*

::: {.concept}
**Python background: namespace packages.** A regular Python package is one directory with an `__init__.py`, owned by exactly one installed distribution. A *namespace package* (PEP 420) has no `__init__.py` at all — Python instead builds the package by merging every directory of that name it finds across every installed distribution on `sys.path`, at import time. That's a deliberate feature, not a workaround: it's what lets several independently-installed packages contribute to the same import path (`egse.*`, in CGSE's case) without any of them depending on each other or being registered anywhere central. The trade-off is exactly what Section 6 covers below: since no single package "owns" the namespace, nothing stops two distributions from shipping a module with the same name, and Python won't warn you — whichever one happens to be imported first (or last, depending on install order) silently wins. See the [Python docs on namespace packages](https://docs.python.org/3/reference/import.html#namespace-packages) for the full mechanism.
:::

`egse.*` is a namespace package: many different distributions — `cgse-common`, `cgse-core`, and every device and mission package in `projects/` — each contribute their own subtree into it, and Python merges all of them into one importable `egse` package at runtime. That has a direct, practical consequence: `import egse.hexapod.symetrie.puna` succeeding tells you nothing about which distribution installed it. `cgse_*` (`cgse_common`, `cgse_core`, `symetrie_hexapod`, ...) is the opposite — always one distribution's own private package, never shared, never merged with anything else.

Given a module name mentioned anywhere in this book — say `egse.dummy` — the concrete recipe for finding it is:

```bash
grep -rl "^def \|^class " --include="dummy.py" libs/*/src/egse projects/*/*/src/egse
```

or, faster once you know roughly which area it belongs to, just check which package's `pyproject.toml` lists the relevant `src/egse/...` subtree under `[tool.hatch.build.targets.wheel].packages` (Section 5). This is also exactly what this book's own "Modules: `egse/x.py`" lines in the chapter index mean in practice — they name the module, and this chapter is what lets you turn that into a real path.

The governance point below rests on one premise worth stating first: CGSE is deliberately designed so a new device driver doesn't require merging into the `cgse` monorepo at all. That's the actual point of the entry-point discovery mechanism (Section 7) — `cgse-core` finds device packages through `cgse.*` entry points, not hard imports, so a contributor can write, package, and register a driver entirely from their own separate repo and have it work alongside monorepo-native packages. Once that's established, the naming convention split follows as a consequence, not an arbitrary rule.

Inside the monorepo, contributing driver code into the shared `egse.*` namespace works because everything lives in one repo — one CI run, one set of reviewers, so a name collision between two packages' `egse/` trees gets caught before it merges. But `egse` is a PEP 420 implicit namespace package: at install time, Python silently merges whatever `egse/` directories show up across every installed distribution, with no built-in check for collisions. A contributor maintaining their own device-driver repo outside the monorepo isn't part of that CI/review process — if their package also drops files under `egse.`, it could silently shadow or overwrite a module from the monorepo (or from someone else's external package), with nothing catching it. So the rule is scoped by where the package is developed, not by what kind of package it is: inside the monorepo, use `egse.*` for driver code as usual, the same way every package in `libs/` and `projects/` does today; outside it, don't — keep everything under your own distribution's package name instead, and rely on entry points (Section 7), not the shared namespace, to plug into CGSE.

## 7. Package Discovery via Entry Points

*How optional packages plug into the `cgse` CLI and `cgse-core` without being hard-imported.*

The problem entry points solve is easy to state: `cgse-core` cannot hard-import `symetrie_hexapod` — doing so would make `cgse-core` depend on every device package that might ever exist, including ones written by external contributors it has never heard of (Section 6). Entry points invert that dependency: a package *declares*, in its own `pyproject.toml`, that it provides something under a named group, and whoever wants to consume that group asks Python's packaging metadata for "everything registered under this name" at runtime, with no import-time coupling at all.

The mechanism lives in `egse/plugin.py` (`cgse-common`), specifically `entry_points(group)` — a thin, cached wrapper around `importlib.metadata.entry_points().select(group=...)`. The `cgse` CLI's own startup code (`cgse_common/cgse.py`, `build_app()`) is the clearest example of it in action: it calls `entry_points("cgse.version")` to build `cgse version`'s output, and `entry_points("cgse.command")` to attach any top-level command a package wants to add.

The more interesting piece is `HierarchicalEntryPoints`, also in `egse/plugin.py`. Given a base group name like `"cgse.service"`, it scans *all* installed entry points and collects every group that either equals the base group or starts with `f"{base_group}."` — so `cgse.service.core_command`, `cgse.service.device_command`, and `cgse.service.example` are all discovered automatically under the `"cgse.service"` base, with no code anywhere needing to know those specific subgroup names in advance. `build_app()` uses exactly this to mount each discovered service as a `typer.Typer` sub-application, grouped in `cgse --help`'s output by a title derived from the subgroup's last segment (`device_command` → "Device Command", and so on). This is precisely why `symetrie-hexapod` registering a `cgse.service.device_command` entry point is enough to make `cgse puna`, `cgse zonda`, and `cgse joran` appear in the CLI — nothing in `cgse-core` or `cgse-common` was touched to add them.

The entry-point groups actually in use across the workspace today:

| Group | Used by | Purpose |
| ---------------------------------------- | -------------------------- | ---------------------------------------- |
| `cgse.version` | every package | Reports installed version |
| `cgse.settings` | most packages | Registers a `settings.yaml` (Chapter 4) |
| `cgse.command` | `cgse-tools` | Top-level CLI command |
| `cgse.service.core_command` | `cgse-core` | Core services (`reg`, `log`, `cm`, `sm`) |
| `cgse.service.device_command` | device packages | Per-device subcommands |
| `cgse.service.example` | `cgse-tools` | Reference example of the pattern |
| `cgse.explore` | most packages | Process discovery for `cgse core status` |
| `cgse.resource` | `cgse-core`, `cgse-gui` | Bundled resources (icons, etc.) |
| `cgse.extension.setup_provider` | `cgse-core` | `SetupManager` provider hook (Chapter 4) |
| `cgse.process_management.core_services` | `cgse-core` | Process-manager registration |
| `cgse.storage.persistence` | `plato-fits`, `plato-hdf5` | Storage-format plugins (Chapter 18) |

The full mechanics of how these groups are loaded, cached, and made robust against a broken plugin (`load_plugins_ep`, `broken_command`) belong to `egse/plugin.py`'s own treatment in Part III — this section's job is only to explain what the mechanism is for and where the wiring is declared, since Section 5's worked example and every later services chapter in Part IV assume the reader already has this picture.

## 8. Scope of This Book

*What's covered in depth, what's deliberately out.*

This book covers `cgse-common` (Part II's opening chapters and all of Part III) and `cgse-core` (the remainder of Part II and all of Part IV) in depth. `cgse-coordinates`, `cgse-gui`, the generic device-driver projects (`symetrie-hexapod`, `keithley-tempcontrol`, `lakeshore-tempcontrol`, `kikusui-power-supply`, `digilent`, `aim-tti-awg`, `cgse-tools`), and the mission-specific projects (`plato-fits`, `plato-hdf5`, `plato-spw`, `ariel-facility`, `ariel-tcu`, `tvac`) are named and located here (Sections 3–4) so a reader isn't left wondering why, say, `symetrie-hexapod` never gets its own chapter — but none of them are drafted as standalone chapters in this pass. [`cgse_book_chapter_index.md`](../../cgse_book_chapter_index.md) is the authoritative, current inventory of what's drafted versus still TBW; consult it for the current list — this section only explains why the boundary is drawn where it is.
