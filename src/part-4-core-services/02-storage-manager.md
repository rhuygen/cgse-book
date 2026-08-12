# Chapter 18 The Storage Manager

*Where all the data coming off a test setup ends up.*

Modules: `egse/storage/__init__.py`, `egse/storage/persistence.py`, `egse/storage/storage_cs.py` (all in `cgse-core`)

Part IV moves from `cgse-common`'s shared primitives to the actual middleware services built on top of them — one control server per chapter, in roughly the order a new team member would need to understand them. The Storage Manager comes first because nearly every other service ends up writing through it.

## 1. What the Storage Manager Is For

The role this service plays relative to the generic `persistence.py` abstraction from Chapter 13, and why storage is centralized in one control server rather than left to each device controller.

TBW.

## 2. Persistence on the Server Side

`egse/storage/persistence.py` and how it differs from — and builds on — `egse/persistence.py` (Chapter 13).

TBW.

## 3. The Storage Control Server

`storage_cs.py` as a concrete `ControlServer` (Chapter 6): what data it accepts, from whom, and in what format.

TBW.
