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

## Not yet written

**`src/part-1-orientation/`** — currently one outline stub (`00-outline.md`) with three planned sections (Introduction & Philosophy, Architecture at a Glance, Repository Tour), all marked TBW.

## Planned next (Part II continues)

- `egse/protocol.py`, `egse/command.py`, `egse/mixin.py` — what a `Command` actually is, how `client_call` becomes a ZeroMQ round trip, how a device protocol class builds the command dictionary `Proxy._request_commands()` receives.
- `egse/dummy.py` — smallest complete worked example tying control.py/proxy.py/command.py/protocol.py together end to end.
- `egse/registry/` — the service registry, covered last in this arc so its value is clear by contrast with the static-port model covered in the control/proxy chapter.

## Running appendix

**Pitfalls & Cleanup Backlog** (`src/99-appendix-pitfalls-cleanup-backlog.md`) — currently P-001 through P-008. Template included at the bottom of that file for adding new entries in the established format.

## Repo layout (current)

```
cgse-book/
  cgse_book_project_instructions.md
  cgse-book-chapter-index.md
  src/
    00-preface.md
    part-1-orientation/
      00-outline.md
    part-2-core-concepts/
      01-settings-and-setup.md
      02-env.md
      03-control-and-proxy.md
    99-appendix-pitfalls-cleanup-backlog.md
```
