This project is for a technical book documenting the CGSE framework, written by the framework's architect as legacy knowledge transfer ahead of retirement in ~2 years. The book covers requirements, architecture, design decisions, and a deep, module-by-module, function-by-function/class-by-class walkthrough of the actual code — intended for coworkers to build on afterward.

SOURCE OF TRUTH — TWO REPOS, BOTH PUBLIC, BOTH CLONED FRESH EVERY SESSION

1. CGSE source code: https://github.com/IvS-KULeuven/cgse
2. Book manuscript: https://github.com/rhuygen/cgse-book

At the start of any work in this project — every new chat, no exceptions — clone both repos fresh before reading or writing anything:

git clone --depth 1 https://github.com/IvS-KULeuven/cgse.git
git clone --depth 1 https://github.com/rhuygen/cgse-book.git

Never rely on a previous session's clone or on memory of a module's contents. The CGSE source changes frequently; always verify current behavior by reading and, where feasible, running the actual code rather than assuming it matches an earlier chapter.

Before starting or resuming any chapter, check cgse-book for the current state of that file. The author edits the manuscript directly as plain Markdown, in VS Code or a similar editor, and commits/pushes changes himself. Treat whatever is currently in the repo as authoritative over anything drafted earlier in this or another conversation. If a chapter already exists there, work from its current content, not from an earlier draft, and preserve any additions the author has made to it.

REPO LAYOUT

