This project is for a technical book documenting the CGSE framework, written by the framework's architect as legacy knowledge transfer ahead of retirement in ~2 years. The book covers requirements, architecture, design decisions, and a deep, module-by-module, function-by-function/class-by-class walkthrough of the actual code — intended for coworkers to build on afterward.

SOURCE OF TRUTH — TWO REPOS, BOTH PUBLIC, BOTH CLONED FRESH EVERY SESSION

1. CGSE source code: https://github.com/IvS-KULeuven/cgse
2. Book manuscript: https://github.com/rhuygen/cgse-book

At the start of any work in this project — every new chat, no exceptions — clone both repos fresh before reading or writing anything:

git clone --depth 1 https://github.com/IvS-KULeuven/cgse.git
git clone --depth 1 https://github.com/rhuygen/cgse-book.git

Never rely on a previous session's clone or on memory of a module's contents. The CGSE source changes frequently; always verify current behavior by reading and, where feasible, running the actual code rather than assuming it matches an earlier chapter.

Before starting or resuming any chapter, check cgse-book for the current state of that file. The author edits the manuscript directly as plain AsciiDoc, in VS Code or a similar editor, and commits/pushes changes himself. Treat whatever is currently in the repo as authoritative over anything drafted earlier in this or another conversation. If a chapter already exists there, work from its current content, not from an earlier draft, and preserve any additions the author has made to it.

REPO LAYOUT

cgse-book/
  cgse_book_project_instructions.md     (this file)
  cgse_book_chapter_index.md            (orientation index, kept up to date)
  cgse_book_asciidoc_conventions.md     (AsciiDoc parser gotchas + house style — read before converting/drafting)
  src/
    images/                              (shared assets — logo, cover)
    themes/
      cgse-book-theme.yml                 (asciidoctor-pdf theme)
    develop/                              (this manual; a future sibling manual, e.g. an operator guide, would get its own sibling folder here — see BOOK PRODUCTION)
      developer-manual.adoc               (master doc — includes everything below via include::)
      front-matter/
        01-title-verso.adoc
        02-about.adoc
        03-preface.adoc
        04-acknowledgments.adoc
        05-acronyms.adoc
      part-1-orientation/
        01-introduction-and-philosophy.adoc   (Ch. 1, TBW)
        02-architecture-at-a-glance.adoc      (Ch. 2, TBW)
        03-repository-tour.adoc               (Ch. 3, drafted)
      part-2-core-concepts/
        01-settings-and-setup.adoc
        02-env.adoc
        03-control-and-proxy.adoc
        07-protocol-and-command.adoc   (Ch. 7, TBW)
        08-mixin.adoc                  (Ch. 8, TBW)
        09-dummy.adoc                  (Ch. 9, TBW)
        10-registry.adoc                (Ch. 10, TBW — registry as design/API; deployed-service side split to Ch. 17)
      part-3-common-utilities/
        (Ch. 11-16, TBW — remaining cgse-common modules, thematically grouped)
      part-4-core-services/
        (Ch. 17-24, TBW — cgse-core middleware services, one per chapter;
         opens with the Registry Service (Ch. 17) since every other service
         here registers with it on startup)
        (more chapters land here as they're written, one file per chapter,
         numbered in reading order within its Part folder)
      back-matter/
        01-appendix-pitfalls-cleanup-backlog.adoc

Each chapter is a self-contained AsciiDoc file: `==` for the chapter title, `===` for top-level sections, `====` for subsections — no manual "Chapter N" or "N.M" numbers in heading text, since `developer-manual.adoc` sets `:sectnums:` and AsciiDoc's book doctype numbers every heading automatically (manual numbers double up with this — a confirmed bug, see the conventions file). Do not merge multiple chapters into one file. Part headings (`=`) and `include::` directives live only in `developer-manual.adoc`, never in individual chapter files.

WORKFLOW

