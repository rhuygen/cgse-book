# Part II — Core Concepts

## Chapter X — Settings and Setup: Where Configuration Lives

### Why this chapter comes early

Almost every other module in CGSE touches `Settings` or `Setup` somewhere. Before we can talk sensibly about device controllers, control servers, or GUI clients, we need a shared vocabulary for a question that comes up in nearly every code review: *should this value be a* `CONSTANT`*, a* `Settings` *entry, or a* `Setup` *entry?*

This chapter answers that question by walking through the two modules that implement the answer: `egse/settings.py` and `egse/setup.py`, both in `libs/cgse-common/src/egse/`. It also touches `egse/env.py` and `egse/plugin.py`, because `Settings` and `Setup` are thin on top of what those two modules provide, and the design only makes sense once you see the layering.

Read this chapter as the template for the rest of the book: for every module we cover later, we'll ask the same three questions — what problem is this solving, what did we decide and why, and where are the sharp edges — but we won't repeat the reasoning about *when to use Settings vs Setup vs a constant*. That reasoning lives here, once, and everything downstream refers back to it.

---

### 1. The problem: three very different kinds of "configuration"

Test facility software accumulates configuration values from day one, and if you don't deliberately separate *kinds* of configuration, they all end up in the same place — usually scattered across module-level constants, `.ini` files, and someone's personal `config.py` that nobody else knows exists. Three years into your project, that becomes unmanageable.

CGSE draws the line along one axis: **how often does the value change, and who changes it?**

| Kind       | Changes...                                           | Example                                                                              | Where it lives                                                           |
| ---------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| `CONSTANT` | Never, without a code change                         | `LOG_FORMAT_DEFAULT`, a physical constant, a protocol magic number                   | A module-level name in the `.py` file                                    |
| `Settings` | Per site / per deployment, but not during a test run | `SSH_SERVER`, `RMAP_BASE_ADDRESS`, log format overrides                              | `settings.yaml`, shipped with the package, optionally overridden locally |
| `Setup`    | Per test, per campaign, sometimes per session        | which hexapod ID is connected, its calibration file, the device class to instantiate | A `Setup` YAML file with a unique ID, managed like data, not like code   |

The rule of thumb we use in code review:

- If changing the value means **releasing a new version of the code**, it's a `CONSTANT`.
- If changing the value means **editing a YAML file that ships with, or sits next to, the package**, and the same value is expected to hold for the lifetime of a site's installation, it's a `Settings` entry.
- If changing the value means **swapping what's physically plugged into the setup, recalibrating something, or starting a new test campaign**, it's a `Setup` entry — and it needs a Setup ID so we can always answer "which configuration was active when this data was taken?"

That last point is the one that trips people up: `Setup` is **not** "the more dynamic version of Settings." It's closer to *data with provenance, with history*. A `Setup` is versioned, timestamped, attributable to a site, and stored as an immutable artifact once submitted. `Settings` has none of that machinery, deliberately, because it doesn't need it — nobody needs to reconstruct "what were the SSH port settings on 14 March 2023."

Keeping this distinction sharp is also what keeps `Settings.load()` fast and side-effect-free (safe to call from anywhere, including import time) while `Setup` loading is explicitly a stateful operation with a global "current setup" context. Blurring the two would have made one of them slow and the other one unsafe.

**Settings vs. Setup vs. Environment Variables:**

**TBD — merge the following with the previous paragraphs**

The distinction between Settings and Setup is crucial and often confused. Remember: **Settings are static, Setup is dynamic.**

- **Settings** `egse.settings.Settings`) — constants, IP addresses, port numbers, system definitions, equipment types, hardware identifiers. Static and change infrequently (only when the system or network is reconfigured). Distributed with the software, with local overrides via environment variable. Examples: `COMMANDING_PORT`, `HOSTNAME`, `MAX_LOG_FILES`, `SERVICE_TYPE`, `DEVICE_NAME`, `MAC_ADDRESS`.
- **Setup** `egse.setup.Setup`) — configuration items, conversion coefficients and tables, device identification and tuning, everything that defines the system *for this specific test or mission*. Changes frequently during a test campaign as calibration is improved or hardware is swapped. Kept under version control in Git, but specific to each campaign/mission. Examples: calibration curves, SUT (System Under Test) parameters, reference frames, which devices are online, gain coefficients.
- **Environment Variables** `.env` + `python-dotenv`) — secrets and deployment metadata, never checked in. Only the `.env.example` template is checked in. Examples: database passwords, API keys, external service URLs, `PROJECT` name, `LOCAL_SETTINGS` path.

The rule of thumb: If a value is test-specific or changes frequently, it belongs in Setup. If it's a secret, use `.env`. If it's a system constant that's shipped with the code, it's a Setting.

---

### 2. `egse/settings.py` — configuration that ships with the code

#### 2.1 What it needs to solve

Static configuration for the entire system — hostnames, port numbers, device parameters, site ID, log levels, resource limits, etc.. Settings are *not* for values that change at runtime (use `Setup` for calibration, SUT state, models) and *not* for sensitive credentials (use `.env` + `python-dotenv` for API keys, database passwords).

Every installable CGSE package (`cgse-common`, `cgse-core`, a device package like `symetrie-hexapod`, a project package like `plato-fits`) may want to contribute its own default static configuration values, without any package having to know about any other package's settings file in advance, and without a central registry file that everyone has to remember to edit.

That requirement — *decentralized contribution, centralized consumption* — is what pushes the design toward Python entry-points rather than a single settings file living in `cgse-common`.

The `Settings` class in `egse.settings` is the central API. It caches (memoizes) loaded YAML files and returns `attrdict` objects — dicts that allow dot-notation access (`settings.COMMANDING_PORT` instead of `settings["COMMANDING_PORT"]`). All settings are loaded once at app startup and treated as immutable thereafter.

#### 2.2 The entry-point mechanism

