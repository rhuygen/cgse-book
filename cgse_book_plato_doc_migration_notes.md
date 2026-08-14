# Migration Notes: `plato-cgse-doc` Developer Manual → `cgse-book`

Analysis of `https://github.com/IvS-KULeuven/plato-cgse-doc`, specifically its Developer Manual
(`src/develop/*.adoc`, ~40 files, master doc at `src/develop/developer-manual.adoc`), for content
worth migrating into this book. Rik Huygen is the author of both documents, so reuse/adaptation is
not a copyright concern — the question is only relevance, staleness, and where it fits our chapter
structure.

Repo was cloned locally to `~/github/plato-cgse-doc` for this analysis (it wasn't present alongside
`~/github/cgse` before). All Python API references below were spot-checked against the current
`~/github/cgse` monorepo source (see "Verified against current source" markers) — but re-verify
again at actual drafting time, since that checkout can drift further between now and then, per this
project's own source-of-truth discipline.

**Bottom line:** the old manual's `cgse-common`/`cgse-core` chapters (Part I "Development Notions"
and Part II "Core Concepts") are the productive vein — mostly short, TBW-heavy stubs, but several
contain concrete, still-accurate code walkthroughs that our already-drafted chapters (Ch. 4–6) either
don't have yet or only partially cover. Part III (Device Commanding) and most of Part IV/V/VI are
PLATO-mission-specific (SUT, SpaceWire, F-FEE/N-FEE, data dumper, OGSE) and fall squarely inside this
book's already-declared "deliberately out of scope for now" list — noted below for completeness, not
recommended for migration yet. Two corrections from the first pass, both confirmed against current
source and folded in below: the Grafana/Prometheus metrics material (§2) is superseded — the
time-series backend is InfluxDB/QuestDB now, not Prometheus — and the GUI Executor material (§6) isn't
a mission-specific exclusion at all; it's an externalized, `navdict`-style standalone package
(https://github.com/IvS-KULeuven/gui-executor), currently unreferenced anywhere in the `cgse` repo.

---

## 1. Genuinely new content for chapters we've already drafted

These are gaps or supplementary material for Ch. 4 (Settings/Setup) and Ch. 6 (control.py/proxy.py)
— chapters that already exist and are substantially more rigorous than the old manual, but the old
manual has a few concrete details/examples not yet in ours.

### Ch. 4 — Settings and Setup (`01-settings-and-setup.adoc`)

- **`get_setup()` vs `load_setup()` vs `list_setups()` distinction** (source: `global-state.adoc`,
  `the-setup.adoc`). `get_setup(id)` retrieves a Setup from the configuration manager *without*
  replacing the currently active one; `load_setup()` retrieves *and* replaces the active Setup.
  `list_setups()` prints/returns the available Setups. All three still exist as module-level
  functions in `egse/setup.py` (**verified**: `get_setup`, `load_setup`, `submit_setup` at
  `libs/cgse-common/src/egse/setup.py` lines 589/829/844; `list_setups` lives server-side in
  `libs/cgse-core/src/egse/_setup_core.py` and `egse/confman/__init__.py`). Our Ch. 4 covers
  `submit_setup_to_disk` and the submit/load asymmetry in depth but doesn't currently spell out the
  `get_setup`/`load_setup` distinction explicitly — worth a short addition.
- **Setup dict-key caveat** (source: `caveats.adoc`): keys containing spaces or special characters
  are legal in the underlying dict and survive `s["a key with spaces"] = 42`, but break dot-notation
  access (`SyntaxError`). Small, concrete, worth either a caveat callout in Ch. 4 or a Pitfalls
  appendix entry (it's a footgun in the `navdict`-based design, not a bug — still worth flagging for
  the next person who hits it).
- **`to_yaml_file()` for local/temporary Setup snapshots** (source: `the-setup.adoc`) — already
  referenced in our Ch. 4 as part of `NavigableDict`'s YAML round-tripping, but the old manual has a
  cleaner standalone usage example (`setup.to_yaml_file(filename="SETUP-42-FIXED.yaml")`) that could
  supplement the existing prose if an example is wanted there.
- **Multiple identical devices in one Setup** (source: `control-server.adoc`, section "Create
  multiple control servers for identical devices") — a concrete worked example (AEU Test EGSE's
  6 PSUs) showing `device_args` used to pass positional constructor arguments to a `Proxy`/`Controller`
  class resolved via `class//`, distinguishing PSU 2 from PSU 1 at the same Settings-defined port
  family. This is a good real-world illustration of the `class//` directive already covered in Ch. 4
  — worth folding in as a worked example if the chapter is ever revisited, though not strictly a gap
  since `class//` itself is already documented.
- **`factory//` directive already covered — not a gap.** The old manual has a good worked example
  (`ControllerFactory` for PUNA/ZONDA hexapods, deciding PUNA-Alpha vs PUNA-Alpha+ based on
  `device_id`) that is *more concrete* than what's currently in Ch. 4 (which documents `factory//`
  but with a smaller example). Optional upgrade, not a gap.

