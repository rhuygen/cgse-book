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