Settings are discovered and merged at startup via entry-points (`cgse.settings`), then optionally overlaid with site-specific local settings (via `<PROJECT>_LOCAL_SETTINGS` environment variable). The merge order is: built-in defaults come first (in each package's `settings.yaml`) → local settings overrides. This lets you deploy to different labs without modifying checked-in code.

Each package that provides configuration settings declares this in its `pyproject.toml` by registering its `settings.yaml` file via the `cgse.settings` entry-point:

```toml
[project.entry-points."cgse.settings"]
cgse-common = "cgse_common:settings.yaml"
```

The entry-point value `"module:filename"` must point to a file inside a real Python package (with `__init__.py`). The `egse.plugin.load_plugins_ep` machinery discovers these at runtime and loads/merges them in entry-point order.

**Why this matters:** When a new device package is added to the monorepo, its settings are automatically discovered — no global registry file to update, no manual plumbing. When two packages define the same top-level group, the second one's values overwrite the first (allowing intentional overrides).

The function `get_file_infos()` in `egse/plugin.py`, when called with `entrypoint="cgse.settings"`, resolves every entry-point registered under that group name into a `(path, filename)` tuple by importing the named module and asking Python where it lives on disk:

```python
def get_file_infos(entry_point: str) -> dict[str, tuple[Path, str]]:
    eps = dict()
    for ep in entry_points(entry_point):
        try:
            path = get_module_location(ep.module)
            if path is None:
                logger.error(...)
            else:
                eps[ep.name] = (path, ep.attr)
        except Exception as exc:
            logger.error(...)
    return eps
```

Two design choices worth calling out:

- **A broken entry-point never blocks the others.** Each entry-point is resolved inside its own `try/except`, and a failure is logged, not raised. If the `pyproject.toml` in `plato-spw` has a typo in its entry-point, every other package's settings still load. This matters a lot in a monorepo where a mistake in one project package shouldn't be able to take down `cgse-core` for everyone else.
- **The module name uses underscores, the package name uses dashes.** `cgse-common` (the installable package / PyPI name) exposes settings through `cgse_common` (the importable Python module). This is standard Python packaging convention, but it's called out explicitly in the docstring because it's exactly the kind of thing that silently breaks an entry-point and takes ten minutes to debug the first time you hit it. Dashes are not allowed in a module name because it will be interpreted as a minus sign while parsing the Python file and you will get a `SyntaxError`.

The function `load_global_settings()` then reads every resolved file and merges them:

```python
def load_global_settings(entry_point: str = "cgse.settings", force: bool = False) -> attrdict:
    ep_settings = get_file_infos(entry_point)
    global_settings = attrdict(label="Settings")
    for ep_name, (path, filename) in ep_settings.items():
        settings = load_settings_file(path, filename, force)
        recursive_dict_update(global_settings, settings)
    return global_settings
```

**Design decision — later package wins.** `recursive_dict_update` merges dictionaries key by key rather than replacing whole top-level groups, and iteration order determines who wins on a conflicting key. This is called out explicitly in the module docstring ("make sure the group names in each package configuration file are unique") rather than solved with an error, because enforcing strict uniqueness across every package in a monorepo — including third-party device packages we don't control — is a bigger cost than the (rare) conflict it would prevent. This is a pragmatic trade-off: we chose "convention documented in the docstring" over "mechanism enforced in code," and it has held up in practice, but it is worth an explicit test whenever a new package adds a top-level group name.

#### 2.3 The float-parsing fix

*A piece of code that looks pointless until you know why its there.*

Near the top of the file:

```python
# Fix the problem: YAML loads 5e-6 as string and not a number
# https://stackoverflow.com/questions/30458977/yaml-loads-5e-6-as-string-and-not-a-number

SAFE_LOADER = yaml.SafeLoader
SAFE_LOADER.add_implicit_resolver(
    "tag:yaml.org,2002:float",
    re.compile(r"""^(?: ... )$""", re.X),
    list("-+0123456789."),
)
```

This is exactly the kind of thing that a future maintainer might "clean up" as dead-looking regex noise, so it deserves a paragraph here rather than just a code comment.

PyYAML's `SafeLoader`, out of the box, only recognizes floats written with a decimal point in a narrow set of forms — `5e-6` (no decimal point before the exponent) parses as a **string**, not a float, unless the resolver is patched. That's a real problem for us: calibration coefficients and physical constants in scientific notation are exactly the kind of value that ends up in a `settings.yaml` or `Setup` YAML file, written the way a scientist would naturally write it. Silent string-instead-of-float bugs are nasty precisely because they don't crash — they misbehave quietly downstream, in a unit conversion or a threshold comparison, until someone notices a graph looks wrong.

The fix replaces the implicit resolver for the float tag with a broader regex (adapted from a well-known PyYAML issue) so that `5e-6`, `.5e-6`, `+5e-6` and friends parse as floats everywhere `SAFE_LOADER` is used — which, because `SAFE_LOADER` is patched at module level, means everywhere in the codebase that loads YAML through this module, not just in `Settings`. This is a case where the fix has to sit at the "load YAML" chokepoint rather than in every call site, because there's no way for a call site to know it's about to receive a mis-typed string instead of a float.

#### 2.4 Memoization: `read_configuration_file`

Settings are memoized by filename; calling `Settings.load()` again doesn't re-read the YAML file from disk. This is by design — settings are static. If you do need to reload (e.g. in a long-running daemon where the local settings file was edited), call `Settings.load(force=True)`. However, this does *not* automatically propagate to code that cached settings in local variables or class instance variables. **Be cautious**: if a part of your app caches `self.port = settings.COMMANDING_PORT` at \_\_**init**\_\_, a later `Settings.load(force=True)` won't update `self.port`. In practice, avoid reloading; restart the process instead.

```python
def read_configuration_file(filename: Path, *, force=False) -> dict:
    filename = str(filename)
    if force or not Settings.is_memoized(filename):
        ...
        with open(filename, "r") as stream:
            yaml_document = yaml.load(stream, Loader=SAFE_LOADER)
        Settings.add_memoized(filename, yaml_document)
    return Settings.get_memoized(filename) or {}
```

Every YAML file is parsed once per process and cached in a class-level dictionary (`Settings.__memoized_yaml`) keyed by filename. The function `Settings.load()` can be called many times per second from many different places in the codebase — device drivers routinely call `Settings.load("SOME_DEVICE")` inside `__init__`, and control servers may re-instantiate device proxies repeatedly — so re-parsing YAML from disk on every call would be wasteful for no benefit, since these files are not expected to change while a process is running. `force=True` exists specifically to bypass the cache, and it's used in the test suite and in the `--local`/`--global` CLI paths where a fresh read is actually meaningful (e.g. after a test intentionally rewrites a YAML file on disk).

> **Performance Note**
>
> YAML parsing happens once per file, then results are cached. On first app startup, \`load_global_settings\` discovers and loads all entry-points, which is O(number of packages). Subsequent \`Settings.load()\` calls are O(1) cache lookups. For tight loops, cache the group you need: \`settings = Settings.load("MyGroup")\` at module level, not inside a loop.

**Why a class attribute and not a module-level dict?** Keeping the cache as a "private" (name mangled) class attribute `__memoized_yaml` on `Settings` rather than a plain function keeps the introspection API (`is_memoized`, `get_memoized_locations`, `clear_memoized`) attached to the same namespace users already import. It's a minor stylistic choice, but it means `Settings.get_memoized_locations()` reads naturally at a REPL when you're debugging *why* a settings file doesn't seem to reflect an edit you just made on disk — which, in practice, is almost always "you need `force=True` because the process already cached it."

#### 2.5 Why `Settings` is a class of class-methods, not an instance

Notice that `Settings` is never instantiated — every method is a `@staticmethod` or `@classmethod`, and `Settings.load(...)` doesn't return a `Settings` object, it returns a plain `attrdict`. This is a deliberate choice, not an oversight:

- `Settings` itself behaves as a **namespace + cache**, not as a piece of configuration. There is exactly one settings cache per process, so a class (effectively a singleton by construction, without needing singleton machinery) is the right shape.
- The *returned* object — the actual settings for a group — is a plain dictionary-like structure (`attrdict`, from `egse.system`) so that calling code gets ordinary dict/attribute access (`dsi_settings.RMAP_BASE_ADDRESS` or `dsi_settings["RMAP_BASE_ADDRESS"]`) without inheriting any of the loading/caching logic. Nobody should be calling `.load()` on the object they get back from `Settings.load()` — that only makes sense on the `Settings` class itself.

This split — "the loader is a class, the result is a dict" — is a pattern you'll see again in `Setup` (Section 3), but with an important difference explained below: `Setup` needs a *richer* returned object than a plain dict, because Setup values can trigger side effects on access (see `class//`, `csv//` in Section 3.3), so `Setup` couldn't get away with returning something as thin as `attrdict`.

#### 2.6 `Settings.load()` — the three call shapes

```python
from egse.settings import Settings

# All global + local settings
settings = Settings.load()  # Returns full nested dict

# Single group
storage_settings = Settings.load("Storage Control Server")
print(storage_settings.COMMANDING_PORT)  # Dot notation

# Single YAML file (useful for command specs, test configs)
commands = Settings.load(location="~/my-project", filename="commands.yaml")

# Force reload (unusual; avoid if possible)
settings = Settings.load(force=True)
```

The load method itself handles the three call shapes in three different code branches:

```python
@classmethod
def load(cls, group_name=None, filename="settings.yaml", location=None, *,
         add_local_settings=True, force=False) -> attrdict:
    if group_name:
        return cls._load_group(group_name, add_local_settings=add_local_settings, force=force)
    elif location:
        return cls._load_one(location=location, filename=filename, force=force)
    else:
        return cls._load_all(add_local_settings=add_local_settings, force=force)
```

Three branches, three private helpers, dispatched on which keyword arguments were actually passed. This is a case of routine code — a simple if/elif/else — but the *reason* three shapes exist is worth stating, because it's a genuine design decision, not an accident of incremental feature creep:

- `group_name` **only** — "give me the settings for group X from the merged entry-point configuration." This is the overwhelmingly common call in device drivers: `Settings.load("DSI")`.
- `location` **(with optional** `filename`**)** — "give me settings from *this specific file*, bypass entry-points entirely." Used for one-off configuration files that don't belong to any installed package's plugin contract — e.g. loading a `command.yaml` file for a specific test script, or reading a user's private local file directly by path.
- **Neither** — "give me everything," i.e. the merged settings from every package's entry-point, which is what the `python -m egse.settings` CLI and diagnostics use.

The `add_local_settings` parameter deserves its own note: it defaults to `True`, meaning the *local* settings file (path given by the `<PROJECT>_LOCAL_SETTINGS` environment variable, see `egse/env.py`) is layered on top of the package-shipped settings by default. This is the mechanism that lets a single test site override, say, `SITE.SSH_SERVER` without touching any installed package's YAML file. It's opt-out rather than opt-in deliberately: the common case in production is "yes, apply whatever local overrides this site has defined," and the `main()` CLI's `--global` flag is the explicit escape hatch for the rarer "show me the settings as shipped, ignore this site's overrides" diagnostic case.

#### 2.7 Local Settings (Site Customization)

Define a local `.yaml` file (typically `~/cgse/local-settings.yaml` or a project-specific path) and set the environment variable:

```bash
export CGSE_LOCAL_SETTINGS=~/cgse/local-settings-lab42.yaml
```

Then call `Settings.load(add_local_settings=True)` (which is the default). Local settings are merged *after* global settings, so they take precedence. You only need to define groups/keys that differ from the built-in defaults:

```yaml
# local-settings-lab42.yaml
SITE:
    ID: LAB42
    SSH_SERVER: pleiades.obs.kuleuven.be

Keithley Control Server:
    HOSTNAME: hardware-rack-02
    COMMANDING_PORT: 6920
```

#### **2.8 Debugging & Inspection**

```bash
# Print all loaded settings
python -m egse.settings

# Just local settings
python -m egse.settings --local

# Just one group
python -m egse.settings --group "Keithley Control Server"
```

The output includes a "Memoized locations" list showing which YAML files were actually loaded.

#### **2.9 Common Patterns**

**Dynamic port allocation:** Set `PORT: 0` in your Settings YAML file; the OS then assigns an ephemeral port. Example: a control server reads `settings.COMMANDING_PORT = 0`, the OS assigns port 6920, and the server registers `service_type="MYDEVICE", port=6920` with the service registry.

Clients then call `registry.discover_service("MYDEVICE")` to get the actual port. This decouples client config from server config. This is especially useful for device drivers where control servers should not allocate fixed port numbers for their services. Dynamically allocated ports are also used for testing (multiple test runs don't collide on ports).

**Per-device overrides:** Nested settings allow one package to define multiple device configs (see `symetrie-hexapod/settings.yaml` with PUNA, ZONDA, JORAN under `Hexapod Controller`). Clients choose which config to use.

**Environment-specific settings:** Different labs can each have their own local settings file. Deploy the same code everywhere; only the local settings file changes.

#### 2.10 What we deliberately left out of `Settings`

No validation against a schema, no type coercion beyond what YAML gives you, no notion of "required" keys. Any of these would be reasonable additions in isolation, but `Settings` is used by every package in the ecosystem, including third-party device packages we don't control the release cycle of. A stricter contract here would mean a schema change in `cgse-common` could break settings loading for a device package that hasn't been touched in two years. The looseness is the feature, not a gap — the cost of that looseness (a typo'd key silently returns `KeyError` later, at the point of use, rather than at load time) is one we've accepted and haven't needed to revisit.

---

### 3. `egse/setup.py` — configuration that describes *this specific test*

#### 3.1 What's fundamentally different here

If `Settings` answers "how is this site configured," `Setup` answers "what was plugged in, and how was it calibrated, for this specific test." The requirements are correspondingly different:

- It needs a **stable, reference-able identity** (a Setup ID) so that any dataset produced during a test can point back at exactly the configuration that was active — this is a traceability requirement, not a convenience.
- It needs to represent **devices**, not just values — a hexapod isn't a number, it's a live object with methods, and the Setup is where "which hexapod, at which IP, using which simulator or real driver" gets decided.
- It needs to be **navigable** by both dictionary keys and dotted attribute access, because the Setup tree can be deep (`setup.gse.hexapod.ID`) and typing `setup["gse"]["hexapod"]["ID"]` everywhere in test scripts would be painful.
- It needs a **notion of "the current one"**, because test scripts, GUIs, and control servers all need to agree on which Setup is active right now without explicitly passing it as a parameter through every function call.

Each of those four requirements maps onto a concrete piece of the implementation below.

The Setup is the complete configuration for a specific test, mission, or observation run. Where Settings are static system constants, Setup is mutable test-specific state — hardware identifiers, calibration coefficients, reference frames, conversion functions, device objects, etc. Setups change frequently during a campaign as calibration improves or hardware is swapped; they are kept under version control.

#### 3.2 Built on `navdict`, not reinvented

`Setup` doesn't implement dotted navigation itself — it extends `navdict` (`NavigableDict` from the `navdict` package), which provides:

- Hierarchical nested dictionary structure for organizing configuration
- Dot-notation access: `setup.gse.hexapod.ID` in addition to `setup["gse"]["hexapod"]["ID"]`
- Special value processing via directives (see below)

A Setup is typically loaded from a YAML file, navigated during a test run, and re-saved when modifications are made (e.g. after calibration improvements). The Configuration Manager (`cm_cs`) holds the current active Setup and serves it to all services on demand.

```python
from navdict import navdict
from navdict.navdict import NavigableDict

class Setup(NavigableDict):
    ...
```

This is a case where a piece of *generic* functionality (navigable, YAML-backed, dot-and-bracket-accessible dictionaries) was deliberately pulled out of CGSE into its own mission-agnostic library, precisely because it has no CGSE-specific behavior in it — the CGSE-specific part is everything `Setup` adds on top: setup IDs, the `class//`/`csv//` family of special values called *directives* (Section 3.3), site-aware file discovery, and the submit/load lifecycle.

The `navdict` split is a good illustration of a general principle worth stating once, here, since it recurs across the codebase: **if a piece of code has no dependency on** `egse.env`**,** `egse.log`**, or any test-facility concept, that's a signal it belongs in its own package, not in** `cgse-common`**.** `cgse-common` is for things that are common *to CGSE*, not common to Python projects in general.

#### 3.3 Special values: the `class//`, `csv//`, `yaml//`, `pandas//`, `int-enum//` directives

This is the part of `Setup` most likely to look like magic to someone reading it for the first time, so it's worth being explicit about the mechanism and the motivation.

A Setup YAML file can contain a value like:

```yaml
gse:
  hexapod:
    ID: 42
    device: "class//egse.hexapod.symetrie.puna.PunaSimulator"
```

and accessing `setup.gse.hexapod.device` doesn't return the *string* `"class//egse.hexapod.symetrie.puna.PunaSimulator"` — it imports that class, instantiates it, and returns the live object. This is implemented via `navdict`'s directive registry (`register_directive`), and `egse/setup.py` registers two CGSE-specific directives on top of whatever `navdict` provides out of the box. When you access a Setup value that begins with a special prefix, navdict automatically processes it:

| Prefix       | Behavior                                  | Example                                                                                             |
| ------------ | ----------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `class//`    | Instantiate and return the class object   | `device: "class//egse.hexapod.symetrie.puna.PunaSimulator"` → returns a live PunaSimulator instance |
| `factory//`  | Load module, call its `create()` method   | `spline: factory//my.package.calibration.spline` → calls `spline.create()`, returns result          |
| `csv//`      | Load CSV file, return as numpy array      | `coeff: "csv//calibration/gain_20250101.csv"` → numpy array of coefficients                         |
| `pandas//`   | Load CSV file, return as pandas DataFrame | `trends: "pandas//historical_data.csv"`                                                             |
| `yaml//`     | Load YAML file, return as dict            | `reference: "yaml//reference_frames.yaml"`                                                          |
| `int-enum//` | Dynamically create an Enum                | `states: "int-enum//enum.StateType"` → enum.StateType class                                         |

Files are resolved relative to the configuration data location (from `<PROJECT>_CONF_DATA_LOCATION` environment variable).

```python
def _load_csv(value: str, parent_location: Path | None, *args, **kwargs):
    from numpy import genfromtxt
    parts = value.rsplit("/", 1)
    [in_dir, fn] = parts if len(parts) > 1 else [None, parts[0]]
    csv_location = get_resource_location(parent_location, in_dir)
    try:
        content = genfromtxt(csv_location / fn, delimiter=",", skip_header=1)
    except FileNotFoundError as exc:
        raise ValueError(f"Resource file not found: {value} in {csv_location}")
    except TypeError as exc:
        raise ValueError(f"Couldn't load resource '{value}' from {csv_location}") from exc
    return content

register_directive("csv", _load_csv)
register_directive("pandas", _load_pandas)
```

**Why override** `csv//` **here instead of leaving** `navdict`**'s default?** The docstring for `_load_csv` says it plainly: "This is a replacement of the standard `load_csv()` function from the navdict package." `navdict`, being mission-agnostic, has no reason to assume NumPy is installed or that a CSV should become a NumPy array rather than, say, a list of lists. CGSE's calibration data (temperature curves, coefficient tables) is used almost exclusively as NumPy arrays downstream, so `egse.setup` overrides the directive with one that returns `genfromtxt(...)` directly, saving every call site from having to convert. This is the general pattern for extending `navdict` from CGSE: **register CGSE-specific directives at import time of** `egse.setup`**, rather than forking or subclassing** `navdict`**'s loader.** It keeps `navdict` clean and keeps the CGSE-specific behavior localized to one file.

**Why is this dangerous, and why do we accept the danger?** A `class//` value causes arbitrary code to run — importing and instantiating a class — the moment someone *reads* a Setup attribute. That's an unusual property for what looks like a plain configuration file, and it means Setup files are not safe to load from an untrusted source. We accept this because Setup files are generated and curated by the team, versioned, and never sourced from outside the facility — the convenience of `setup.gse.hexapod.device.homing()` working straight out of a YAML-described configuration, with no boilerplate device-instantiation code in every test script, outweighs the risk in this closed context. The docstring's own advice — *"It would however be better (more performant) to put the device object in a variable"* — is a second, independent piece of guidance: every attribute access on a `class//` value re-triggers `_get_attribute`'s resolution path (see `NavigableDict`), so repeated access is also a performance foot-gun, not just a style preference.

**Example Setup Structure**

```yaml
gse:
  hexapod:
    device_name: "Puna Hexapod"
    device: "class//egse.hexapod.symetrie.puna.PunaSimulator"
    device_id: "HEX_001"
    ID: 42
    calibration: "csv//hexapod/calib_puna_001.csv"

  power_supply:
    device_name: "Keithley DAQ6510"
    device: "class//egse.keithley.DAQ6510Proxy"
    device_id: "DAQ_001"
    gains: "pandas//keithley/gains.csv"
    conversion: "factory//my_calibration.temperature:create_conversion_curve"

instrument:
  reference_frames: "yaml//coordinates/reference_frames.yaml"
  detector_model: "class//my_project.imaging.DetectorModel"
```

In code, you'd access these naturally:

```python
setup = load_setup(setup_id=123)

# Dot notation navigation
hexapod = setup.gse.hexapod.device  # Instantiated immediately (class// directive)
gains = setup.gse.power_supply.gains  # Loaded as pandas DataFrame
calibration = setup.gse.hexapod.calibration  # Loaded as numpy array
```

#### 3.4 The Setup ID and filename contract

```python
def _parse_filename_for_setup_id(filename: str) -> str | None:
    match = re.search(r"SETUP_(\w+)_([\d]{5})_([\d]{6})_([\d]{6})\.yaml", filename)
    try:
        return match[2]  # match[2] is setup_id
    except (IndexError, TypeError):
        return None
```

Setup files follow a strict, encoded filename convention: `SETUP_<site_id>_<5-digit id>_<date>_<time>.yaml`, e.g. `SETUP_CSL_00082_210923_094458.yaml`. The identity of a Setup is derived from its **filename**, not from a field inside the YAML content. This is a design choice worth defending, because it looks backwards at first (why not just put `setup_id: 82` inside the file?):

- The filename is what survives when the file is copied, emailed, attached to a ticket, or listed in a directory — the identity travels with the artifact even in contexts where nobody has opened it to read the content.
- It makes duplication detection trivial: two files can't accidentally claim the same ID unless someone deliberately renames one, which is a much rarer mistake than a copy-pasted YAML field.
- Setup IDs are assigned by `submit_setup_to_disk` (Section 3.7) by scanning existing filenames for the current site and taking `max(existing) + 1` — the filename *is* the source of truth for "what's the next available ID," so it would be redundant, and a source of drift, to also track IDs inside file content.

The regex is applied in two places (`_parse_filename_for_setup_id` and `disentangle_filename`) with slightly different return shapes — one returns just the ID, the other returns `(site_id, setup_id)` as a tuple. This duplication is minor and could be collapsed, but it's flagged here as exactly the kind of small thing worth cleaning up opportunistically rather than urgently: low risk, low cost, not worth a dedicated refactor PR on its own.

#### 3.5 `NavigableDict` subclass, not composition

```python
class Setup(NavigableDict):
    def __init__(self, nav_dict: NavigableDict | dict = None, label: str = None):
        try:
            _filename = nav_dict.get_private_attribute("_filename")
        except AttributeError:
            _filename = None
        super().__init__(nav_dict or {}, label=label, _filename=_filename)
        try:
            setup_id = nav_dict.get_private_attribute("_setup_id")
            self.set_private_attribute("_setup_id", setup_id)
        except AttributeError:
            pass
```

Inheritance was chosen over composition (wrapping a `NavigableDict` inside a `Setup` and delegating) because `Setup` needs to *be* a navigable dict for the dotted-attribute ergonomics to work transparently — `setup.gse.hexapod.ID` needs every intermediate node to also behave like a `NavigableDict`, and composition would require re-implementing `__getattr__` forwarding at every level for no benefit over what subclassing gives for free.

Notice the `try/except AttributeError` pattern used twice here for copying "private attributes" (`_filename`, `_setup_id`) from an existing `NavigableDict` into the new `Setup`. This looks slightly unusual — most code would check `hasattr` or use `getattr(..., default)` — but `get_private_attribute` is a `navdict` API that raises when the attribute was never set, rather than returning `None`, so the `try/except` here is the correct idiom given that library's contract, not an inconsistency with the rest of the codebase's style.

#### 3.6 The "current Setup" context: `setup_ctx` and why it's a `ContextVar`

```python
setup_ctx: ContextVar[Setup | None] = ContextVar("setup", default=None)
```

```python
def load_setup(setup_id: int = None, **kwargs):
    setup = _setup_manager.load_setup(setup_id, **kwargs)
    setup_ctx.set(setup)
    return setup
```

`contextvars.ContextVar` rather than a plain module-level global was chosen specifically because CGSE control servers are multi-threaded (and increasingly touch `asyncio` code, e.g. the monitoring/gauge work), and a plain global would mean "the current Setup" is shared, and mutable from every thread, with no isolation. A `ContextVar` gives each thread/task its own view unless explicitly propagated, which matches the actual requirement: "the Setup currently active in *this* context," not "the one global Setup for the whole process," even though in the overwhelmingly common single-threaded-test-script case, those two things look identical and this distinction is invisible. This is a case of paying a very small complexity cost up front to avoid a genuinely hard concurrency bug later — the value of the `ContextVar` choice doesn't show up until someone runs two things concurrently that each expect their own Setup, at which point a plain global would have produced a very confusing bug.

#### 3.7 Submit/load as a deliberately asymmetric pair

```python
def submit_setup_to_disk(setup: Setup, description: str, **kwargs) -> str | None:
    ...
    setup_id = (max(existing_setup_ids) + 1) if existing_setup_ids else 0
    filename = f"SETUP_{site_id}_{setup_id:05d}_{format_datetime(fmt='%y%m%d_%H%M%S')}.yaml"
    history = setup.get("history")
    if not isinstance(history, dict):
        history = {}
        setup["history"] = history
    history.update({f"{setup_id}": description})
    setup.set_private_attribute("_setup_id", setup_id)
    setup.to_yaml_file(setup_location / filename)
    save_last_setup_id(setup_id, site_id=site_id)
    ...
    return f"{setup_id:05d}"
```

A few decisions bundled into this one function:

- **Setups are append-only.** `submit_setup_to_disk` never rewrites an existing Setup file — it always computes the next ID and writes a new file. Combined with the `history` dict that accumulates a `{setup_id: description}` entry on every submit, this gives an audit trail for free: you can always see the chain of descriptions that led to the current configuration. This matters in an ESA test campaign context, where "what changed and why" needs to be answerable months later, possibly by someone who wasn't in the room.
- **The rich-printed message after submission is a deliberate nudge, not decoration:**

```python
rich.print(textwrap.dedent("""\
    Saving setup to disk, a new setup identifier has been assigned.
    To finalize the submit, reload the setup:

    setup = load_setup()
    """))
```

Submitting a Setup and continuing to use the in-memory `setup` object you already had would silently work most of the time, but that object doesn't have the newly assigned `_setup_id` reflected consistently with what's on disk in every code path, and — more importantly — it isn't the object registered in `setup_ctx`. The explicit reminder exists because this was, in practice, a mistake people made before the message was added: submit, then keep working from the stale in-memory reference. This is worth flagging in the book precisely because it's a "brain fart" class of bug — not a logic error, a *forgot to reload* error — and the fix was social (tell the user) rather than technical (force a reload), because forcing a reload would have meant deciding unilaterally that the caller's reference should be invalidated, which is more surprising than a printed reminder.

#### 3.8 `SetupManager` and the provider pattern

> Designed for a dependency that might not be installed.

Setups can be loaded from different sources (local disk, core-services, database, remote server, etc.) via pluggable providers. Packages register custom providers through the `cgse.extension.setup_provider` entry-point:

```toml
[project.entry-points."cgse.extension.setup_provider"]
my-custom-provider = "my_package.setup:MySetupProvider"
```

The `SetupManager` loads and caches the Setup providers when the `providers` property is accessed.

```python
class SetupManager:
    def __init__(self):
        self._providers: list | None = None
        self._default_source = "local"
        self._discovery_lock = Lock()

    @property
    def providers(self):
        if self._providers is None:
            with self._discovery_lock:
                if self._providers is None:
                    self._providers = self._discover_providers()
        return self._providers
```

This is double-checked locking, the classic pattern for "initialize exactly once, lazily, safely under concurrent access." It's used here, and not in most other lazy-init spots in the codebase, because `_discover_providers()` does entry-point discovery — I/O-adjacent work you don't want to repeat, and don't want two threads racing to do simultaneously the first time a Setup is requested.

The reason `SetupManager` exists as an abstraction at all, rather than `load_setup` just calling `load_setup_from_disk` directly, is stated directly in the class docstring: `cgse-core` (the package providing the Configuration Manager service) is an **optional** dependency of `cgse-common`. A Setup consumer — a device package, a project package — should be able to call `load_setup()` and get sensible behavior whether or not `cgse-core` happens to be installed in that environment:

```python
def _discover_providers(self):
    providers = []
    cgse_eps = HierarchicalEntryPoints("cgse.extension")
    for ep in cgse_eps.get_by_subgroup("setup_provider"):
        provider_class = ep.load()
        provider = provider_class()
        if isinstance(provider, SetupProvider):
            providers.append(provider)
            if provider.can_handle("core-services"):
                self._default_source = "core-services"
    providers.append(LocalSetupProvider())
    return providers
```

If `cgse-core` is installed, it registers itself as a `setup_provider` entry-point, gets discovered here, and — because it can handle `"core-services"` — becomes the default source. If it's *not* installed, no entry-point is found, `LocalSetupProvider` (which reads Setup files straight from disk, no server involved) is the only provider, and it remains the default. No `ImportError`, no conditional `if cgse_core_installed:` branching scattered through calling code — the optionality is resolved once, here, through the same entry-point mechanism that `Settings` uses for its own decentralization (Section 2.2). This is the second appearance of the same idea in this chapter: **entry-points are CGSE's general mechanism for "this package may or may not be present, and calling code shouldn't need to know."**

The `Protocol` used to define the contract:

```python
@runtime_checkable
class SetupProvider(Protocol):
    def load_setup(self, setup_id: int, **kwargs) -> Setup | None: ...
    def submit_setup(self, setup: Setup, description: str, **kwargs) -> str | None: ...
    def can_handle(self, source: str) -> bool: ...
```

is a structural (duck-typed) contract rather than an abstract base class that providers must inherit from. This matters because `cgse-core`'s provider class has no compile-time or install-time dependency on `cgse-common` beyond what it already needs — it doesn't need to import an ABC from `egse.setup` and inherit from it, it just needs to implement three methods with the right names. `@runtime_checkable` lets `isinstance(provider, SetupProvider)` actually work as a sanity check at discovery time despite this being structural typing, which is the one line of "belt and braces" defensiveness against a mis-registered entry-point pointing at something that isn't really a provider.

Built-in providers:

- **LocalSetupProvider** — loads from disk (`<PROJECT>_CONF_DATA_LOCATION`)
- **CoreServicesProvider** (if cgse-core is available) — loads from Configuration Manager

At startup, providers are discovered via HierarchicalEntryPoints. If any provider can handle `"core-services"`, it becomes the default source; otherwise, `"local"` is default.

```python
# Load from explicit source
setup = load_setup(setup_id=123, source="core-services")

# Load from local disk, bypassing default source
setup = load_setup(setup_id=123, from_disk=True)
```

#### 3.9 What `Setup` borrows from `navdict`, and what stays out of this book

`navdict` is its own small, mission-agnostic library with its own documentation, and it stays that way deliberately (see Section 3.2) — this book won't duplicate its internals. But a reader of `egse/setup.py` needs to recognize, at a glance, which names are `navdict`-provided versus CGSE-specific, so here's the short list of `NavigableDict`/`navdict` API that `Setup` leans on directly, with just enough of a note to keep reading without a side-trip:

- `NavigableDict` **(base class)** — gives `Setup` its dict-and-dot-notation navigation (`setup["gse"]["hexapod"]` and `setup.gse.hexapod` both work) and its YAML round-tripping (`from_yaml_file` / `to_yaml_file`, both overridden in `Setup` to add the `Setup`-specific header and top-level group handling — see Section 3.5).
- `get_private_attribute` **/** `set_private_attribute` **/** `has_private_attribute` — the mechanism `navdict` provides for attaching metadata to a node (like `_filename` or `_setup_id`) that isn't part of the actual configuration tree and won't show up when the Setup is printed, iterated, or serialized back to YAML. `Setup` uses this instead of ordinary attributes precisely because a `NavigableDict`'s `__getattr__` is already doing double duty for navigating configuration keys — private attributes are `navdict`'s way of keeping "data about the Setup" separate from "data in the Setup."
- `register_directive` **/ the** `class//`**,** `csv//`**,** `yaml//` **special-value family** — the plugin point `navdict` exposes for "some string values should be resolved into something else on access." `egse/setup.py` registers two CGSE-specific directives (`csv`, `pandas`) on top of whatever `navdict` ships by default (Section 3.3); it doesn't invent the mechanism.
- `get_resource_location` — resolves a relative resource path (used inside `_load_csv` and `_load_pandas`) against the location of the Setup file itself, so calibration files can be referenced relative to the Setup rather than with absolute paths. This is `navdict`'s answer to "where is 'here', when the YAML file describing 'here' can live at any site."
- `__rich__` — `NavigableDict` already knows how to render itself as a `rich.tree.Tree`; `Setup.__rich__` (Section 3.5's neighbor, just below it in the file) only adds two extra leaves (`Setup ID`, `Loaded from`) on top of what the base class already draws.

If you need to understand *how* dotted navigation, directive resolution, or private attributes are implemented under the hood, that's `navdict`'s own documentation's job, not this book's. What belongs here is only ever "which of these does `Setup` use, and why."

#### 3.10 Things we chose not to build into `Setup`

- **No schema validation.** Same reasoning as `Settings` (Section 2.7), amplified: Setup files are written by hand or generated by scripts across four different test sites (CSL, SRON, IAS, INTA), often under time pressure during a test campaign. A hard schema would either need to be extremely permissive (defeating the purpose) or would routinely block people from saving valid, needed configuration during a TVAC campaign at 2am. We rely on code review of Setup file templates and on the `Setup.compare()` diffing method (built on `DeepDiff`) for catching unintended changes between Setup versions, rather than on upfront validation.
- **No automatic migration between Setup schema versions.** If the shape of what lives under `gse.hexapod` changes, old Setup files don't get rewritten. This is intentional: old Setup files describe old test configurations that produced specific, already-analyzed data, and rewriting them after the fact would be rewriting history. `Setup.compare()` plus the `history` dict is the mechanism for understanding what changed and when, not a migration script.

---

### 4. Where this leaves the CONSTANT / Settings / Setup question, concretely

Bringing Section 1's table back with the mechanism now visible:

- A `CONSTANT` lives as a plain module-level name because nothing in `egse.settings` or `egse.setup` needs to know it exists — there's no loading, no caching, no site- or test-specificity. If you find yourself tempted to put a constant in `settings.yaml` "just in case it needs to change later," ask whether that possible future change is a site-configuration concern or a test-configuration concern — if it's neither, it's still a constant, just maybe one that deserves a comment explaining *why* it's fixed.
- A value belongs in `Settings` if it would be answered the same way regardless of which Setup is currently loaded — "what SSH port does this site's server use" doesn't change between Setup 27 and Setup 82. The entry-point-based, per-package contribution model exists because this kind of value is naturally owned by whichever package defines the thing it configures.
- A value belongs in `Setup` the moment the answer to "what's the right value" depends on *which test, which campaign, which physical configuration* you're talking about — and the moment traceability back to a specific configuration matters for interpreting data correctly.

This is also, not coincidentally, why `Settings.load()` is safe to call at import time (it's pure configuration, no side effects, cheap to cache) while `load_setup()` deliberately mutates a `ContextVar` and is never called implicitly at import time anywhere in the codebase — Setup loading is an explicit, meaningful event in a test script's life, not background plumbing.

---

### What this chapter's template gives the next chapter

For every module going forward, we'll follow this shape: the problem that forced the module to exist as a separate thing, the two or three decisions that would look arbitrary without explanation, the pieces of code that look like magic or dead weight until you know the story behind them, and — explicitly — what was deliberately left out and why. Performance notes appear where we actually measured something (Section 2.4's memoization, Section 3.3's repeated-access cost), not as a boilerplate section when there's nothing to say.

*(Next:* `egse/env.py`*, the module both* `Settings` *and* `Setup` *lean on for every environment-variable and file-location decision — a natural continuation, since half of this chapter's "why" answers bottomed out in "because of how* `env.py` *resolves* `<PROJECT>_...` *variables.")*

# Chapter Y — `egse/env.py`: Where "Where Does It Live" Gets Decided

## Why this chapter follows Settings & Setup

Chapter X kept saying some version of "the location comes from `egse.env`" — the local settings path, the configuration data location, the Setup files directory. This chapter is that other half: the module that turns two mandatory environment variables (`PROJECT`, `SITE_ID`) into every other location the CGSE needs, and the module that both `Settings` and `Setup` depend on for knowing *where on disk* to look.

If Chapter X answered "what kind of configuration is this," this chapter answers "and once we know that, where does it physically live, on this machine, at this site, for this project."

---

## 1. The problem: four test sites, one codebase, and no hardcoded paths allowed

CGSE runs at multiple test sites (CSL, SRON, IAS, INTA) across multiple projects (PLATO, ARIEL, CubeSpec). The data storage root, the configuration repository, the log file location — none of these can be a constant in code, because the same code runs unmodified at every site. But they also can't just be "read `os.environ` wherever you need it," because:

- every call site would need to remember the exact environment variable name, including the `<PROJECT>_` prefix convention,
- there'd be no single place to validate a location exists, or to warn when it doesn't, or to provide a sensible fallback when a more specific variable isn't set, and
- testing code that needs to simulate a different site or project would mean mutating `os.environ` directly and hoping nothing else read a stale cached value first.

`egse/env.py` exists to be the *only* place in the codebase that touches `os.environ` for these project/site variables. Everything else calls a named function (`get_conf_data_location()`, not `os.environ["PLATO_CONF_DATA_LOCATION"]`), and the module docstring says this outright: "Do not use the environment variables directly in your code."

---

## 2. The naming convention: two mandatory variables, five derived ones

```python
MANDATORY_ENVIRONMENT_VARIABLES = ["PROJECT", "SITE_ID"]

KNOWN_PROJECT_ENVIRONMENT_VARIABLES = [
    "DATA_STORAGE_LOCATION",
    "CONF_DATA_LOCATION",
    "CONF_REPO_LOCATION",
    "LOG_FILE_LOCATION",
    "LOCAL_SETTINGS",
]
```

Only `PROJECT` and `SITE_ID` are bare environment variable names. Everything else is a *suffix* that gets prefixed with whatever `PROJECT` currently resolves to — `PLATO_DATA_STORAGE_LOCATION`, `ARIEL_DATA_STORAGE_LOCATION`, and so on. This is the mechanism that lets the exact same source tree run for PLATO one day and ARIEL the next, on the same machine, with nothing but environment variables changing.

`KNOWN_PROJECT_ENVIRONMENT_VARIABLES` is a plain list, not a dict mapping name → getter function, and that's worth noting precisely because it's *not* used to auto-generate the getter/setter functions below — each of the five variables still has its own hand-written `get_X`/`set_X`/`get_X_env_name` trio (Section 4). The list is only used by `setup_env()` (Section 3) to know which variables to pre-populate into the internal cache at startup. A more "clever" version of this module could have generated all fifteen functions from the list via a loop or a factory. That wasn't done, and it's a reasonable choice: these functions differ in their fallback behavior (Section 4.2) enough that a generic factory would need per-variable special cases anyway, and fifteen short, individually readable, individually greppable functions are easier for someone unfamiliar with the module to step through in a debugger than one generic function parameterized five ways.

---

## 3. `setup_env()` and the `_Env` cache

### 3.1 Run-once initialization via `@static_vars`

```python
@static_vars(is_initialized=False)
def setup_env():
    global _env
    if setup_env.is_initialized:
        return
    ...
    setup_env.is_initialized = True
```

`setup_env()` is called at **import time**, unconditionally, at the bottom of the module (`setup_env()` appears right after the `_Env`/`NoValue` class definitions). It needs to be callable many times — every module that imports `egse.env` transitively triggers it — but it must only do its actual work (reading `os.environ`, populating the cache) once. `@static_vars` (from `egse.decorators`) attaches `is_initialized` as an attribute of the function itself rather than requiring a module-level global guard variable, which keeps the guard state physically next to the function it guards instead of floating separately at module scope.

This *looks* like it should be a job for `functools.lru_cache` on a zero-argument function, but `lru_cache` doesn't compose well here: `setup_env()` needs to be **re-runnable on demand**, not just memoized — see `env_var()` in Section 6, which explicitly resets `setup_env.is_initialized = False` and calls `setup_env()` again to force a fresh read of `os.environ` after temporarily changing it. A cached function can't be selectively invalidated from outside as cleanly as a plain attribute flag can.

### 3.2 Why mandatory variables warn instead of raising

```python
for name in MANDATORY_ENVIRONMENT_VARIABLES:
    try:
        _env.set(name, os.environ[name])
    except KeyError:
        logger.warning(f"The environment variable {name} is not set. ...")
        _env.set(name, NoValue())
```

Missing `PROJECT` or `SITE_ID` at *import* time doesn't raise — it logs a warning and stores a `NoValue()` sentinel. This is deliberate: `import egse.env` (directly, or transitively through almost every other `egse` module) happens in contexts where the environment genuinely isn't fully configured yet — a fresh Python REPL for interactive debugging, a unit test that sets up its own environment inside the test body, a `--help` invocation of some CLI tool that doesn't actually need a Setup. Raising at import time would make `import egse.env` itself fail in all of these legitimate cases. The error is deferred to the moment a caller actually asks for a value that depends on the missing variable — that's what `_check_no_value()` does (Section 4.1) — because that's the point where "the environment isn't configured" actually becomes a real problem, not just a hypothetical one.

### 3.3 The `_Env` class: a cache, not a re-implementation of `os.environ`

```python
class _Env:
    def __init__(self):
        self._env = {}

    def set(self, key, value):
        if value is None:
            if key in self._env:
                del self._env[key]
        else:
            self._env[key] = value

    def get(self, key) -> str:
        return self._env.get(key, NoValue())
```

`_Env` is a thin dict wrapper, and every public `get_X()` function in this module reads from `_env`, not from `os.environ` directly. Meanwhile every public `set_X()` function writes to **both** `os.environ[...]` and `_env`. That duplication is intentional, not an oversight:

- Writing to `os.environ` matters because child processes (a control server spawning a subprocess, a script launched via `subprocess.run`) inherit `os.environ`, not this module's private cache. If `set_conf_data_location()` only updated `_env`, a subprocess would never see the change.
- Reading from `_env` rather than `os.environ` directly is what makes `NoValue()` possible as a distinguishable "never set" sentinel (Section 3.4) — `os.environ.get(key)` would just return `None` for "not set," which collides with the `set_X(None)` convention for "explicitly clear this," described next.

### 3.4 `NoValue`: a sentinel that isn't `None`, on purpose

```python
class NoValue:
    def __eq__(self, other):
        if isinstance(other, NoValue):
            return True
        return False

    def __bool__(self):
        return False
```

Passing `None` to any `set_X()` function means "unset this variable" — that convention is used consistently (`set_data_storage_location(None)` deletes the environment variable). Given that, `None` can't *also* mean "this was never set" internally, because then a getter couldn't distinguish "the caller explicitly cleared this" from "nobody has touched this yet" — in practice those two states behave the same way downstream (both mean "no value available"), but conflating them in the *type* returned by `_env.get()` would make `_check_no_value()`'s job (raise a descriptive error) indistinguishable from a legitimate `None` flowing through some other code path. `NoValue` solves this by being a distinct type that is falsy (`__bool__` returns `False`, so `if not value:` checks still work intuitively) and that compares equal to *any other* `NoValue` instance (`__eq__`) — so code can write `value == NoValue()` without needing `_env` to hand back the exact same singleton object every time. It's a small, single-purpose sentinel type, and it's worth recognizing it as exactly that rather than a general-purpose null object — see Section 8 for a case where this equality contract was misapplied.

---

## 4. The get/set/env-name triads

### 4.1 The shape, using `DATA_STORAGE_LOCATION` as the model

```python
def get_data_storage_location_env_name() -> str:
    project = _env.get("PROJECT")
    return f"{project}_DATA_STORAGE_LOCATION"

def set_data_storage_location(location: str | Path | None):
    env_name = get_data_storage_location_env_name()
    if location is None:
        if env_name in os.environ:
            del os.environ[env_name]
        _env.set("DATA_STORAGE_LOCATION", None)
        return
    if not Path(location).expanduser().exists():
        warnings.warn(f"The location you provided ... doesn't exist: {location}.")
    os.environ[env_name] = str(location)
    _env.set("DATA_STORAGE_LOCATION", str(location))

def get_data_storage_location(site_id: str = None) -> str:
    project = _env.get("PROJECT")
    _check_no_value("PROJECT", project)
    site_id = site_id or _env.get("SITE_ID")
    _check_no_value("SITE_ID", site_id)
    data_root = _env.get("DATA_STORAGE_LOCATION")
    _check_no_value("DATA_STORAGE_LOCATION", data_root)
    data_root = data_root.rstrip("/")
    return data_root if data_root.endswith(site_id) else f"{data_root}/{site_id}"
```

Every one of the five known variables follows this exact three-function shape: `get_X_env_name()` (constructs the `<PROJECT>_X` string), `set_X()` (validates existence with a `warnings.warn` — never a hard failure, since you might legitimately be setting a location that doesn't exist yet, e.g. before calling `--mkdir` from the CLI), and `get_X()` (reads from `_env`, raises via `_check_no_value` if unavailable). Once you've read this one, `get_log_file_location`, `get_conf_data_location`, and their setters are the same shape with a different suffix, and don't need separate line-by-line treatment.

What *does* deserve attention is the tail end of `get_data_storage_location`: it silently appends `site_id` to the configured root if the root doesn't already end with it. **This makes the data storage location site-specific by construction** — you cannot get a `get_data_storage_location()` result that *isn't* scoped to a site, even if the environment variable was configured as a bare shared root. This is a guard against a real class of mistake: a shared root configured once and reused across two sites would silently mix data from CSL and SRON in the same folder tree.

### 4.2 Fallback chaining: only one location is really mandatory

`get_conf_data_location()` and `get_log_file_location()` don't require their own environment variable to be set at all — if `<PROJECT>_CONF_DATA_LOCATION` isn't set, the function falls back to `get_data_storage_location() + "/conf"`; similarly, log file location falls back to `.../log`. Only `<PROJECT>_DATA_STORAGE_LOCATION` (plus `PROJECT` and `SITE_ID` themselves) is truly mandatory — everything else has a sane, discoverable default derived from it.

This is a genuine usability decision for anyone setting up a new test site: you can get a working CGSE environment with three environment variables (`PROJECT`, `SITE_ID`, `<PROJECT>_DATA_STORAGE_LOCATION`) and only need to set the other four explicitly once you want to deviate from the convention — e.g. keeping the configuration repository somewhere outside the data storage tree entirely, which is the normal case in practice (see `<PROJECT>_CONF_REPO_LOCATION`, Section 5).

---

## 5. `CONF_REPO_LOCATION` is different in kind, not just in name

Unlike the other four, `CONF_REPO_LOCATION` points at a **git working copy** (`~/git/{project}-conf` per the CLI's own `--doc` help text), not at a generic data folder — it's the repository that `plato-common-egse`/CGSE configuration data is version-controlled in, separate from the `CONF_DATA_LOCATION` which is where Setup YAML files are actually read from day to day. In practice, `CONF_DATA_LOCATION` for a site can simply *be* a path inside the `CONF_REPO_LOCATION` working copy — the repo is where the Setup files live under version control, and the data location is how code finds them, and they often overlap on disk. `Setup.get_path_of_setup_file()` (Chapter X, Section 3) branches explicitly on `has_conf_repo_location()` to decide whether to go through the extra checks in `_check_conditions_for_get_path_of_setup_file` (verifying the repo folder and the site's `data/<site>/conf` subfolder both exist) versus falling back to a simpler `get_conf_data_location()`-based path.

Which brings us to the one thing in this module that doesn't behave the way its name promises.

---

## 6. A real bug, caught by reading the code and checking it: `has_conf_repo_location()`

```python
def has_conf_repo_location() -> bool:
    location = _env.get("CONF_REPO_LOCATION")
    return True if location in (None, NoValue) else False
```

Compare this to `get_conf_repo_location()`, twelve lines below it in the same file:

```python
def get_conf_repo_location() -> str | None:
    location = _env.get("CONF_REPO_LOCATION")
    if location in (None, NoValue()):
        ...
```

Spot the difference: `get_conf_repo_location` checks membership against `NoValue()` — an **instance**. `has_conf_repo_location` checks against `NoValue` — the **class itself**, no parentheses.

`NoValue.__eq__` (Section 3.4) only returns `True` when compared against another `NoValue` *instance* (`isinstance(other, NoValue)`); a class object is never an instance of itself, so `isinstance(NoValue, NoValue)` is `False`. Combined with the fact that `_env.get()` never actually returns Python's `None` (Section 3.3 — `_Env.set` deletes the key entirely rather than storing `None`), this means:

- when `CONF_REPO_LOCATION` is unset, `location` is a `NoValue()` **instance**, and `location in (None, NoValue)` evaluates `False` both times — the function returns `False`.
- when `CONF_REPO_LOCATION` **is** set to an actual path, `location` is a string, and `location in (None, NoValue)` is *also* `False` — the function **still returns** `False`.

I confirmed this by actually running it rather than just reading it — worth doing here, since a tempting reading of the code is "well, it probably works for the common case":

```
--- not set ---
has_conf_repo_location(): False
--- set to /tmp/someconf ---
has_conf_repo_location(): False
```

`has_conf_repo_location()` returns `False` unconditionally, regardless of whether the environment variable is set. It's only called from one place in the entire codebase — `egse/setup.py::get_path_of_setup_file()`:

```python
if not has_conf_repo_location():
    setup_location = Path(get_conf_data_location(site_id)).expanduser()
else:
    setup_location = _check_conditions_for_get_path_of_setup_file(site_id)
```

Because `has_conf_repo_location()` always returns `False`, `not has_conf_repo_location()` is always `True`, and the `else` branch — the one that validates the configuration repository actually exists and contains a `data/<site_id>/conf` folder before trusting it — is **dead code**, currently unreachable, at every site, regardless of whether `<PROJECT>_CONF_REPO_LOCATION` is configured. In practice this hasn't caused visible failures, because `get_conf_data_location()` (the branch that *does* always run) has its own reasonable fallback behavior (Section 4.2) — but it means the extra validation in `_check_conditions_for_get_path_of_setup_file` (checking the repo folder and the site subfolder both exist, and raising a clear `NotADirectoryError` naming the exact environment variable to fix) never actually protects anyone today.

This is exactly the kind of thing this book exists to surface: not a crash, not a test failure — years of correct-looking behavior on the common path, and a validation branch that quietly never runs. It's logged as **P-003** in the Pitfalls appendix with the fix (`NoValue` → `NoValue()`) and a note to add a regression test asserting `has_conf_repo_location()` toggles correctly, since the absence of exactly that test is *why* this survived.

---

## 7. `load_dotenv()`: a narrow, deliberate override

```python
def load_dotenv():
    """
    - set `CGSE_DOTENV_DISABLED=true` to disable loading the `.env` file
    - the `.env` file is searched for relative to the current working directory,
      unlike the default, which searches from the script location.
    """
    if not bool_env("CGSE_DOTENV_DISABLED") and (dotenv_location := find_dotenv(usecwd=True)):
        logger.debug(f"Loading environment variables from {dotenv_location}.")
        _load_dotenv(dotenv_path=dotenv_location)
```

Two small, specific deviations from the `python-dotenv` package's own default behavior, both called out explicitly in the docstring rather than left implicit:

- **Search from the current working directory (**`usecwd=True`**), not from the script's location.** CGSE test scripts and CLI tools get invoked from many different working directories — a test campaign's own working folder, a user's home directory, wherever a shell happens to be — and the relevant `.env` file (if any) is the one for *that* working context, not the one sitting next to wherever `egse/env.py` happens to be installed on disk.
- **An explicit escape hatch,** `CGSE_DOTENV_DISABLED`**.** Needed because automatic `.env` loading is exactly the kind of implicit behavior that's convenient during interactive development and actively unwanted during automated/CI test runs, where you want full control over the environment and no surprise values leaking in from a stray `.env` file in the checkout.

The docstring also states a rule that's easy to violate by accident: *"don't use* `load_dotenv` *in any modules, only in entrypoints and apps."* The reasoning, though not spelled out in the docstring itself, follows directly from Section 3.2's initialize-once design: calling `load_dotenv()` deep inside some unrelated library module would mean environment variables get mutated as a side effect of an unrelated import, potentially after `setup_env()` has already run and cached its snapshot — exactly the kind of hard-to-trace bug that "one designated place does initialization" is supposed to prevent.

---

## 8. `env_var()`: the context manager for tests

```python
@contextlib.contextmanager
def env_var(**kwargs: str | int | float | bool | None):
    saved_env = {}
    for k, v in kwargs.items():
        saved_env[k] = os.environ.get(k)
        if v is None:
            if k in os.environ:
                del os.environ[k]
        else:
            os.environ[k] = v

    setup_env.is_initialized = False
    setup_env()

    yield

    for k, v in saved_env.items():
        if v is None:
            if k in os.environ:
                del os.environ[k]
        else:
            os.environ[k] = v

    setup_env.is_initialized = False
    setup_env()
```

This is the mechanism that makes `Settings`/`Setup` unit tests practical (recall `test_settings.py` using `from egse.env import env_var`): temporarily override one or more environment variables, re-run `setup_env()` so the `_env` cache actually reflects the override (this is precisely why Section 3.1 needed `setup_env` to be forcibly re-runnable, not just idempotent-by-default), run the test body, then restore the previous values and re-sync the cache again on the way out — including when the test body raises, since this is a `contextlib.contextmanager` and the restoration code after `yield` still needs `try/finally` semantics to be fully safe. As written, an exception raised inside the `with env_var(...):` block will propagate *before* the restoration code after `yield` runs, since there's no `try/finally` wrapping the `yield` — a test that fails an assertion inside the context manager leaves the overridden environment variables in place for whatever runs next. This is a second, smaller pitfall in the same module as Section 6's; logged as **P-004**.

The docstring's one-line note — *"This context manager is different from the one in* `egse.system` *because of the CGSE environment changes"* — is a pointer worth taking seriously if you ever see both imported in the same file: they are not interchangeable, and reaching for the wrong one won't necessarily fail loudly.

---

## 9. `print_env()` and the `main()` CLI — diagnostics, briefly

`print_env()` is a small, side-effect-free reporting function: it prints the current value of every known location, wrapped in `warnings.catch_warnings()` with warnings suppressed, because its whole purpose is to be a calm diagnostic printout, not to also emit every warning that the getters would normally raise for unset optional variables. It's used exactly once outside this module, in `Setup._check_conditions_for_get_path_of_setup_file`, as context dumped just before raising a `LookupError` — genuinely useful there, since a confusing environment-variable error is much less frustrating with a full printout of what *is* set alongside it.

`main()` (reachable via `python -m egse.env`) is a more elaborate version of the same idea, aimed at a human setting up a new site: `--full` for a verbose dump including `sys.path` and `PATH`, `--doc` to print the human-readable explanation of each variable's purpose (the same text reproduced in Section 2's table, but written for a terminal rather than for this book), and `--mkdir` to actually create missing directories rather than just reporting them missing. The `check_env_dir`/`check_env_file` inner closures exist only to keep `main()`'s rich-formatted validation logic (relative-path warning, doesn't-exist warning, not-a-directory warning) from being repeated four times inline — routine code, no further comment needed.

One stray line at the bottom of `main()` is worth a one-line flag rather than a deep dive:

```python
# Do we still use these environment variables?
#
# PLATO_WORKDIR
# PLATO_COMMON_EGSE_PATH - YES
```

A leftover question-to-self from an earlier cleanup, never resolved. Logged as **P-005** — not because it's harmful, but because "do we still use X" comments left in shipped code are exactly the kind of thing a departing architect should resolve explicitly rather than leave as an unanswered question for whoever reads it next.

---

## What carries forward

The pattern from Chapter X holds: this module's "why" is almost entirely about *not* letting project/site variability leak into every call site, and about making the one unavoidable piece of global mutable state (`os.environ`) safe to reason about through a single cache with a real initialize-once lifecycle. The two real findings this chapter produced — `has_conf_repo_location`'s inverted-and-dead logic, and `env_var`'s missing `try/finally` — are exactly the kind of thing that "go deep on the tricky bits, verify rather than assume" is meant to catch, and both are now in the Pitfalls appendix with enough detail for a fix to be a quick, well-scoped PR.

*(Next: pivoting to* `cgse-core` *and the ZeroMQ-based control server architecture — a good moment to leave* `cgse-common`*, since everything from here on assumes the Settings/Setup/env foundation from this and the previous chapter, and starts building the client-server layer on top of it.)*

# Chapter Z — `control.py` and `proxy.py`: The Client/Server Foundation

## Why this chapter follows Settings, Setup, and env

Chapters X and Y covered *what* configuration exists and *where* it lives. This chapter is about what actually *uses* that configuration at runtime: every device in a Setup — a hexapod, a temperature controller, a power supply — is operated through a **Control Server** process that owns the physical connection to the hardware, and every test script or GUI that wants to talk to that device does so through a **Proxy** object that looks, to calling code, almost exactly like the device itself.

`egse/control.py` (in `cgse-core`) defines `ControlServer`, the abstract base every device control server inherits from. `egse/proxy.py` defines `Proxy` (and its relatives), the client-side counterpart. Between them, they define the one architectural pattern that essentially all of CGSE's runtime behavior is built on top of. Everything from here on — device drivers, the GUI clients, the Storage and Configuration Managers themselves (which are *also* `ControlServer` subclasses, Section 2) — assumes this chapter's vocabulary.

We're covering this pair before the newer `egse/registry` module deliberately (see the closing note): understanding the "classic" model here first is what will make the registry's added value legible later, rather than the other way around.

---

## 1. The problem: one process per device, many clients per process

A test facility has physical devices that can only safely be talked to by one thing at a time — you don't want a GUI and a test script independently opening a serial connection to the same hexapod. CGSE's answer is a strict separation:

- **One long-running server process per device (or per service)** owns the actual connection — serial port, Ethernet socket, GPIB, whatever the hardware needs — and is the only thing that ever talks to it directly.
- **Any number of client processes** — test scripts, GUIs, monitoring dashboards — talk to that server process over ZeroMQ, never to the device directly.

This buys the two things a shared, hands-on test facility actually needs: exclusivity (the device can't be commanded from two places at once and get confused) and location transparency (a test script doesn't care, and doesn't need to know, whether the hexapod control server is running on the same machine or across the lab network — it's just an endpoint string).

`ControlServer` is the shared machinery for the server side of that relationship, and it's reused far beyond individual device drivers: the **Storage Manager** and **Configuration Manager** — CGSE's own infrastructure services — are themselves `ControlServer` subclasses. The same request/reply, registration, and monitoring machinery that runs a hexapod control server runs the service that decides where housekeeping data gets written. That reuse is a strong signal of how central this one base class is.

---

## 2. Three sockets, three concerns

```python
self.dev_ctrl_service_sock = self.zcontext.socket(zmq.REP)   # "how are you, what are your ports"
self.dev_ctrl_mon_sock = self.zcontext.socket(zmq.PUB)        # periodic status/HK broadcast
self.dev_ctrl_cmd_sock = self.zcontext.socket(zmq.REP)        # the actual device commands
```

`ControlServer.__init__` sets up three distinct ZeroMQ sockets, each with a different pattern, because they solve three genuinely different problems:

- `dev_ctrl_cmd_sock` **(REQ/REP)** — the device commands themselves (`homing()`, `set_temperature()`, whatever the device protocol defines). REQ/REP is a strict synchronous request-then-reply pattern: exactly one command in flight at a time, which matches "the device can only do one thing at a time" from Section 1. This socket is left unbound in the base class — "the device protocol shall bind the socket in the subclass" (from the class docstring) — because binding requires knowing the commanding port, and that's something only a concrete subclass knows (`get_commanding_port()`, an abstract method, Section 4).
- `dev_ctrl_service_sock` **(REQ/REP)** — a *separate* request/reply channel for questions about the server itself rather than the device: "what's your monitoring port," "are you alive" (`Ping`), service-level configuration. Keeping this separate from the command socket means a client asking "are you there?" never has to compete with, or get queued behind, in-flight device commands — and vice versa, a slow device command can't make the server unable to answer a basic liveness check.
- `dev_ctrl_mon_sock` **(PUB)** — periodic status and housekeeping broadcast. PUB is the right pattern here specifically because monitoring is fundamentally different in shape from commanding: any number of listeners (a GUI, a logging process, a second GUI opened for debugging) can subscribe without the server needing to track who's listening or reply to each one individually — publish once, however many subscribers get it. Trying to serve monitoring data over a REQ/REP socket would mean the server tracking a client list and iterating it on every tick; PUB/SUB gets that fan-out from ZeroMQ for free.

### A self-flagged rough edge, worth reading in the source, not just this book

```python
self.poller.register(self.dev_ctrl_mon_sock, zmq.POLLIN)  # FIXME: I think this should not be registered
```

This is left in the source as-is, and it's worth explaining *why* it's suspicious rather than just repeating the FIXME: `dev_ctrl_mon_sock` is a `PUB` socket — it only ever sends, never receives — so registering it for `POLLIN` (readability) in the poller is very likely inert: ZeroMQ shouldn't report a `PUB` socket as readable in any normal flow, meaning this line probably does nothing harmful, but also nothing useful. It's flagged in the Pitfalls appendix (P-007) as "verify and remove if confirmed inert" rather than fixed outright in this book, since removing a poller registration in a 24/7 running control server is exactly the kind of change you want backed by a deliberate test and a real deployment window, not a silent edit while writing documentation.

---

## 3. `serve()`: a single-threaded reactor, not a thread per socket

```python
while True:
    self.signaling.process_pending_commands()
    socks = dict(self.poller.poll(50))  # timeout in milliseconds, do not block

    if self.dev_ctrl_cmd_sock in socks:
        self.device_protocol.execute()
    if self.dev_ctrl_service_sock in socks:
        self.service_protocol.execute()
    if self.event_subscription.socket in socks:
        self.event_subscription.handle_event()

    if time_in_ms() - last_time >= self.mon_delay:
        ...  # send monitoring status
    if time_in_ms() - last_time_hk >= self.hk_delay:
        ...  # collect + store + propagate housekeeping

    self.handle_scheduled_tasks()

    if self.interrupted or killer.term_signal_received:
        break
    if not self.device_protocol.is_alive():
        break
```

**Design decision — one thread, one loop, polling with a short timeout, rather than one thread per socket.** This is the single most consequential design choice in the whole class, and it's worth being explicit about the trade-off rather than treating it as an obvious default:

- **What it buys:** there is exactly one place where device state can change, so there's no need for locks around device access, no risk of two threads racing to send two ZeroMQ messages on the same socket at the same time (ZeroMQ sockets are famously not thread-safe to share), and the entire server's behavior for a given tick is describable as "poll, then handle whatever's ready, then check the clocks, then run scheduled tasks" — a sequential story a person can hold in their head and step through in a debugger.
- **What it costs, and why the docstring warns about it explicitly:** *"the* `callback` *function is executed in the* `serve()` *event loop, it shall not block!"* (from `schedule_task`'s docstring). Because everything happens on one thread, one slow operation — a device command that takes three seconds, a scheduled task that blocks on network I/O — stalls *every other concern* of this server for that same duration: no other commands get processed, no monitoring gets published, no housekeeping gets collected. This isn't a hidden gotcha; it's the direct, unavoidable consequence of choosing simplicity-through-single-threading, and it's the reason `schedule_task` exists at all as an escape hatch (Section 3.2) rather than calling blocking code directly from `before_serve` or a subclass override.
- **The 50ms poll timeout** is the tuning knob that balances "responsive to new events" against "don't spin the CPU for no reason." It's not configurable per-instance — it's a literal `50` in the `serve()` method — which is a reasonable simplification given that every control server has the same basic responsiveness requirement (sub-100ms reaction to a new command), and no server built on this base class so far has needed a different value.

### 3.1 Why `serve()` explicitly tells you Ctrl-C won't work

```python
except KeyboardInterrupt:
    self.logger.warning("Keyboard interrupt caught!")
    self.logger.warning(
        "The ControlServer can not be interrupted with CTRL-C, send a quit command to the server instead."
    )
    continue
```

This is a deliberate operational policy, not a missing feature. A control server owns a live connection to physical hardware — if a `KeyboardInterrupt` were allowed to unwind the Python stack at an arbitrary point inside `serve()`'s loop, it could do so in the middle of a device command, skip `after_serve()`, skip storage manager de-registration, and leave sockets and the device connection in an undefined state. The `quit()` method (Section 3.2) and the `interrupted` flag give the loop a chance to reach the `break` at the top of the loop body on its own terms, run the cleanup sequence at the bottom of `serve()` in order (unregister from storage manager, run `after_serve()`, close every socket explicitly, deregister from the service registry, terminate the ZeroMQ context), and exit cleanly. `SIGTERM` (via `killer.term_signal_received`, from `egse.system.SignalCatcher`) is still honored — this isn't "ignore all signals," it's specifically "don't let an interactive Ctrl-C interrupt at an arbitrary instruction," while still allowing an orchestrated shutdown signal to be checked at a safe point in the loop.

### 3.2 `schedule_task` / `handle_scheduled_tasks`: cooperative multitasking, explicitly

```python
def schedule_task(self, callback: Callable, after: float = 0.0, when: Callable = None):
    ...
    self.scheduled_tasks.append({"task": callback, "name": name, "after": scheduled_time, "when": when})
```

Given Section 3's single-thread constraint, `schedule_task` is how a device protocol defers work to a later tick of the loop instead of blocking the current one — explicitly documented as a deadlock-avoidance mechanism ("this function is intended to be used in order to prevent a deadlock"). `handle_scheduled_tasks` processes the list once per loop iteration: overdue and condition-satisfied tasks run immediately (wrapped in `try/except` so one failing task can't take down the server — it gets rescheduled instead of propagating), tasks whose `after` time hasn't arrived, or whose `when` condition isn't yet true, get put back on the list for the next check.

The reverse-then-pop-from-the-end pattern (`self.scheduled_tasks.reverse()` followed by `.pop()` in a `while` loop) is a slightly unusual way to process a list in original order while also being able to append newly-rescheduled tasks without disturbing the ones still to be processed in *this* pass — routine once you see the trick, not worth more than this one sentence.

---

## 4. The abstract contract: four methods, one theme

```python
@abc.abstractmethod
def get_communication_protocol(self) -> str: ...
@abc.abstractmethod
def get_commanding_port(self) -> int: ...
@abc.abstractmethod
def get_service_port(self) -> int: ...
@abc.abstractmethod
def get_monitoring_port(self) -> int: ...
```

Every concrete control server must supply its protocol and its three ports. This is a small, deliberately narrow abstract contract — `ControlServer` doesn't force subclasses to structure their device commanding any particular way, only to be explicit about *how to reach this server at all*. And this is exactly where Chapter X's `CONSTANT`/`Settings`/`Setup` framework earns its keep in practice: a concrete implementation (e.g. the PUNA hexapod control server) typically implements these four methods as one-liners returning module-level names loaded once from `Settings.load(...)` at import time —

```python
def get_commanding_port(self):
    return COMMANDING_PORT
```

— because a commanding port is a textbook `Settings` value by Chapter X's own rule of thumb: it's fixed per site/deployment, not per test, and changing it means editing a YAML file, not the code.

---

## 5. Registry integration and the `can_operate_without_registry()` policy hook

```python
def register_service(self, service_type: str) -> None:
    self._service_id = self.registry.register(
        name=self.service_name, host=get_host_ip() or "127.0.0.1",
        port=get_port_number(self.dev_ctrl_cmd_sock), service_type=self.service_type,
        metadata={"service_port": ..., "monitoring_port": ...},
    )
    if self._service_id:
        self.registry.start_heartbeat()
    elif self.can_operate_without_registry():
        self.logger.warning(f"Failed to register '{self.service_name}' ... Continuing because ...")
    else:
        raise ServiceRegistrationError(...)
```

```python
def can_operate_without_registry(self) -> bool:
    """... The default is strict: registration is required. Subclasses with explicitly
    configured, externally known endpoints may override this policy hook."""
    return False
```

By default, a control server that can't register itself with the service registry treats that as fatal (`ServiceRegistrationError`). But look at how a concrete hexapod control server overrides the hook:

```python
def can_operate_without_registry(self) -> bool:
    return bool(COMMANDING_PORT and SERVICE_PORT and MONITORING_PORT)
```

The override isn't "always tolerate a missing registry" — it's specifically "tolerate it *when this server's ports are statically configured in Settings rather than dynamically assigned* (a non-zero, explicitly set port, as opposed to `0`/OS-assigned)." That condition is the whole point: if a device's ports are fixed, well-known values from a YAML file, a client can in principle be told that endpoint directly and connect without ever asking the registry — so losing the registry is a degraded, not a broken, situation for that server. A server relying on OS-assigned (`0`) ports has no such fallback: without the registry, nobody could discover which port it ended up on, so for *that* server, a failed registration really is fatal. `can_operate_without_registry()` is a Template Method-style policy hook precisely because the right answer depends on a per-server fact (static vs. dynamic ports) that only the concrete subclass knows — `ControlServer` provides the mechanism (what to do with the answer) without hardcoding the policy (what the answer should be).

---

## 6. `is_control_server_active()`: a raw, low-level ping, separate from the Proxy

```python
def is_control_server_active(endpoint: str = None, timeout: float = 0.5) -> bool:
    ctx = zmq.Context.instance()
    socket = ctx.socket(zmq.REQ)
    socket.connect(endpoint)
    socket.send(pickle.dumps("Ping"))
    rlist, _, _ = zmq.select([socket], [], [], timeout=timeout)
    if socket in rlist:
        response = pickle.loads(socket.recv())
        return_code = response == "Pong"
    socket.close(linger=0)
    return return_code
```

This module-level function duplicates, in miniature, what `Proxy.ping()` does (Section 8) — open a `REQ` socket, send `"Ping"`, expect `"Pong"` back within a timeout. It exists as a standalone function, separate from any `Proxy` instance, specifically so that code that only wants to *check* whether something is listening at an endpoint doesn't need to construct a full `Proxy` object (which, per Section 8, immediately tries to load the entire command set on construction). It's a liveness check with no side effects and a short-lived, disposable socket — appropriate for, say, a startup script probing several endpoints in sequence before deciding what to launch.

---

## 7. Why `ControlServer` is not a `Proxy`, and what's shared instead

Notice `ControlServer` and `Proxy`/`BaseProxy` don't share a common base class — they're two independent hierarchies that happen to agree on a wire protocol (pickled Python objects over ZeroMQ `REQ`/`REP`, with the literal strings `"Ping"`/`"Pong"` as the handshake). What *is* shared is the vocabulary of `get_commanding_port` / `get_service_port` / `get_monitoring_port` — both sides need to agree on what a "commanding port" means, but the server's job (own the socket, bind, serve requests, own the device) and the client's job (connect, send, wait for reply, degrade gracefully on timeout) are different enough in shape that forcing them into one hierarchy would buy nothing.

---

## 8. `BaseProxy` and `Proxy`: the client side

### 8.1 Three sequential responsibilities, three classes

```python
class ControlServerConnectionInterface:      # the connect/disconnect/reconnect contract
class BaseProxy(ControlServerConnectionInterface):   # the actual ZeroMQ REQ socket + send()/ping()
class Proxy(BaseProxy, ControlServerConnectionInterface):  # + dynamic command loading
```

`ControlServerConnectionInterface` defines connection-lifecycle methods as `@dynamic_interface` stubs that raise `NotImplementedError` — this is the same `dynamic_interface` marker mechanism used elsewhere in device protocol classes (Section 8.3 touches why this matters for `DynamicProxy`): it marks a method as "this name is reserved for connection management and must not be silently overwritten by a dynamically loaded device command of the same name" — the docstring is explicit about this: the interface "guarantees that connection commands do not interfere with the commands defined in the `DeviceConnectionInterface` (which will be loaded from the control server)." `BaseProxy` implements the actual socket handling. `Proxy` adds the mechanism that makes a Proxy object able to grow new methods at runtime, one per command the connected control server actually offers (Section 8.4) — which is the single most distinctive thing about this class.

### 8.2 `send()`: retry, reconnect, and the meaning of "connected" in ZeroMQ

```python
def send(self, data, retries=REQUEST_RETRIES, timeout=None):
    ...
    if self._socket.closed:
        self.reconnect_cs()
    self._socket.send(pickle_string)
    while True:
        socks = dict(self._poller.poll(timeout_ms))
        if self._socket in socks and socks[self._socket] == zmq.POLLIN:
            return pickle.loads(self._socket.recv())
        else:
            self.disconnect_cs()
            if retries_left == 0:
                return Failure(f"Control Server seems to be off-line, abandoning ({data})")
            retries_left -= 1
            self.reconnect_cs()
            self._socket.send(pickle_string)
```

The comment right above this method's retry logic states the key fact that makes all of this necessary: *"we are using ZeroMQ where the connect method returns gracefully even when no server is available."* `zmq.Socket.connect()` doesn't fail just because nothing is listening yet — ZeroMQ handles reconnection at the transport level transparently, which means a `Proxy` can be constructed and appear to "connect" successfully even before its control server has started. The real liveness test only happens the first time you actually try to exchange a message and either get a reply or don't. That's why `send()`, not `connect_cs()`, is where the retry/reconnect logic lives: a timeout on `poll()` is ambiguous between "the server is slow" and "the server was never there," and the only sound response to that ambiguity, given ZeroMQ's REQ socket semantics (a REQ socket that has sent a request and not yet received a reply is in a strict alternating state and can't just resend on the same socket), is to close the socket, open a fresh one, and try again — which is exactly what `disconnect_cs()` / `reconnect_cs()` / re-`send()` does here.

`REQUEST_RETRIES = 0` as the module default is worth noting explicitly: **by default,** `send()` **does not retry at all** — one attempt, and a timeout becomes an immediate `Failure`. Retrying is opt-in per call (`send(data, retries=2)`), which keeps the default behavior predictable for callers that want to fail fast (e.g. an interactive GUI that shouldn't hang) while still allowing scripted code that expects transient network blips to ask for retries explicitly.

### 8.3 `DynamicProxy` vs `Proxy`, and an acknowledged bit of debt

```python
class DynamicProxy(BaseProxy, DynamicClientCommandMixin):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

# TODO (rik): remove all methods from Proxy that are also define in the BaseProxy

class Proxy(BaseProxy, ControlServerConnectionInterface):
    ...
```

`DynamicProxy` composes `BaseProxy` with a different mixin (`DynamicClientCommandMixin`, from `egse.mixin`) than `Proxy` does — a second, apparently parallel mechanism for building dynamically-commandable client objects, existing alongside `Proxy`'s own `load_commands()` approach (Section 8.4). The `# TODO (rik): remove all methods from Proxy that are also define in the BaseProxy` comment, left in the source, is a first-person acknowledgment (worth taking at face value, given its author) that `Proxy` accumulated some duplication with `BaseProxy` over time — methods like `get_monitoring_port`/`get_commanding_port`/`get_service_port` are defined on `BaseProxy` (Section 8.5) and `Proxy` inherits them without needing to redeclare anything, but the comment suggests that wasn't always tidy historically. This is flagged in the Pitfalls appendix (P-008) as a "confirm `DynamicProxy` vs `Proxy`'s actual relationship and either consolidate or document why both exist" item — exactly the kind of thing worth an explicit decision before a handover, rather than leaving two "the dynamic one" classes for a successor to have to reverse-engineer the difference between.

### 8.4 `load_commands()`: a Proxy that grows its own interface at runtime

```python
def _request_commands(self):
    response = self.send("send_commands")
    self._commands = response

def _add_commands(self):
    for key in self._commands:
        if hasattr(self, key):
            attribute = getattr(self, key)
            if isinstance(attribute, types.MethodType) and not hasattr(attribute, "__dynamic_interface"):
                self._logger.warning(f"... already has an attribute '{key}', not overwriting.")
                continue
        command = self._commands[key]
        new_method = MethodType(command.client_call, self)
        new_method = set_docstring(new_method, command)
        setattr(self, key, new_method)
```

This is the mechanism that makes `hexapod_proxy.homing()` work without a `homing` method ever being written by hand anywhere in `Proxy` or its subclasses: on construction (assuming the ping handshake succeeds), the `Proxy` asks its control server for its full command dictionary (`send("send_commands")` — the server side of this exchange is the device protocol's command registry, out of scope for this chapter, but the shape of what comes back is a dict of `Command` objects, covered when we reach `egse/command.py`), and for every command name that isn't already claimed by something else on the instance, it binds that command's `client_call` as a genuine bound method on `self` using `types.MethodType`. From the calling code's perspective, there is no visible difference between a "real" method and one of these dynamically attached ones — that's the whole point, and it's why device-specific Proxy subclasses across the codebase can stay almost empty: most of their public interface doesn't exist as written Python at all, it's populated at `__init__` time from whatever the connected control server reports it supports.

**The collision guard is the one piece of this worth reading closely.** If the Proxy already has an attribute of the given name, it's only overwritten if that attribute is *not* already a method carrying the `__dynamic_interface` marker (Section 8.1) — i.e., connection-management methods like `connect_cs` are protected from being silently replaced by a same-named device command, but a regular Python method a subclass author happened to define (without the marker) is also protected, with a warning logged rather than a silent, confusing override. This is the direct, practical payoff of the `ControlServerConnectionInterface`/`@dynamic_interface` split from Section 8.1 — it's not there to enable to `Proxy`'s connection lifecycle, it's there specifically to survive contact with `_add_commands()`.

### 8.5 `get_service_proxy()`: a Proxy that can hand you a different kind of Proxy

```python
def get_service_proxy(self):
    from egse.services import ServiceProxy  # prevent circular import problem
    transport, address, _ = split_address(self._endpoint)
    response = self.send("get_service_port")  # FIXME: Check if this is still returning the proper port
    ...
    return ServiceProxy(protocol=transport, hostname=address, port=response)
```

Recall Section 2's three sockets: a `Proxy` normally only ever talks to the *commanding* socket. `get_service_proxy()` is the bridge to the *service* socket — given a device Proxy already connected to a control server's commanding endpoint, this method asks that same server (over the commanding channel) what its service port is, then constructs and returns a brand-new `ServiceProxy` object pointed at that different port. This is a convenience specifically for code that's holding a device Proxy and suddenly needs to ask a service-level question (e.g. "what's your process status") without the caller having to independently know or reconstruct the service endpoint by hand. The inline `# FIXME: Check if this is still returning the proper port` is left as-is here too — noted in the Pitfalls appendix (P-008, same entry as the `DynamicProxy` question, since both point at the same general area of the file needing a maintenance pass) rather than resolved silently, since verifying it means actually exercising a live control server connection, not just reading source.

---

## 9. `self.service_id` vs `self._service_id`: a real, confirmed bug

```python
# in ControlServer.__init__:
self.service_id: str | None = None
"""The service ID of this Control Server, as registered in the Service Registry."""
```

```python
# in ControlServer.register_service:
self._service_id = self.registry.register(...)
...
if self._service_id:
    self.registry.start_heartbeat()
```

```python
# in ControlServer.deregister_service:
if self._service_id:
    self.registry.stop_heartbeat()
    self.registry.deregister()
```

Read closely: `__init__` declares and documents a **public** attribute, `self.service_id` (no leading underscore), explicitly described as "The service ID of this Control Server, as registered in the Service Registry." But `register_service()` — the only place that ever assigns a value after a successful registration — sets `self._service_id` (**with** a leading underscore), a *different* attribute that was never declared in `__init__` at all. `deregister_service()` and the `elif`/`if` checks inside `register_service()` all consistently read `self._service_id`, so the internal logic is self-consistent — but the publicly documented `self.service_id` attribute is never updated by anything, ever. It stays `None` for the entire lifetime of the object, even after a fully successful registration.

I didn't take this on faith — I checked how the same pattern is used elsewhere in `cgse-core`, since "service ID after registration" is a recurring need across several server classes in this package:

```
egse/registry/service.py:   self.service_id = await self.registry_client.register(...)
egse/metricshub/server.py:  self.service_id = await self.registry_client.register(...)
egse/notifyhub/server.py:   self.service_id = await self.registry_client.register(...)
egse/control.py:            self._service_id = self.registry.register(...)   # <- the odd one out
```

Every sibling server class in the package — the registry service base itself, the metrics hub server, the notify hub server — assigns the *public*, undocumented-underscore `self.service_id`. `ControlServer` is the only one using `self._service_id`. That consistency across three other classes makes it very likely that `self.service_id` was the intended name here too, and the leading underscore in `control.py` is a copy-paste-era typo that's simply never been exercised by anything that reads the public name.

**Practical consequence:** any code — a subclass, a monitoring tool, a test — that reads `control_server.service_id` expecting to find the registered ID (which is exactly what the attribute's own docstring promises) will always get `None`, silently, even when registration genuinely succeeded and the heartbeat is running. Only code that happens to know about the undocumented `_service_id` name gets the real value. This is logged as **P-006** in the appendix, flagged as the single highest-value fix to come out of this chapter — it's a one-line change (rename `_service_id` to `service_id` in `register_service`), but worth a deliberate look at every call site across the monorepo before touching it, precisely because "silently always `None`" is the kind of bug that other code may have already, unknowingly, worked around.

---

## What carries forward

Two real, evidence-checked findings came out of this chapter (P-006, the `service_id` mismatch, confirmed by cross-referencing three sibling classes; P-007, the self-flagged PUB-in-poller FIXME, formalized rather than silently fixed) plus one open question worth a deliberate decision (P-008, `DynamicProxy` vs `Proxy`'s relationship). None of them are described here in a way that tells a reader *how* to go looking for this class of bug in general — that's deliberately left implicit in the "read closely, then verify against siblings" method itself, which is the real takeaway for whoever inherits this codebase: when a name is *this* close to another name doing the same conceptual job elsewhere, it's worth five minutes with grep before trusting either one.

*(Next:* `egse/protocol.py`*,* `egse/command.py`*, and* `egse/mixin.py` *— the pieces that define what a "command" actually is, how* `Command.client_call` *turns into a real ZeroMQ round trip, and how a device protocol class turns a* `Command` *registry into the dictionary that* `Proxy._request_commands()` *receives. Then* `egse/dummy.py` *as the smallest complete worked example tying control.py, proxy.py, command.py, and protocol.py together end to end — before finally turning to* `egse/registry/` *and what problem it was introduced to solve on top of the static-port model covered here.)*
