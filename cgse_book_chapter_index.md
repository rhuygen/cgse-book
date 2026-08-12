# CGSE Book — Chapters Index

Reference index for the project knowledge base. Update this file whenever a chapter is added, reordered, or substantially revised. This is a summary for quick orientation — the actual current text of every chapter lives in the cgse-book repo, not here.

## Published / drafted so far

**`src/part-2-core-concepts/01-settings-and-setup.md` — Settings and Setup: Where Configuration Lives**
Modules: `egse/settings.py`, `egse/setup.py` (both in `cgse-common`)
Establishes the book's core running framework: CONSTANT vs Settings vs Setup, decided by "how often does the value change, and who changes it." Covers the entry-point-based plugin model for Settings, the float-parsing YAML fix, memoization, the `class//`/`csv//` directive family in Setup, the Setup ID/filename contract, the `ContextVar`-based "current Setup," submit/load asymmetry, and the `SetupManager` provider pattern (optional `cgse-core` dependency). Includes a "what Setup borrows from navdict" section (navdict itself stays out of the book, covered separately). Extended by the author with sections on local settings/site customization, debugging & inspection, and common patterns.

**`src/part-2-core-concepts/02-env.md` — egse/env.py: Where "Where Does It Live" Gets Decided**
Module: `egse/env.py` (`cgse-common`)
Covers the `<PROJECT>_...` environment variable naming convention, the `_Env`/`NoValue` cache mechanism, `setup_env()`'s run-once-but-re-runnable design, the get/set/env-name triads and their fallback chaining, `load_dotenv()`'s deliberate deviations, and the `env_var()` test context manager.
Findings logged in the Pitfalls appendix: P-003 (`has_conf_repo_location()` always returns `False`, confirmed by running it — dead validation branch in `Setup.get_path_of_setup_file`), P-004 (`env_var()` not exception-safe), P-005 (stray unresolved TODO comment).