### Ch. 6 — control.py and proxy.py (`03-control-and-proxy.adoc`)

- **The Connection Interface pattern** (source: `device-interface.adoc`, "The Connection Interface").
  This describes two related-but-distinct interfaces that our Ch. 6 touches only partially:
  1. **Device connection interface** — `connect()` / `disconnect()` / `is_connected()`, implemented
     by device `Controller` classes, simulators, and `Proxy` subclasses alike, so all three present a
     uniform connection API regardless of what's on the other end.
  2. **`ControlServerConnectionInterface`** — `connect_cs()` / `disconnect_cs()` / `reconnect_cs()` /
     `reset_cs_connection()` / `is_cs_connected()`, implemented once in the `Proxy` base class
     (**verified**: `class ControlServerConnectionInterface` at
     `libs/cgse-core/src/egse/proxy.py:39`). Ch. 6 already documents `reconnect_cs()`/`disconnect_cs()`
     as part of the `send()` retry logic, but doesn't currently name or describe
     `ControlServerConnectionInterface` as its own contract, nor `reset_cs_connection()` /
     `is_cs_connected()`. Worth a short addition — this is the cleanest available explanation of *why*
     `Proxy` has two separate connection vocabularies (one for the device, one for the control server).
  - The device-side half of this (`connect()`/`disconnect()`/`is_connected()` on `Controller` classes)
    is arguably a better fit for the future Ch. 11 (device communication) than Ch. 6, since Ch. 6 is
    scoped to `control.py`/`proxy.py` specifically, not `device.py`. Worth deciding when that chapter
    is drafted.
- **Response / Failure / Success / Message classes** (source: `responses.adoc`). Short section
  explaining that `control.py`'s command responses use a `Response` base class with `Success`,
  `Failure`, and `Message` subclasses so that exceptions on the server side can propagate to the
  client as data rather than raising remotely. Our Ch. 6 already uses `Failure` in its retry-logic
  walkthrough but doesn't describe the `Response`/`Success`/`Message` family as a design decision in
  its own right. **Verified current**: `libs/cgse-common/src/egse/response.py` — `Response` (17),
  `Failure(Response, Exception)` (38), `Success(Response)` (72), `Message(Response)` (93). This module
  is also explicitly listed as in-scope for the planned Ch. 14 "Messaging primitives"
  (`response.py`) — so this content's real home is Ch. 14, with Ch. 6 only needing a cross-reference
  update (it already uses `Failure` without introducing it).
- **Service class commands** (source: `services.adoc`) — `get_service_proxy()` is already covered in
  Ch. 6, but the specific commands available through it are not: `get_process_status()` (returns PID,
  uptime, RSS/USS memory, CPU%, etc.), `set_hk_frequency(freq)`, `set_monitoring_frequency(freq)`, with
  the concrete caveat that the applied delay is never shorter than the average execution time of
  `get_housekeeping()`/`get_status()` plus ~200ms overhead — a good, concrete constraint worth
  preserving. **Verified current**: `set_monitoring_frequency`, `set_hk_frequency`,
  `get_process_status` all present in `libs/cgse-core/src/egse/services.py` (~194–202) and
  `get_process_status` also in `libs/cgse-core/src/egse/control.py:307`. Natural fit either as a Ch. 6
  supplement or as part of the planned Ch. 24 (`egse/services.py`).

