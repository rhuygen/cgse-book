# Appendix — Pitfalls & Cleanup Backlog

This appendix collects small, low-urgency issues surfaced while writing the book: things that work correctly today but are worth revisiting opportunistically — duplicated logic, sharp edges that cost someone real debugging time once, conventions that are easy to violate by accident. Nothing here blocks anything; it's a backlog, not a bug list. Each entry names the module, states the issue in one or two sentences, and notes the fix scope so a future maintainer (or Rik, before he leaves) can judge in five seconds whether it's worth picking up.

Entries are grouped by the chapter they surfaced in and listed in the order they were found.

---- 

## From: Settings & Setup (Chapter X)

### P-001 — Duplicated Setup-filename regex
**Module:** `egse/setup.py`
**Where:** `_parse_filename_for_setup_id()` and `disentangle_filename()`
**Issue:** Both functions apply essentially the same regex (`SETUP_(\w+)_([\d]{5})_([\d]{6})_([\d]{6})\.yaml`) against a Setup filename, one returning just the setup\_id, the other returning `(site_id, setup_id)`. A single parsing function returning a small dataclass/namedtuple (or `None`) would remove the duplication and the risk of the two regexes drifting apart if the filename convention ever changes.
**Fix scope:** Small, self-contained, no API-visible change needed if `disentangle_filename` and `_parse_filename_for_setup_id` keep their current signatures as thin wrappers.
**Risk of leaving as-is:** Low. The convention is stable and well-tested; the only real risk is someone changing the format string in one place and not the other.

