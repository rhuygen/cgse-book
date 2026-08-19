# CONTEXT.md

This file is the approved technical vocabulary for *CGSE: A Field Guide*, under the
ASD-STE100 project-vocabulary allowance. It fixes one term for one concept, so a
concept does not drift across chapters under different names.

## How this file works

No setup step is needed. Claude Code's output style checks for a `CONTEXT.md` file
at the repository root on its own. When this file is present, Claude uses each term
below exactly as defined, in the part of speech given. It does not substitute a
synonym, and it does not use a word an `Avoid` line rejects.

A term listed here gets its full definition once, in this file. A chapter that uses
the term does not need to redefine it inline — this is the one exception to the
normal STE rule that a domain term must be defined at its first use in running prose.

This file is separate from [05-acronyms.adoc](src/develop/front-matter/05-acronyms.adoc),
which expands abbreviations (CGSE, ARIEL, ZeroMQ, and so on) for the human reader.
This file exists for a different job: fixing word choice so the same concept does
not pick up two names, or one name does not quietly cover two concepts.

## Terms

### monorepo (noun)

One repository that holds every package in the framework: every library, every
device driver, and every mission-specific package. See
[03-repository-tour.adoc](src/develop/part-1-orientation/03-repository-tour.adoc),
Section 1.

_Avoid:_ "workspace" as a synonym. A workspace is the `uv` mechanism that operates
on the monorepo (see the `workspace` entry below). The two words name different
things: one is an organizational choice, the other is a tool.

### workspace (noun)

The `uv` workspace: the `[tool.uv.workspace]` and `[tool.uv.sources]` tables in the
root `pyproject.toml`. These let `uv` resolve and lock every package in the monorepo
together, against one `uv.lock` file.

_Avoid:_ "monorepo" as a synonym (see the `monorepo` entry above).

### namespace package (noun)

A Python package, defined by PEP 420, with no `__init__.py` file. Python builds it
by merging every directory of that name across every installed distribution, at
import time. In CGSE, `egse.*` is the one namespace package in the framework.

_Avoid:_ plain "package" when the merging behavior specifically matters. Plain
"package" covers both namespace packages and regular packages, and loses the
distinction the sentence needs.

### distribution (noun)

One installed Python package, in the packaging sense: the unit `pip` or `uv`
installs, with its own `pyproject.toml` and its own version. A distribution may
contribute a subtree into a namespace package without owning that namespace.

_Avoid:_ "package" as a strict synonym. "Package" is the broader, everyday word;
use "distribution" only where the installed-unit sense is the point, for example
when discussing what `importlib.metadata` reports.

### entry point (noun)

A name that one distribution registers in its own `pyproject.toml`, under a named
group, and that another distribution looks up at runtime through Python's packaging
metadata, without a direct import.

### register (verb, for entry points)

The action a distribution takes to make an entry point available: it lists the
name in its own `pyproject.toml`, under a group. Use "register" for this action
specifically.

_Avoid:_ "declare" for this action. Reserve "declare" for other `pyproject.toml`
content, such as dependencies or workspace membership, so the two actions stay
visibly distinct.

### CONSTANT (noun)

A configuration value that never changes without a code change: a module-level
name in a `.py` file. The first of three configuration kinds CGSE distinguishes;
see `Settings` and `Setup` below.

_Avoid:_ lowercase "constant" for this specific kind. Use lowercase "constant" only
in its ordinary English sense (unrelated to this three-way distinction).

### Settings (noun, capitalized)

A configuration value that changes per site or per deployment, but not during a
test run: a `settings.yaml` file shipped with a package, optionally overridden
locally. The second of three configuration kinds; implemented by `egse/settings.py`.

_Avoid:_ lowercase "settings" for this specific mechanism. Use lowercase "settings"
only for the ordinary English word (a device's settings, a tool's settings).

### Setup (noun, capitalized)

A configuration value that changes per test, per campaign, or per session: a
versioned, timestamped `Setup` YAML file with a unique ID, managed like data, not
like code. The third of three configuration kinds; implemented by `egse/setup.py`.

_Avoid:_ lowercase "setup" for this specific mechanism, and "the more dynamic
version of Settings" as a description — `Setup` is data with provenance, not a
faster-changing `Settings`. For the physical sense (the hardware on a bench), use
"test setup" (see below), never bare "setup."

### test setup (noun)

The physical hardware and instruments at one site, ready to run a test campaign:
for example, a PLATO ground-support setup with a Symétrie hexapod on the bench.

_Avoid:_ bare "setup" for this sense, since it collides with `Setup`, the
capitalized configuration mechanism above. Always pair it with "test" or another
qualifier (ground-support setup, deployed setup) to keep the two apart on sight.

### Control Server (noun, capitalized)

The long-running server process that owns the physical connection to one device or
service, and is the only thing that ever talks to it directly. Implemented by the
`ControlServer` base class in `egse/control.py`.

_Avoid:_ bare "server" once `Control Server` has been introduced in a chapter;
switching to "server" invites confusion with other server-shaped things in the
same chapter (a registry backend, a web server). Repeat "Control Server."

### Proxy (noun, capitalized)

The client-side object that a test script or GUI uses to talk to a Control Server.
It presents the same interface as the device itself. Implemented by the `Proxy`
class in `egse/proxy.py`.

_Avoid:_ "client" as a synonym. "Client" is fine for the general role (some process
acting as a client), but the specific object is always "Proxy."

### Service Registry (noun, capitalized)

The CGSE service that lets a Control Server register itself, and a Proxy discover
it, without either side knowing a fixed, statically configured port in advance.

_Avoid:_ bare "registry" once `Service Registry` has been introduced in a chapter,
for the same reason as `Control Server` above.

### device driver (noun)

A package that implements the Control Server and Proxy pair for one specific
physical device, under `projects/generic/` or a mission-specific `projects/`
subdirectory.

_Avoid:_ "driver" alone in a context where it could also mean an OS-level device
driver (a different, unrelated concept). Use the full "device driver."