---

## 2. Strong raw material for chapters that are still TBW

This is the highest-value bucket — these old-manual sections are close to complete, still describe
live code, and map directly onto chapters in our skeleton that haven't been drafted yet.

### Ch. 8 — `egse/mixin.py` (currently TBW)

- **`dynamic-commanding.adoc`** (210 lines) is essentially a full draft of this chapter's core
  material already. It walks through both the *old* `@dynamic_interface` decorator mechanism and its
  successor `@dynamic_command`, including:
  - why the interface/proxy split exists (define the command interface once, implement client and
    server sides without duplicating work),
  - the internals of `_add_commands()` and `MethodType()`-based method binding — *why* `setattr`
    can't just do a plain assignment,
  - the full `client_call()` → `CommandExecution` → server `Protocol.execute()` → `server_call()`
    round trip,
  - the concrete problem `@dynamic_command` was built to solve (a `Proxy` is non-functional until it's
    contacted its control server at least once under `@dynamic_interface`; `@dynamic_command` proxies
    work immediately and reconnect gracefully),
  - a full before/after worked example (`HuberSMC9300` stage controller) showing a method migrated
    from `@dynamic_interface` to `@dynamic_command`, including `cmd_string` templating
    (`$`-substitution vs `.format()`), `process_cmd_string`, `process_response`, `pre_cmd`/`post_cmd`
    hooks, and the requirement that `Controller` classes add `DynamicCommandMixin` and `Proxy`
    subclasses switch from `Proxy` to `DynamicProxy`.
  **Verified current**: `class DynamicCommandMixin` at `libs/cgse-core/src/egse/mixin.py:236`,
  `class DynamicClientCommandMixin` at line 460 (note: mixin.py is `cgse-core`, not `cgse-common` —
  worth double-checking against our skeleton's module list, which doesn't currently specify the
  package). This single old-manual file could cut most of the research time for drafting Ch. 8.
  Directly relevant to Ch. 6's `DynamicProxy`-vs-`Proxy` open question (Pitfalls P-008) too — this
  material explains the *historical reason* the two exist (successive designs, not duplication),
  which is exactly the kind of context P-008 is asking someone to go find.

### Ch. 21 — Log Server and Notifications (`egse/listener.py`, currently TBW)

- **`notifications.adoc`** (222 lines) is a near-complete design writeup of the Event/Listener
  pattern used for control-server-to-control-server notifications (e.g., "a new Setup was loaded" —
  notify the storage manager). Covers:
  - `Event`, `EventInterface.handle_event(event)`, `notify_listeners()`, `register_as_listener()` /
    `unregister_as_listener()`, `add_listener()` / `remove_listener()` / `get_listener_names()`,
  - why it's built on ZeroMQ messaging rather than a plain producer/consumer method call,
  - the deadlock hazard this pattern is designed around: a listener that needs to fetch fresh state
    from the very control server that just notified it (e.g., re-fetching the new Setup) can't do that
    synchronously inside `handle_event()` without risking a mutual-wait deadlock, hence the explicit
    tie-in to **scheduled tasks** — which our Ch. 6 *already documents* in isolation
    (`schedule_task`/`handle_scheduled_tasks` as cooperative multitasking) without yet explaining this
    specific motivating use case. This is a good concrete example to backfill into Ch. 6's existing
    section or forward-reference from there into Ch. 21.
  **Verified current**: `class EventInterface`, `handle_event`, `notify_listeners` all present in
  `libs/cgse-core/src/egse/listener.py` (lines 56, 68, 151). Also worth noting:
  `libs/cgse-core/src/egse/storage/storage_cs.py` has a `handle_event_new_setup` method — the
  configuration-manager/storage-manager example from the old doc is still a live, findable example in
  current code, not just historical.
- The chapter's worked "how to add event handling to a control server" walkthrough (register in
  `__init__`, deregister in `after_serve`, implement `handle_event`) is a reusable template structure
  for whatever worked example Ch. 21 ends up using.