**`src/part-2-core-concepts/03-control-and-proxy.md` — control.py and proxy.py: The Client/Server Foundation**
Modules: `egse/control.py`, `egse/proxy.py` (both in `cgse-core`)
Covers the one-process-per-device / many-clients architecture, the three-ZeroMQ-socket topology (cmd/service/mon) and why each uses its pattern, the single-threaded reactor `serve()` loop and its blocking-callback trade-off, why Ctrl-C is deliberately disabled, `schedule_task` as cooperative multitasking, the abstract port/protocol contract tying back to the Settings framework, the `can_operate_without_registry()` policy hook, and the client-side `Proxy`/`BaseProxy` machinery — retry/reconnect semantics, `DynamicProxy` vs `Proxy`, and `load_commands()`'s runtime method injection.
Findings logged in the Pitfalls appendix: P-006 (`ControlServer.service_id` never actually set — confirmed against three sibling classes; highest-value fix so far), P-007 (self-flagged FIXME on the monitoring socket's poller registration), P-008 (`DynamicProxy` vs `Proxy` relationship needs a decision).

## Full skeleton (placeholders, all marked TBW)

A full skeleton was scaffolded on 2026-08-12, covering Parts I–IV (orientation plus the whole core framework: `cgse-common` + `cgse-core`). Chapter numbering is global across the book; file numbering restarts at `01` within each Part folder. Coordinates (`cgse-coordinates`), GUI (`cgse-gui`), the generic device-driver projects, and the mission-specific projects (`ariel`, `ivs`, `plato`) are deliberately out of scope for this skeleton pass — planned for a later session.

**`src/part-1-orientation/`** — one file per chapter, all TBW:
- Ch. 1 `01-introduction-and-philosophy.md` — Introduction and Philosophy
- Ch. 2 `02-architecture-at-a-glance.md` — Architecture at a Glance
- Ch. 3 `03-repository-tour.md` — Repository Tour

**`src/part-2-core-concepts/`** — chapters 4–6 drafted (see above); chapters 7–10 are new TBW placeholders continuing the same arc:
- Ch. 7 `07-protocol-and-command.md` — `egse/protocol.py`, `egse/command.py`
- Ch. 8 `08-mixin.md` — `egse/mixin.py`
- Ch. 9 `09-dummy.md` — `egse/dummy.py`, the worked end-to-end example
- Ch. 10 `10-registry.md` — `egse/registry/` (backend, client, server, service)

**`src/part-3-common-utilities/`** — new Part, TBW, covering the remaining `cgse-common` modules in thematic (not 1:1) chapters:
- Ch. 11 `01-device-communication.md` — `device.py`, `socketdevice.py`, `scpi.py`
- Ch. 12 `02-runtime-and-resilience.md` — `system.py`, `process.py`, `task.py`, `decorators.py`, `backoff.py`
- Ch. 13 `03-persistence-housekeeping-metrics.md` — `persistence.py`, `hk.py`, `metrics.py`, `plugins/metrics/*`
- Ch. 14 `04-messaging-primitives.md` — `response.py`, `zmq_ser.py`, `observer.py`, `state.py`, `signal.py`, `heartbeat.py`
- Ch. 15 `05-logging-errors-diagnostics.md` — `log.py`, `exceptions.py`, `dicts.py`, `version.py`
- Ch. 16 `06-odds-and-ends.md` — `bits.py`, `calibration.py`, `counter.py`, `config.py`, `resource.py`, `plugin.py`, `obsid.py`, `randomwalk.py`, `reload.py`

**`src/part-4-core-services/`** — new Part, TBW, one control-server-shaped service per chapter (or a closely related pair):
- Ch. 17 `01-storage-manager.md` — `egse/storage/*`
- Ch. 18 `02-configuration-manager.md` — `egse/confman/*`, `egse/cm_acs/*`, `egse/serialization.py`
- Ch. 19 `03-process-manager.md` — `egse/procman/*`
- Ch. 20 `04-log-server-and-notifications.md` — `egse/logger/*`, `egse/listener.py`, `egse/connect.py`
- Ch. 21 `05-metrics-and-notification-hubs.md` — `egse/metricshub/*`, `egse/notifyhub/*`
- Ch. 22 `06-monitoring-observation-async-servers.md` — `egse/monitoring.py`, `egse/observation.py`, `egse/async_control.py`, `egse/async_dummy.py`, `egse/async_temp.py`, `egse/temperature_profile.py`, `egse/_setup_core.py`
- Ch. 23 `07-the-cgse-cli.md` — `cgse_core/_start.py`, `_status.py`, `_stop.py`, `cgse_explore.py`, `cgse_core/services.py`, `egse/services.py`

## Running appendix

**Pitfalls & Cleanup Backlog** (`src/back-matter/01-appendix-pitfalls-cleanup-backlog.md`) — currently P-001 through P-008. Template included at the bottom of that file for adding new entries in the established format.


## Repo layout (current)

```
cgse-book/
  cgse_book_project_instructions.md
  cgse-book-chapter-index.md
  build.sh
  metadata.yaml
  src/
    front-matter/
      01-title-verso.md
      02-preface.md
    part-1-orientation/
      01-introduction-and-philosophy.md          (Ch. 1, TBW)
      02-architecture-at-a-glance.md             (Ch. 2, TBW)
      03-repository-tour.md                      (Ch. 3, TBW)
    part-2-core-concepts/
      01-settings-and-setup.md                    (Ch. 4, drafted)
      02-env.md                                   (Ch. 5, drafted)
      03-control-and-proxy.md                     (Ch. 6, drafted)
      07-protocol-and-command.md                  (Ch. 7, TBW)
      08-mixin.md                                 (Ch. 8, TBW)
      09-dummy.md                                 (Ch. 9, TBW)
      10-registry.md                              (Ch. 10, TBW)
    part-3-common-utilities/
      01-device-communication.md                  (Ch. 11, TBW)
      02-runtime-and-resilience.md                (Ch. 12, TBW)
      03-persistence-housekeeping-metrics.md       (Ch. 13, TBW)
      04-messaging-primitives.md                  (Ch. 14, TBW)
      05-logging-errors-diagnostics.md            (Ch. 15, TBW)
      06-odds-and-ends.md                         (Ch. 16, TBW)
    part-4-core-services/
      01-storage-manager.md                       (Ch. 17, TBW)
      02-configuration-manager.md                 (Ch. 18, TBW)
      03-process-manager.md                       (Ch. 19, TBW)
      04-log-server-and-notifications.md          (Ch. 20, TBW)
      05-metrics-and-notification-hubs.md         (Ch. 21, TBW)
      06-monitoring-observation-async-servers.md  (Ch. 22, TBW)
      07-the-cgse-cli.md                          (Ch. 23, TBW)
    back-matter/
      01-appendix-pitfalls-cleanup-backlog.md
```

Note: file numbering restarts at `01` within each Part folder (matching the existing convention); chapter numbers in each file's H1 are global across the book.