### P-002 — Silent last-writer-wins on duplicate Settings group names
**Module:** `egse/settings.py`
**Where:** `load_global_settings()`, via `recursive_dict_update`
**Issue:** If two installed packages both define a top-level group with the same name in their `settings.yaml` (e.g. two device packages both using `DEVICE` as a group name), the second one loaded silently overwrites keys from the first, with no warning. The docstring tells authors to avoid this, but nothing enforces it, and entry-point iteration order isn't obviously deterministic across environments.
**Fix scope:** Medium. A cheap improvement: log a warning when `recursive_dict_update` is about to overwrite an existing top-level group key from a *different* entry-point than the one that first defined it. Doesn't need to become a hard error — just needs to stop being silent.
**Risk of leaving as-is:** Low today (hasn't caused a real incident yet), but grows as more third-party/device packages are added to the ecosystem outside the core team's direct review.

---- 

## From: env.py (Chapter Y)

### P-003 — `has_conf_repo_location()` always returns `False` (confirmed by running it)
**Module:** `egse/env.py`
**Where:** `has_conf_repo_location()`
**Issue:** The function compares `_env.get("CONF_REPO_LOCATION")` against `(None, NoValue)` — the `NoValue` **class**, not a `NoValue()` **instance**. Because `NoValue.__eq__` only matches actual `NoValue` instances, and `_env.get()` never returns Python's literal `None` (unset values are stored as `NoValue()` instances, see `_Env.set`), the membership test evaluates `False` in every case — whether the variable is unset or set to a real path. Empirically verified: the function returns `False` both before and after calling `set_conf_repo_location("/some/real/path")`.
**Downstream effect:** Its only call site, `egse/setup.py::get_path_of_setup_file()`, branches on `if not has_conf_repo_location():` — since the function always returns `False`, this condition is always `True`, and the `else` branch (`_check_conditions_for_get_path_of_setup_file`, which validates the repo folder and the site's `data/<site_id>/conf` subfolder both exist before trusting them) is dead code at every site, regardless of configuration.
**Fix scope:** Trivial — change `NoValue` to `NoValue()` on the one line. Add a regression test asserting `has_conf_repo_location()` toggles `True`/`False` correctly around a `set_conf_repo_location` call, since the lack of exactly that test is why this went unnoticed.
**Risk of leaving as-is:** Low-to-medium. No crash, no visibly wrong output today, because the "always take the simpler branch" fallback (`get_conf_data_location()`-based path) happens to produce reasonable results in practice. The risk is that the intended extra validation (clear, named error messages when the conf-repo env var is misconfigured) silently never runs, so a genuinely misconfigured `CONF_REPO_LOCATION` fails later and less clearly than it's designed to.

### P-004 — `env_var()` context manager doesn't restore state on exception
**Module:** `egse/env.py`
**Where:** `env_var()`
**Issue:** The restoration code that runs after `yield` (putting back the previous environment variable values and re-running `setup_env()`) is not wrapped in `try/finally`. If the code inside a `with env_var(...):` block raises — e.g. a failed test assertion — the restoration never runs, and the overridden environment variables leak into whatever runs next in the same process (notably: the rest of a test session).
**Fix scope:** Small — wrap the body from `yield` onward (or the whole function body after the initial override) in `try/finally`.
**Risk of leaving as-is:** Medium in a test suite: a single failing test using `env_var(...)` can cause confusing, unrelated failures in tests that run afterward in the same process, because they silently inherit the wrong `PROJECT`/`SITE_ID`/etc.

### P-005 — Unresolved "do we still use these" comment in `env.py::main()`
**Module:** `egse/env.py`
**Where:** end of `main()`
**Issue:** A leftover comment — `# Do we still use these environment variables? PLATO_WORKDIR / PLATO_COMMON_EGSE_PATH - YES` — was never resolved or removed.
**Fix scope:** Trivial — either confirm and document `PLATO_COMMON_EGSE_PATH`'s status properly (or add it to `KNOWN_PROJECT_ENVIRONMENT_VARIABLES` if it's genuinely still used) and delete the comment, or confirm `PLATO_WORKDIR` is dead and remove any remaining references to it elsewhere.
**Risk of leaving as-is:** Very low — cosmetic/documentation debt only. Listed mainly because "unresolved question left in shipped code" is exactly the category of thing worth clearing out before a knowledge handover, even when harmless.

---- 


## From: control.py & proxy.py (Chapter Z)

### P-006 — `ControlServer.service_id` is never actually set (confirmed against sibling classes)
**Module:** `egse/control.py`
**Where:** `__init__` (declares `self.service_id`) vs. `register_service()` / `deregister_service()` (both use `self._service_id`)
**Issue:** `__init__` declares and documents a public attribute `self.service_id` ("The service ID of this Control Server, as registered in the Service Registry."). `register_service()` — the only place that assigns a value after a successful registration — sets `self._service_id` instead, a different, never-declared-in-`__init__` attribute. `deregister_service()` reads `self._service_id` too, so internal logic is self-consistent, but the documented public attribute is never updated and stays `None` for the object's entire lifetime, even after successful registration.
**Evidence:** Cross-checked against three sibling classes in the same package that implement the same "register with the service registry" pattern — `egse/registry/service.py`, `egse/metricshub/server.py`, `egse/notifyhub/server.py` — all three consistently assign `self.service_id` (no underscore). `control.py` is the only one using `self._service_id`, strongly suggesting a copy-paste-era typo rather than an intentional distinction.
**Fix scope:** Small in isolation (rename `_service_id` → `service_id` in `register_service` and `deregister_service`), but audit every call site across the monorepo first — code may have already adapted to reading the (currently always-`None`) public attribute or the private one, and both need to end up correct after the rename.
**Risk of leaving as-is:** Medium. Anyone relying on the documented `service_id` attribute (subclass, monitoring tool, future test) silently gets `None` even when registration succeeded. This is the highest-value fix identified so far in the book.

### P-007 — Monitoring `PUB` socket registered in the poller (self-flagged in source)
**Module:** `egse/control.py`
**Where:** `ControlServer.__init__`, the `self.poller.register(self.dev_ctrl_mon_sock, zmq.POLLIN)` line
**Issue:** The line carries its own inline comment: `# FIXME: I think this should not be registered`. `dev_ctrl_mon_sock` is a `PUB` socket (send-only); registering it for `POLLIN` (readability) is very likely inert, since ZeroMQ shouldn't report a `PUB` socket as readable in normal use.
**Fix scope:** Small, but should be preceded by verifying it's genuinely inert (add a log line or test asserting this socket never shows up in `socks` during normal operation) before removing the registration from a 24/7-running server class.
**Risk of leaving as-is:** Very low — likely harmless dead registration, not a behavioral bug. Kept in the backlog mainly so the original author's own flag doesn't get lost.

### P-008 — `DynamicProxy` vs `Proxy`: unclear relationship, acknowledged TODO
**Module:** `egse/proxy.py`
**Where:** `DynamicProxy` class (uses `DynamicClientCommandMixin`) vs. `Proxy` class (uses its own `load_commands()`/`_add_commands()` mechanism); also the adjacent `# TODO (rik): remove all methods from Proxy that are also define in the BaseProxy` comment, and the `# FIXME: Check if this is still returning the proper port` in `get_service_proxy()`.
**Issue:** Two apparently parallel mechanisms exist for building a dynamically-commandable client object (`Proxy`'s `load_commands()` vs. `DynamicProxy`'s `DynamicClientCommandMixin`), with an author-acknowledged TODO suggesting some historical duplication between `Proxy` and `BaseProxy` was never fully cleaned up.
**Fix scope:** Needs a decision, not just a patch: confirm whether `DynamicProxy` is legacy, experimental, or intentionally different in scope from `Proxy`, then either consolidate, deprecate one, or document the distinction clearly in both classes' docstrings. Separately, verify the `get_service_proxy()` port-forwarding FIXME against a live control server.
**Risk of leaving as-is:** Low day-to-day (both classes work), but high risk for a successor maintainer trying to decide which one to subclass for a new device — exactly the kind of ambiguity this book is meant to resolve while the reasoning is still available.

---- 