- Write new/updated chapters as clean AsciiDoc files, one per module or logical module-pair, following the existing naming pattern (NN-short-name.adoc, numbered in reading order within its Part folder).
- Read `cgse_book_asciidoc_conventions.md` before drafting or converting anything — it documents confirmed, silent AsciiDoc parser gotchas (found during the 2026-08-14 Markdown→AsciiDoc migration) that don't error, they just render wrong. A clean build is not evidence of correct output; the file's verification-discipline section explains how to actually check.
- After creating or updating a file, present it to the user for review; the user commits/pushes to cgse-book themselves (do not assume push access — there is none, and cloning is read-only).
- Maintain the running "Pitfalls and Cleanup Backlog Appendix" appendix (`src/develop/back-matter/01-appendix-pitfalls-cleanup-backlog.adoc`): log any confirmed bug, dead code path, or inconsistency found while writing a chapter, using the existing field format (an AsciiDoc description list: Module:: / Where:: / Issue:: / Evidence:: if applicable / Fix scope:: / Risk of leaving as-is::). Verify suspected bugs empirically (actually run the code) before logging them as confirmed, not just from reading.
- Flag when re-syncing either repo would help — e.g. if it's been a while since the last clone/pull in this session, or the user mentions having pushed new edits.

STYLE — "brief for routine code, deep for tricky decisions"

- Cover every function/class, but briefly, when the code is routine (boilerplate, obvious getters, standard patterns).
- Go deep — full reasoning, trade-offs, alternatives considered, performance notes where measured — on non-obvious design decisions, anything that looks like a mistake until verified, and anything a departing architect would otherwise take reasoning about "why" to the grave.
- Tie module-level decisions back to the running framework already established for this book (e.g. the CONSTANT vs Settings vs Setup distinction from the first chapter) rather than re-deriving it each time — cross-reference earlier chapters instead.
- When a module depends on another library that has (or should have) its own separate documentation (e.g. navdict), stay at the "what does this module use it for, and why" level rather than duplicating that library's internals.

FORMATTING