cgse-book/
  cgse_book_project_instructions.md   (this file)
  cgse-book-chapter-index.md          (orientation index, kept up to date)
  src/
    front-matter/
      01-title-verso.md
      02-preface.md
    part-1-orientation/
      (chapters TBW; currently one outline stub file)
    part-2-core-concepts/
      01-settings-and-setup.md
      02-env.md
      03-control-and-proxy.md
      07-protocol-and-command.md   (Ch. 7, TBW)
      08-mixin.md                  (Ch. 8, TBW)
      09-dummy.md                  (Ch. 9, TBW)
      10-registry.md                (Ch. 10, TBW)
    part-3-common-utilities/
      (Ch. 11-16, TBW — remaining cgse-common modules, thematically grouped)
    part-4-core-services/
      (Ch. 17-23, TBW — cgse-core middleware services, one per chapter)
      (more chapters land here as they're written, one file per chapter,
       numbered in reading order within its Part folder; chapter numbers
       in each file's H1 are global across the book)
    back-matter/
      01-appendix-pitfalls-cleanup-backlog.md

Each chapter is a self-contained Markdown file, starting at H1 for the chapter title, H2 for its top-level sections, H3/H4 for subsections. Do not merge multiple chapters into one file, and do not pre-emptively demote heading levels to nest under a "Part" — Parts are just folders for organization; how the final book gets assembled (and whether heading levels need adjusting for that) is a separate, not-yet-decided step (see BOOK PRODUCTION below).

WORKFLOW

- Write new/updated chapters as clean plain-Markdown files, one per module or logical module-pair, following the existing naming pattern (NN-short-name.md, numbered in reading order within its Part folder).
- After creating or updating a file, present it to the user for review; the user commits/pushes to cgse-book themselves (do not assume push access — there is none, and cloning is read-only).
- Maintain the running "Pitfalls and Cleanup Backlog Appendix" appendix (01-appendix-pitfalls-cleanup-backlog.md): log any confirmed bug, dead code path, or inconsistency found while writing a chapter, using the existing field format (Module / Where / Issue / Evidence if applicable / Fix scope / Risk of leaving as-is). Verify suspected bugs empirically (actually run the code) before logging them as confirmed, not just from reading.
- Flag when re-syncing either repo would help — e.g. if it's been a while since the last clone/pull in this session, or the user mentions having pushed new edits.

STYLE — "brief for routine code, deep for tricky decisions"

- Cover every function/class, but briefly, when the code is routine (boilerplate, obvious getters, standard patterns).
- Go deep — full reasoning, trade-offs, alternatives considered, performance notes where measured — on non-obvious design decisions, anything that looks like a mistake until verified, and anything a departing architect would otherwise take reasoning about "why" to the grave.
- Tie module-level decisions back to the running framework already established for this book (e.g. the CONSTANT vs Settings vs Setup distinction from the first chapter) rather than re-deriving it each time — cross-reference earlier chapters instead.
- When a module depends on another library that has (or should have) its own separate documentation (e.g. navdict), stay at the "what does this module use it for, and why" level rather than duplicating that library's internals.

FORMATTING

- Plain Markdown only. Standard CommonMark — no mkdocs-specific syntax (no admonitions, no wikilinks, no `{: .class}` tags), since the target editor and export tooling are not yet decided.
- One paragraph, bullet, or field per physical line — no manual hard-wrapping mid-paragraph. Let the editor soft-wrap. Blank lines are the only paragraph/block separator. (This convention was originally chosen for Ulysses' editor but is being kept because it also gives cleaner, more predictable line-level diffs than arbitrary hard-wrapping — revisit if the author wants sentence-per-line instead, which gives even finer-grained diffs but is riskier to auto-generate given inline code spans, abbreviations, and version numbers throughout the text.)
- Preserve fenced code blocks, tables, and headings exactly; only prose gets reflowed onto single lines.
- Headings: number + short noun phrase only. No colons or em-dash explanatory clauses in headings — they wrap badly in printed output and clutter a table of contents. If a heading's hook phrase is worth keeping, add it as a short italic "deck" line directly under the heading instead.

BOOK PRODUCTION (NOT YET DECIDED)

The author currently edits the manuscript as plain Markdown in VS Code or a similar single-file editor — not in Ulysses, which was tried but found too complex for this stage. Final production into PDF/ePub will be figured out later (possibly Ulysses again, possibly Pandoc, possibly something else). Do not assume any particular export tool's constraints (Ulysses-specific formatting rules, a particular Pandoc filter, etc.) unless the author asks for that tool specifically at that time.

BOOK STRUCTURE SO FAR

Chapters completed: settings.py + setup.py (Ch. 4), env.py (Ch. 5), control.py + proxy.py (Ch. 6) — all in cgse-core/cgse-common as noted per chapter.

A full skeleton (Parts I-IV, chapters 1-23, all placeholder/TBW except the three above) was scaffolded on 2026-08-12. It covers Part I (orientation), the rest of Part II (protocol.py+command.py, mixin.py, dummy.py, egse/registry/ — Ch. 7-10), a new Part III "cgse-common: The Utility Toolbox" covering the remaining cgse-common modules in six thematic chapters (Ch. 11-16), and a new Part IV "cgse-core: Middleware Services" covering the cgse-core services one control-server-shaped chapter at a time (Ch. 17-23: storage manager, configuration manager (confman + its async cm_acs rewrite), process manager, log server + listeners, metrics hub + notification hub, monitoring/observation/async control server, the cgse CLI).

Deliberately out of scope for this skeleton: cgse-coordinates, cgse-gui, the generic device-driver projects (projects/generic/*), and the mission-specific projects (projects/ariel/*, projects/ivs/*, projects/plato/*) — planned for a later session. See cgse-book-chapter-index.md for the full current file-by-file breakdown and status.

Chapters were grouped thematically rather than 1:1 with modules for Parts III and IV (this was an explicit author decision, given cgse-common alone has 33 modules and cgse-core 52) — a chapter may cover several small/routine modules together, reserving standalone chapters for modules with real design weight, consistent with the "brief for routine, deep for tricky" style rule.

There is also a separate, related research paper project (CGSE for an instrumentation journal, ten-section structure, Section 6 on multi-mission deployment as the evidentiary core) — related but distinct from this book; don't conflate the two unless asked.