### Ch. 13 — Persistence, Housekeeping, Metrics (`metrics.py`, `plugins/metrics/*`, currently TBW)

- **Correction (per author, 2026-08-14): `grafana-prometheus.adoc` is superseded, not migratable
  as written.** The old file describes Prometheus/Grafana as the metrics *storage and visualization*
  stack — a pull-based model where Prometheus scrapes each control server's HTTP endpoint. That is no
  longer the architecture: the time-series backend is now **InfluxDB or (preferably) QuestDB**.
  **Verified against current source**: `libs/cgse-common/src/egse/metrics.py` defines a
  `TimeSeriesRepository` protocol and `get_metrics_repo(plugin_name, config)` factory, with concrete
  backends as entry-point plugins at `libs/cgse-common/src/egse/plugins/metrics/{influxdb,questdb,
  duckdb}.py`, plus a shared `line_protocol.py` helper ("Helpers for converting metric payloads to
  Influx/QuestDB line protocol"). `prometheus_client` is still a declared dependency
  (`libs/cgse-common/pyproject.toml`) and `Gauge` is still imported in `metrics.py`, so Prometheus's
  *client-side metric types* (or at least the `Gauge` shape) may still be in use somewhere in the
  data model — but the "Setup Prometheus" / scrape-based framing, and the three-timestamp-strategy
  discussion built on top of it, describe a design that has moved on. **Do not use this file's
  Prometheus/Grafana framing when drafting Ch. 13** — draft directly from `metrics.py` and
  `plugins/metrics/*` instead. The underlying *question* the old doc was answering (how to timestamp a
  metric: device-supplied vs. retrieval-time vs. ingestion-time) may still be a live design question
  worth asking about the current `DataPoint`/`MeasurementSchema` model, but the answer needs to be
  re-derived from current code, not carried over.
- This is a good general reminder for this whole migration exercise: **the `cgse` repo is the only
  authoritative source**; the old manual is a starting point for what topics to cover, not for what
  the current design actually is. Metrics/storage is the module where the two diverged the most
  amongst everything reviewed here — treat any other old-manual section describing infrastructure
  choices (storage backends, protocols, service topology) with the same suspicion until checked
  against current code.

### Ch. 12 — Runtime and Resilience (`system.py`, `process.py`, currently TBW)

- **`timestamps.adoc`** — the `format_datetime()` function from `egse.system`, its default UTC output
  format (`YYYY-mm-ddTHH:MM:SS.μs+0000`), its round-trip parse format string, and the relative-date
  argument form (`format_datetime('yesterday')`). **Verified current**:
  `def format_datetime(...)` at `libs/cgse-common/src/egse/system.py:390`.
- **`essential-toolkit.adoc`** — confirms `SubProcess` and `ProcessStatus` (both TBW stubs in the old
  doc, so no prose to reuse, but confirms these are the right classes to anchor this chapter's
  `process.py` coverage on). **Verified current**: `class ProcessStatus` at
  `libs/cgse-common/src/egse/process.py:120`, `class SubProcess` at line 264.

### Ch. 19 — Configuration Manager (currently TBW)

- **`confman.adoc`** is a 7-line stub, but its scope bullet list (GlobalState / Setup / Observation
  concept) confirms the chapter's intended boundary — matches our skeleton's scope of `egse/confman/*`
  well; GlobalState itself is a `camtest` (test-scripts) concept and correctly stays out per our
  existing out-of-scope decision on mission/test-script code, but the Setup-serving role of the
  configuration manager (the actual server behind `get_setup`/`load_setup`/`submit_setup`/
  `list_setups`) is exactly this chapter's subject. **Verified current**: all four functions live
  server-side in `libs/cgse-core/src/egse/confman/__init__.py` (methods at lines 532/536/544 and
  722/779/846 — there appear to be two implementations/classes in that file worth understanding when
  this chapter is drafted).
- **`the-setup.adoc`**'s closing warning is a good design-rationale nugget for this chapter: prefer
  passing `setup` as an explicit function argument over reaching for the current-Setup global/context
  state, "only when there is no other means to get hold of the current Setup." Ties directly into our
  book's established Settings/Setup framework from Ch. 4.

### Ch. 20 — Process Manager (currently TBW)

- **`procman.adoc`** stub frames the chapter's core design question well: the process manager needs
  to know which device control servers exist and how to reach them, and that information lives in the
  configuration manager — i.e., an explicit dependency between Ch. 19 and Ch. 20 worth stating (in the
  spirit of this book's existing cross-reference discipline, e.g. the registry-split precedent).

### Ch. 18 — Storage Manager (currently TBW)

- **`storage-manager.adoc`** is very sparse but confirms the persistence formats in scope: CSV, HDF5,
  FITS, TXT, SQLite — useful as a chapter-scope checklist.

### Ch. 2 — Architecture at a Glance (currently TBW)

- **`misc.adoc`**, section "System Components" / "Data Flows", has a clean high-level component list
  (Storage Manager, Configuration Manager, Process Manager, Device Control Servers, SUT) and a
  paragraph enumerating the device categories the CGSE talks to (camera FEE, TCS, AEU, optical
  sources, mechanisms, thermal monitoring) plus a referenced architecture diagram
  (`cgse-container-diagram.png`, described as "main components... and how they interface to each
  other... and to the test setup... and the PLATO camera (SUT)"). **Caveat**: this list predates the
  Registry Service (Ch. 17 in our book), which didn't exist yet when this was written — if reused, the
  component list needs updating to reflect the current five-or-more core services including the
  registry, and probably `metricshub`/`notifyhub` (see note under "superseded," below). The diagram
  itself, if the source `.png`/asset can be located and is still accurate, could be a useful visual
  starting point rather than drawing one from scratch — worth checking if `plato-cgse-doc`'s
  `src/images/` has it and whether it needs updating before reuse.

---

## 3. "War stories" — candidates for the Pitfalls & Cleanup Backlog appendix

`stories.adoc` contains two debugging narratives explicitly framed as "otherwise difficult to explain
in the previous sections" — this is exactly the tacit, hard-won knowledge this book's Pitfalls
appendix exists to capture (see CLAUDE.md's workflow section on maintaining that appendix).

- **Story 2 — "A non-closed socket is deeply buried in the code."** Directly relevant to Ch. 6.
  Traces a hung shutdown to `unregister_as_listener()` in `control.py`, which opened a `Proxy` via
  `proxy()` to check liveness (`is_control_server_active()`) but never closed it — the fix was to use
  the `Proxy` as a context manager instead. Also surfaces a secondary, easy-to-miss logging bug (a
  `logging.debug()` call around `zcontext.term()` never printed because ZMQ log handlers were closed
  *before* the terminate call, while the root logger was at INFO). This directly touches the same
  `unregister_as_listener()`/`register_as_listener()` machinery documented in `notifications.adoc`
  above (§2), so if that content becomes Ch. 21, this bug is a natural companion Pitfalls entry or
  even a "story" sidebar there. **Needs empirical re-verification against current source** before
  logging as a confirmed Pitfalls entry, per this project's own verification-discipline rule — the
  `unregister_as_listener` code shown is from an older snapshot of `control.py` and may already be
  fixed, given `DynamicProxy` and other Ch. 6 material have clearly moved on since this was written.
- **Story 1 — "Seemingly unrelated Process Manager Crash."** A `systemd`/`LD_LIBRARY_PATH` deployment
  issue (a device control server couldn't load a shared library because the environment file used by
  `systemd` didn't set `LD_LIBRARY_PATH`, causing a crash that looked like a Storage Manager
  registration bug). This is operational/deployment-environment knowledge rather than `cgse-common`/
  `cgse-core` code knowledge — better suited to an installation/operations manual (which
  `plato-cgse-doc` itself has, `installation-manual.adoc`) than this developer manual, and this book
  doesn't currently have that scope. Low priority for this book; flagging for completeness only.

---

## 4. A structural question: general Python/process conventions

Three old-manual files are not module documentation at all, but general engineering conventions this
book currently has no place for:

- **`style-guide.adoc`** — PEP8 + Google style guide adoption, naming conventions (classes, functions,
  variables, constants, modules), and one sharp, still-relevant gotcha: never name an `egse` module
  the same as a Python stdlib module (worked example: an `egse.math` module silently shadowing
  `math`, producing a confusing `AttributeError` instead of an import error).
- **`error-handling.adoc`** (317 lines, the most complete file in the entire old manual) — a genuinely
  good, opinionated treatise on exception handling in this specific codebase: when to catch vs. let
  propagate, `try`/`finally` vs. context managers (with a real example using `PunaProxy` and its
  `ConnectionError` on a dead control server — nicely ties back to Ch. 6 material), EAFP vs. LBYL with
  a rule of thumb tied to expected failure frequency, why Python favors exceptions over return codes,
  when to re-raise (`raise` bare vs. `raise ... from`), a real `PMACException`-wrapping example from
  the actual codebase, when assertions are appropriate (and the `-O` flag gotcha that silently strips
  them), and the `Error`-suffix naming convention for custom exceptions.
- **`docstring.adoc`** — Google-style docstring convention adopted project-wide, with a full worked
  example (`egse.bits.humanize_bytes`) and a clear "describe *what*, not *how*" principle.

None of these describe a specific `cgse-common`/`cgse-core` module, so they don't fit the "one chapter
per module/module-group" pattern this book otherwise follows. But they're genuinely reusable,
undated, and still match the codebase's actual conventions (the `PunaProxy`/`ConnectionError` and
`PMACException` examples in `error-handling.adoc` reference real, still-plausible code paths, though
not independently re-verified here). **This needs an explicit decision, not a drafting default**:
candidates are (a) a new short chapter/section in Part I ("Development Conventions" or similar,
alongside the still-TBW Ch. 1/Ch. 2), (b) an appendix parallel to the Pitfalls backlog, or (c) leave
out of the book entirely as out-of-scope "process," not "architecture." Flagging for the author to
decide rather than picking one — this is exactly the kind of chapter-structure change CLAUDE.md asks
to be proposed and confirmed before touching manuscript files.

---

## 5. Minor/glossary-level pickups

- **`glossary.adoc`** has a few terms our front-matter acronyms list (`05-acronyms.adoc`) doesn't:
  EAFP, LBYL, "control server," "service" (as a term of art distinguishing device commands from
  control-server-behavior commands — ties to §1's Service class note above). Small, cheap addition if
  the acronyms/terminology page is ever revisited — note our existing file is a flat acronym table,
  not a definitions glossary, so these might not fit its current format as-is.
- **`terminal.adoc`**'s `curl localhost:<port>` metrics-inspection tip is **also superseded** — it's
  framed around scraping a Prometheus exposition endpoint, which no longer matches the
  InfluxDB/QuestDB-backed architecture described above. Whatever the current equivalent debugging
  technique is (querying QuestDB directly? a different inspection command?) would need to come from
  current source/author knowledge, not this file.

---

## 6. Explicitly out of scope (noted for completeness, not recommended now)

Consistent with this book's own stated scope boundary (CLAUDE.md: "deliberately out of scope so
far... `cgse-coordinates`, `cgse-gui`, the generic device-driver projects, and the mission-specific
projects"):

- **`data-dumper.adoc`** — F-FEE/F-DPU fast-camera data path, entirely PLATO-mission-specific
  (`data_dump` process, HDF5 packet formats, N-FEE/F-FEE hardware specifics).
- **`sut.adoc`, `spw.adoc`, `device-simualtors.adoc`, `device-control-servers.adoc`** — SpaceWire, DPU
  Processor, N-FEE/F-FEE simulators — all PLATO camera hardware.
- **`synoptics-manager.adoc`** — worth a note: this old core service (unifying HK parameter names
  across test facilities) doesn't appear to exist by that name in the current source (no `synoptics`
  module found under `libs/cgse-core`); it looks to have been **superseded by `metricshub`/
  `notifyhub`** (**verified present**: `libs/cgse-core/src/egse/metricshub/` and
  `libs/cgse-core/src/egse/notifyhub/`, already correctly scoped to our planned Ch. 22). The old
  content is conceptually adjacent but not directly portable — if Ch. 22 is drafted, it's worth
  checking with the author whether `metricshub`/`notifyhub` are in fact the synoptics manager's
  architectural successor, since that'd be a good "why this replaced that" narrative beat, similar in
  spirit to the registry-split precedent already established in this book.
- **`observation.adoc`, `building-block.adoc`** — test-script/`camtest` concepts, explicitly out of
  scope.
- **`gui-executor.adoc`** — **correction (per author, 2026-08-14): this is not a `cgse-gui` /
  mission-specific exclusion in the usual sense.** "The Tasks GUI" described in the old file
  originated inside `plato-common-egse` but has since been extracted into its own standalone repo,
  https://github.com/IvS-KULeuven/gui-executor — the same pattern as `navdict` (also born out of this
  codebase, now a separate library with its own documentation). **Verified against current source**:
  no reference to `gui_executor`, `gui-executor`, or `exec_ui` (the decorator the old doc describes)
  anywhere in the `cgse` monorepo (`libs/`, `projects/`, or any `pyproject.toml`) — it is not currently
  a declared dependency of any in-scope package. Per this project's own convention for
  already-externalized dependencies (CLAUDE.md: "stay at what this module uses it for, and why rather
  than duplicating that library's internals," as already applied to `navdict`), `gui-executor` would
  get the same light-touch treatment *if and when* some in-scope module is found to depend on it — but
  right now nothing in `cgse-common`/`cgse-core` appears to. Most likely consumer is `cgse-gui` itself
  or a mission-specific project, both already out of scope, so the practical recommendation is
  unchanged (don't draft this now) — but the *reason* is "not currently used by anything in scope,"
  not "inherently out of scope." Worth a quick check with the author on whether any in-scope module
  is expected to pick up `gui-executor` later, since that would change this.
- **`ccd-numbering.adoc`** — PLATO CCD/MSSL register-map numbering, mission-specific.
- **`dev-environment.adoc`** — entirely superseded. Describes the old multi-repo, per-project `venv`/
  `pip install -e .`/`invoke start-core-egse` workflow; this book's Ch. 3 already documents the
  current `uv` monorepo workflow, which has fully replaced this.
- **`settings.adoc`** (the old manual's own short stub, not to be confused with our Ch. 4) — also
  superseded: describes a single global `settings.yaml` plus a `$PLATO_LOCAL_SETTINGS` env-var
  override, whereas our Ch. 4 already documents the current entry-point-based plugin model, which is
  architecturally different (multiple packages contributing settings, not one file + one override).
  Nothing here to migrate; noted only so it isn't mistaken for still-relevant source material.
- **`version-numbers.adoc`** — describes an old `YYYY.WW.patch+SUFFIX` semantic-versioning scheme
  tied to a Configuration Control Board cadence and per-repo suffixes (`+CGSE`, `+TS`, `+CONF`). Our
  Ch. 3 already documents the current monorepo's lockstep versioning via `bump.py`, which is a
  different scheme. Worth a quick check with the author on whether the CCB-week versioning convention
  still applies at all under the new scheme, or whether `bump.py` fully replaced it — not a content
  migration either way, just a possible fact-check.
- **`review.adoc`** — a specific, dated code-review planning document (named reviewers, a
  `code-review-2020-Q2` tag) with a few generically-reusable bullets buried in it (the "why we review"
  rationale list, and the black/flake8 pre-review tooling checklist). Low value; the specific plan is
  clearly stale and the generic bullets are thin on their own.
- **`grafana.adoc`-adjacent operational content** (systemd services, install/update procedures,
  `terminal.adoc`'s git cheat-sheet) belongs to `plato-cgse-doc`'s own Installation Manual scope, which
  this book doesn't currently cover.

---

## Suggested next step

Given the size, recommend tackling this in the order the migrated content unblocks the most TBW
chapters: **Ch. 8 (mixin.py)** first — `dynamic-commanding.adoc` is nearly a complete draft already —
then **Ch. 21 (notifications)** using `notifications.adoc`, then folding the smaller Ch. 4/Ch. 6
supplements (§1 above) into the already-drafted chapters as a lighter editing pass. The Part I
conventions question (§4) is a standalone decision independent of chapter-drafting order.