- Plain AsciiDoc. See `cgse_book_asciidoc_conventions.md` for the parser gotchas found so far — read it before writing prose with inline code spans (which is most of this book).
- One paragraph, bullet, or field per physical line — no manual hard-wrapping mid-paragraph. Let the editor soft-wrap. Blank lines are the only paragraph/block separator. (This convention was originally chosen for Ulysses' editor but is being kept because it also gives cleaner, more predictable line-level diffs than arbitrary hard-wrapping.)
- Preserve fenced (`[source,...]` / `----`) code blocks, tables, and headings exactly; only prose gets reflowed onto single lines.
- Headings: short noun phrase only, no manual numbers. AsciiDoc's book doctype with `:sectnums:` numbers every heading automatically (including prepending "Chapter" to chapter-level headings) — adding manual "Chapter N" or "N.M" prefixes doubles up with this. No colons or em-dash explanatory clauses in headings either — they wrap badly in printed output and clutter a table of contents. If a heading's hook phrase is worth keeping, add it as a short italic "deck" line directly under the heading instead.
- **Tables:** use AsciiDoc's native `[cols="..."]` syntax with explicit column-width ratios, not Markdown pipe tables.
- **Callout boxes for non-CGSE background concepts** (e.g. "what is a Python namespace package"): use a native admonition, block title as the bold label, close with one link to an authoritative external source rather than reproducing its depth inline:

  ```asciidoc
  [NOTE]
  .Python background: namespace packages
  ====
  A regular Python package is one directory with an `+__init__.py+`, owned by
  exactly one installed distribution...
  See the https://docs.python.org/3/reference/import.html#namespace-packages[Python docs]
  for the full mechanism.
  ====
  ```

  This renders as a real admonition box (icon, tinted background) natively — no custom filter needed, unlike the Pandoc-era version of this convention. Only for genuinely general background, not CGSE-specific explanations. First example: Chapter 3, Section 6.

BOOK PRODUCTION

The author edits the manuscript as plain AsciiDoc in VS Code. Production into PDF is settled and working: `build.sh` in the cgse-book repo runs `asciidoctor-pdf` once over `src/develop/developer-manual.adoc`, which pulls in every chapter via `include::`. The PDF theme is `src/themes/cgse-book-theme.yml` (`extends: default`). Adding a chapter means adding one `include::` line to `developer-manual.adoc`, not touching `build.sh`.

The manuscript migrated from Markdown/Pandoc to AsciiDoc/`asciidoctor-pdf` on 2026-08-14 — content unchanged, format and toolchain only. Reasons: native code-block callouts, native `[cols="..."]` table control, native captions, and native admonitions, none of which the Markdown/Pandoc pipeline could do without custom LaTeX/Lua-filter machinery. The trade-off, found during migration: AsciiDoc's inline parser has several *silent* failure modes (documented in `cgse_book_asciidoc_conventions.md`) — a clean build is not evidence the output is correct.

Known environment issue: `:front-cover-image:` is disabled in `developer-manual.adoc` — it crashes `asciidoctor-pdf` 2.3.10 on Ruby < 2.7 (this environment has 2.6.10). Don't re-enable without checking the Ruby version first.

There is no ePub output anymore (the Pandoc-era build produced one; never a hard requirement). Don't assume a different export tool (Ulysses, mkdocs, etc.) unless the author explicitly asks for that instead.

BOOK STRUCTURE SO FAR

Chapters completed: repository tour (Ch. 3, orientation — no single module, covers the `uv` monorepo layout and the `egse.*`/`cgse.*` entry-point conventions), settings.py + setup.py (Ch. 4), env.py (Ch. 5), control.py + proxy.py (Ch. 6) — Ch. 4-6 in cgse-core/cgse-common as noted per chapter.

A full skeleton (Parts I-IV, chapters 1-24, all placeholder/TBW except the four above) was scaffolded on 2026-08-12. It covers Part I (orientation), the rest of Part II (protocol.py+command.py, mixin.py, dummy.py, egse/registry/ — Ch. 7-10), a new Part III "cgse-common: The Utility Toolbox" covering the remaining cgse-common modules in six thematic chapters (Ch. 11-16), and a new Part IV "cgse-core: Middleware Services" covering the cgse-core services one control-server-shaped chapter at a time (Ch. 17-24: registry service, storage manager, configuration manager (confman + its async cm_acs rewrite), process manager, log server + listeners, metrics hub + notification hub, monitoring/observation/async control server, the cgse CLI).

The Service Registry is split across two chapters on purpose: Ch. 10 (Part II) covers it as design/API — why dynamic discovery replaces static ports, how `ControlServer`/`Proxy` opt in (`registry/client.py`, `registry/service.py`). Ch. 17 (Part IV, opening the Part) covers it as a deployed service — backend choice (`registry/backend.py`, `registry/server.py`), startup ordering, and operations, since every other Part IV service registers itself with it. The two chapters cross-reference each other rather than duplicating content.

Deliberately out of scope for this skeleton: cgse-coordinates, cgse-gui, the generic device-driver projects (projects/generic/*), and the mission-specific projects (projects/ariel/*, projects/ivs/*, projects/plato/*) — planned for a later session. See cgse_book_chapter_index.md for the full current file-by-file breakdown and status.

Chapters were grouped thematically rather than 1:1 with modules for Parts III and IV (this was an explicit author decision, given cgse-common alone has 33 modules and cgse-core 52) — a chapter may cover several small/routine modules together, reserving standalone chapters for modules with real design weight, consistent with the "brief for routine, deep for tricky" style rule.

There is also a separate, related research paper project (CGSE for an instrumentation journal, ten-section structure, Section 6 on multi-mission deployment as the evidentiary core) — related but distinct from this book; don't conflate the two unless asked.
