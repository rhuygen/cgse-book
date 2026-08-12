This project is for a technical book documenting the CGSE framework, written by the framework's architect as legacy knowledge transfer ahead of retirement in ~2 years. The book covers requirements, architecture, design decisions, and a deep, module-by-module, function-by-function/class-by-class walkthrough of the actual code — intended for coworkers to build on afterward.

SOURCE OF TRUTH — TWO REPOS, BOTH PUBLIC, BOTH CLONED FRESH EVERY SESSION

1. CGSE source code: https://github.com/IvS-KULeuven/cgse
2. Book manuscript: https://github.com/rhuygen/cgse-book

At the start of any work in this project — every new chat, no exceptions — clone both repos fresh before reading or writing anything:

git clone --depth 1 https://github.com/IvS-KULeuven/cgse.git
git clone --depth 1 https://github.com/rhuygen/cgse-book.git

Never rely on a previous session's clone or on memory of a module's contents. The CGSE source changes frequently; always verify current behavior by reading and, where feasible, running the actual code rather than assuming it matches an earlier chapter.

Before starting or resuming any chapter, check cgse-book for the current state of that file — the author edits directly in Ulysses, which writes back to this repo via an External Folder link. Treat whatever is in the repo as authoritative over anything drafted earlier in this or another conversation. If a chapter already exists there, diff your intended changes against it mentally before rewriting.

WORKFLOW

- Write new/updated chapters as clean plain-Markdown files, one per module or logical module-pair, matching the existing naming pattern in cgse-book.
- After creating or updating a file, present it to the user for review; the user commits/pushes to cgse-book themselves (do not assume push access — there is none).
- Maintain the running "Pitfalls & Cleanup Backlog" appendix (appendix-pitfalls.md in the repo): log any confirmed bug, dead code path, or inconsistency found while writing a chapter, using the existing field format (Module / Where / Issue / Evidence if applicable / Fix scope / Risk of leaving as-is). Verify suspected bugs empirically (actually run the code) before logging them as confirmed, not just from reading.
- Flag when re-syncing the repo would help — e.g. if it's been a while since the last clone/pull in this session, or the user mentions having pushed new edits.

STYLE — "brief for routine code, deep for tricky decisions"

- Cover every function/class, but briefly, when the code is routine (boilerplate, obvious getters, standard patterns).
- Go deep — full reasoning, trade-offs, alternatives considered, performance notes where measured — on non-obvious design decisions, anything that looks like a mistake until verified, and anything a departing architect would otherwise take reasoning about "why" to the grave.
- Tie module-level decisions back to the running framework already established for this book (e.g. the CONSTANT vs Settings vs Setup distinction from the first chapter) rather than re-deriving it each time — cross-reference earlier chapters instead.
- When a module depends on another library that has (or should have) its own separate documentation (e.g. navdict), stay at the "what does this module use it for, and why" level rather than duplicating that library's internals.

FORMATTING — for direct import into Ulysses

- Plain Markdown only. No mkdocs-specific syntax (no admonitions, no wikilinks, no `{: .class}` tags).
- One paragraph, bullet, or field per physical line — no manual hard-wrapping mid-paragraph. Let the editor soft-wrap. Blank lines are the only paragraph/block separator.
- Preserve fenced code blocks, tables, and headings exactly; only prose gets reflowed onto single lines.
- Headings: number + short noun phrase only. No colons or em-dash explanatory clauses in headings — they wrap badly in PDF export and clutter the TOC. If a heading's hook phrase is worth keeping, add it as a short italic "deck" line directly under the heading instead.

BOOK STRUCTURE SO FAR

Chapters completed: settings.py + setup.py, env.py, control.py + proxy.py (all in cgse-core/cgse-common as noted per chapter).
Next planned: protocol.py, command.py, mixin.py, dummy.py (worked end-to-end example), then egse/registry/ (service registry — covered after the static-port model so its value is legible by contrast).

There is a file in the repo that contains a summary of the chapters, i.e. `chapter-index.md` (try to keep this file up-to-date).

There is also a separate, related research paper project (CGSE for an instrumentation journal, ten-section structure, Section 6 on multi-mission deployment as the evidentiary core) — related but distinct from this book; don't conflate the two unless asked.
