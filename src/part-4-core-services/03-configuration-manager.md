# Chapter 19 The Configuration Manager, Two Generations

*`confman` and its async rewrite, `cm_acs`.*

Modules: `egse/confman/` (all files), `egse/cm_acs/` (all files), `egse/serialization.py` (all in `cgse-core`)

This chapter covers two implementations of the same service side by side: the original, synchronous Configuration Manager, and `cm_acs`, its asynchronous successor. Reading them together should make clear why the rewrite happened and what it cost.

## 1. The Classic Configuration Manager

`confman/confman_cs.py`: a server that controls and distributes configuration settings, and its client/protocol pair.

TBW.

## 2. Why an Async Rewrite

The motivation for `cm_acs`, and what specifically about the synchronous design it was meant to fix.

TBW.

## 3. `cm_acs`: Client, Controller, Server

Walking `client.py`, `controller.py`, and `server.py` in `egse/cm_acs/`.

TBW.

## 4. Typed Serialization

`cm_acs/typed_serialization.py` and `egse/serialization.py` — the shared JSON-safe payload conversion helpers, and how `cm_acs` uses stricter typing than the classic `confman`.

TBW.

## 5. Migration Path and Open Questions

Whether `confman` is expected to be retired, and what a consumer needs to know before choosing one over the other today.

TBW.
