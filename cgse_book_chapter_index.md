# CGSE Book — Chapters Index

Reference index for the project knowledge base. Update this file whenever a chapter is added, reordered, or substantially revised. This is a summary for quick orientation — the actual current text of every chapter lives in the cgse-book repo, not here.

## Published / drafted so far

**`src/develop/part-1-orientation/03-repository-tour.adoc` — Repository Tour**
No specific module — covers the workspace itself: the `uv` monorepo (`libs/` vs `projects/generic|plato|ariel|ivs`), lockstep versioning via `bump.py`, the `[tool.uv.workspace]`/`[tool.uv.sources]` wiring, the `cgse-common`/`cgse-core` split (mirrored by this book's own Part structure), a worked package anatomy walkthrough (`symetrie-hexapod`), the `egse.*` namespace-package convention and its scoping to in-monorepo contributors only (external device packages should stay under their own distribution name), and the `cgse.*` entry-point families (`cgse.version`, `cgse.settings`, `cgse.service.*` via `HierarchicalEntryPoints`, `cgse.explore`, `cgse.resource`, `cgse.extension.setup_provider`, `cgse.process_management.core_services`, `cgse.storage.persistence`) that let optional packages plug into the `cgse` CLI and `cgse-core` without being hard-imported. Closes out Part I.
Findings logged in the Pitfalls appendix: P-010 (stale docstring in `cgse_common/cgse.py` names a `cgse.command.plugins` group that the code doesn't actually use — it reads `cgse.command`), P-011 (three unexplained/unused entries in root's `[tool.uv.sources]`, and three member-level `[tool.uv.sources]` tables that are entirely redundant with what they'd inherit from root anyway).

**`src/develop/part-2-core-concepts/01-settings-and-setup.adoc` — Settings and Setup: Where Configuration Lives**
Modules: `egse/settings.py`, `egse/setup.py` (both in `cgse-common`)
Establishes the book's core running framework: CONSTANT vs Settings vs Setup, decided by "how often does the value change, and who changes it." Covers the entry-point-based plugin model for Settings, the float-parsing YAML fix, memoization, the `class//`/`csv//` directive family in Setup, the Setup ID/filename contract, the `ContextVar`-based "current Setup," submit/load asymmetry, and the `SetupManager` provider pattern (optional `cgse-core` dependency). Includes a "what Setup borrows from navdict" section (navdict itself stays out of the book, covered separately). Extended by the author with sections on local settings/site customization, debugging & inspection, and common patterns.

**`src/develop/part-2-core-concepts/02-env.adoc` — egse/env.py: Where "Where Does It Live" Gets Decided**
Module: `egse/env.py` (`cgse-common`)
Covers the `<PROJECT>_...` environment variable naming convention, the `_Env`/`NoValue` cache mechanism, `setup_env()`'s run-once-but-re-runnable design, the get/set/env-name triads and their fallback chaining, `load_dotenv()`'s deliberate deviations, and the `env_var()` test context manager.
Findings logged in the Pitfalls appendix: P-003 (`has_conf_repo_location()` always returns `False`, confirmed by running it — dead validation branch in `Setup.get_path_of_setup_file`), P-004 (`env_var()` not exception-safe), P-005 (stray unresolved TODO comment).

**`src/develop/part-2-core-concepts/03-control-and-proxy.adoc` — control.py and proxy.py: The Client/Server Foundation**
Modules: `egse/control.py`, `egse/proxy.py` (both in `cgse-core`)
Covers the one-process-per-device / many-clients architecture, the three-ZeroMQ-socket topology (cmd/service/mon) and why each uses its pattern, the single-threaded reactor `serve()` loop and its blocking-callback trade-off, why Ctrl-C is deliberately disabled, `schedule_task` as cooperative multitasking, the abstract port/protocol contract tying back to the Settings framework, the `can_operate_without_registry()` policy hook, and the client-side `Proxy`/`BaseProxy` machinery — retry/reconnect semantics, `DynamicProxy` vs `Proxy`, and `load_commands()`'s runtime method injection.
Findings logged in the Pitfalls appendix: P-006 (`ControlServer.service_id` never actually set — confirmed against three sibling classes; highest-value fix so far), P-007 (self-flagged FIXME on the monitoring socket's poller registration), P-008 (`DynamicProxy` vs `Proxy` relationship needs a decision).

**`src/develop/part-2-core-concepts/08-mixin.adoc` — Mixin and Dynamics**
Module: `egse/mixin.py` (`cgse-core`)
Covers `DynamicCommandMixin`/`DynamicClientCommandMixin`, the `+__getattribute__+`-interception pattern shared by both, the `dynamic_command()` decorator factory (including the recently added `validate` keyword), `create_command_string()`'s template/format/callable paths, and the PUNA/PUNA+/DAQ6510 worked examples showing `@dynamic_interface`+`Proxy` and `@dynamic_command`+`DynamicProxy` as two coexisting, deliberately different systems. Resolves the relationship half of P-008 (Ch. 6); the `Proxy`-specific TODO/FIXME half of that entry stays open.
Rewritten to ASD-STE100/Zinsser style 2026-08-21; verified against current source, including the `validate` keyword merged after the original draft. The `get_current_position`/`?p${axis}` example in the earlier draft did not exist in source and was replaced with the real `homing()` pair (`alpha.py`/`dynalpha.py`).

## Full skeleton (placeholders, all marked TBW)

A full skeleton was scaffolded on 2026-08-12, covering Parts I–IV (orientation plus the whole core framework: `cgse-common` + `cgse-core`). Chapter numbering is global across the book; file numbering restarts at `01` within each Part folder. Coordinates (`cgse-coordinates`), GUI (`cgse-gui`), the generic device-driver projects, and the mission-specific projects (`ariel`, `ivs`, `plato`) are deliberately out of scope for this skeleton pass — planned for a later session.

**`src/part-1-orientation/`** — Ch. 3 drafted (see above); Ch. 1-2 still TBW:
- Ch. 1 `01-introduction-and-philosophy.adoc` — Introduction and Philosophy
- Ch. 2 `02-architecture-at-a-glance.adoc` — Architecture at a Glance

**`src/part-2-core-concepts/`** — chapters 4–6 and 8 drafted (see above); chapters 7, 9, and 10 are still TBW placeholders continuing the same arc:
- Ch. 7 `07-protocol-and-command.adoc` — `egse/protocol.py`, `egse/command.py`
- Ch. 9 `09-dummy.adoc` — `egse/dummy.py`, the worked end-to-end example
- Ch. 10 `10-registry.adoc` — `egse/registry/client.py`, `egse/registry/service.py` — the registry as design/API (client-side registration and discovery); the deployed-service side (`server.py`, `backend.py`) is split out to Ch. 17 in Part IV, cross-referenced rather than duplicated

**`src/part-3-common-utilities/`** — new Part, TBW, covering the remaining `cgse-common` modules in thematic (not 1:1) chapters:
- Ch. 11 `01-device-communication.adoc` — `device.py`, `socketdevice.py`, `scpi.py`
- Ch. 12 `02-runtime-and-resilience.adoc` — `system.py`, `process.py`, `task.py`, `decorators.py`, `backoff.py`
- Ch. 13 `03-persistence-housekeeping-metrics.adoc` — `persistence.py`, `hk.py`, `metrics.py`, `plugins/metrics/*`
- Ch. 14 `04-messaging-primitives.adoc` — `response.py`, `zmq_ser.py`, `observer.py`, `state.py`, `signal.py`, `heartbeat.py`
- Ch. 15 `05-logging-errors-diagnostics.adoc` — `log.py`, `exceptions.py`, `dicts.py`, `version.py`
- Ch. 16 `06-odds-and-ends.adoc` — `bits.py`, `calibration.py`, `counter.py`, `config.py`, `resource.py`, `plugin.py`, `obsid.py`, `randomwalk.py`, `reload.py`

**`src/part-4-core-services/`** — new Part, TBW, one control-server-shaped service per chapter (or a closely related pair). Opens with the Registry Service, since every other service here registers itself with it on startup:
- Ch. 17 `01-registry-service.adoc` — `egse/registry/server.py`, `egse/registry/backend.py` — the registry as a deployed service (backend choice, startup ordering, operations); split from Ch. 10's design/API treatment, cross-referenced not duplicated
- Ch. 18 `02-storage-manager.adoc` — `egse/storage/*`
- Ch. 19 `03-configuration-manager.adoc` — `egse/confman/*`, `egse/cm_acs/*`, `egse/serialization.py`
- Ch. 20 `04-process-manager.adoc` — `egse/procman/*`
- Ch. 21 `05-log-server-and-notifications.adoc` — `egse/logger/*`, `egse/listener.py`, `egse/connect.py`
- Ch. 22 `06-metrics-and-notification-hubs.adoc` — `egse/metricshub/*`, `egse/notifyhub/*`
- Ch. 23 `07-monitoring-observation-async-servers.adoc` — `egse/monitoring.py`, `egse/observation.py`, `egse/async_control.py`, `egse/async_dummy.py`, `egse/async_temp.py`, `egse/temperature_profile.py`, `egse/_setup_core.py`
- Ch. 24 `08-the-cgse-cli.adoc` — `cgse_core/_start.py`, `_status.py`, `_stop.py`, `cgse_explore.py`, `cgse_core/services.py`, `egse/services.py`

## Running appendix

**Pitfalls & Cleanup Backlog** (`src/develop/back-matter/01-appendix-pitfalls-cleanup-backlog.adoc`) — currently P-001 through P-011.

## Book production

The manuscript migrated from Markdown/Pandoc to AsciiDoc/`asciidoctor-pdf` on 2026-08-14 (content unchanged, format and toolchain only). See `cgse_book_asciidoc_conventions.md` for the reasons and for the parser gotchas that migration surfaced — read it before drafting or converting a chapter, since several of those failure modes are silent (no build error, just wrong-looking output).

## Repo layout (current)

```
cgse-book/
  cgse_book_project_instructions.md
  cgse_book_chapter_index.md
  cgse_book_asciidoc_conventions.md
  build.sh
  src/
    images/
    themes/
      cgse-book-theme.yml
    develop/
      developer-manual.adoc                        (master doc — includes everything below)
      front-matter/
        01-title-verso.adoc
        02-about.adoc
        03-preface.adoc
        04-acknowledgments.adoc
        05-acronyms.adoc
      part-1-orientation/
        01-introduction-and-philosophy.adoc          (Ch. 1, TBW)
        02-architecture-at-a-glance.adoc             (Ch. 2, TBW)
        03-repository-tour.adoc                      (Ch. 3, drafted)
      part-2-core-concepts/
        01-settings-and-setup.adoc                    (Ch. 4, drafted)
        02-env.adoc                                   (Ch. 5, drafted)
        03-control-and-proxy.adoc                     (Ch. 6, drafted)
        07-protocol-and-command.adoc                  (Ch. 7, TBW)
        08-mixin.adoc                                 (Ch. 8, drafted)
        09-dummy.adoc                                 (Ch. 9, TBW)
        10-registry.adoc                              (Ch. 10, TBW)
      part-3-common-utilities/
        01-device-communication.adoc                  (Ch. 11, TBW)
        02-runtime-and-resilience.adoc                (Ch. 12, TBW)
        03-persistence-housekeeping-metrics.adoc      (Ch. 13, TBW)
        04-messaging-primitives.adoc                  (Ch. 14, TBW)
        05-logging-errors-diagnostics.adoc            (Ch. 15, TBW)
        06-odds-and-ends.adoc                         (Ch. 16, TBW)
      part-4-core-services/
        01-registry-service.adoc                      (Ch. 17, TBW)
        02-storage-manager.adoc                       (Ch. 18, TBW)
        03-configuration-manager.adoc                 (Ch. 19, TBW)
        04-process-manager.adoc                       (Ch. 20, TBW)
        05-log-server-and-notifications.adoc          (Ch. 21, TBW)
        06-metrics-and-notification-hubs.adoc         (Ch. 22, TBW)
        07-monitoring-observation-async-servers.adoc  (Ch. 23, TBW)
        08-the-cgse-cli.adoc                          (Ch. 24, TBW)
      back-matter/
        01-appendix-pitfalls-cleanup-backlog.adoc
```

Note: file numbering restarts at `01` within each Part folder (matching the existing convention); chapter and section numbers are generated automatically by AsciiDoc's `:sectnums:` from `developer-manual.adoc` — no manual numbers in heading text (see the conventions file for why that matters).