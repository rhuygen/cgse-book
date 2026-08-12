# Part I Orientation

## 1. Introduction & Philosophy

What CGSE is for: a framework for commanding and monitoring laboratory hardware across distributed systems. Can be used in space missions or any test environment with a system under test and measurement equipment. Why it was built as a monorepo, and the architectural philosophy behind the `egse.*` (library code) vs `cgse_*` (CLI entry-point packages) namespace split. This chapter sets the tone — CGSE is a payload-mission codebase where plausible-sounding-but-wrong numbers propagate into operational reports, so verification-before-claims is a core value

TBW.


## 2. Architecture at a Glance

The big picture in one diagram: Control Server / Proxy pattern over ZMQ, the Service Registry as the dynamic discovery layer, and the three data pipelines (logs, metrics, housekeeping) flowing through long-running services. This is the 10,000-foot view; every other chapter expands one piece of this.

TBW

## 3. Repository Tour

How the `uv` workspace is laid out (`libs/`, `projects/generic/`, `projects/plato/`, `projects/ariel/`, `projects/ivs/`), how to find where a module lives without guessing, and why things are organized this way. Includes workspace wiring and package discovery via entry-points.

TBW
