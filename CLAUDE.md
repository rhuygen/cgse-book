# CGSE Book — Working Notes for Claude Code

This repo is the manuscript for *CGSE: A Field Guide*, written by Rik Huygen (the framework's architect) as legacy knowledge transfer ahead of retirement in ~2 years. It covers requirements, architecture, design decisions, and a deep, module-by-module walkthrough of the CGSE codebase — for coworkers to build on afterward.

A parallel, non-technical set of instructions for this same project also exists at [cgse_book_project_instructions.md](cgse_book_project_instructions.md), written for Claude Projects sessions without persistent filesystem/git access. This file is the Claude Code equivalent — same intent, adapted for working directly in a checked-out repo. Keep both roughly in sync when the book's structure or conventions change; [cgse_book_chapter_index.md](cgse_book_chapter_index.md) is the third leg — the up-to-date, file-by-file table of contents.

## Role: structure vs. content

The default job here is **structure, guidance, and hints or suggestions for content** — chapter and section skeletons, scope notes describing what a section should cover, TBW placeholders — not complete drafted prose. Only write full content for a section when explicitly asked to fill in that specific section, or to rephrase/edit specific existing paragraphs.

Within that default, it's still fine — expected, even — to:

- Fill small gaps and correct mistakes or out-of-date content found while working (a stale module reference, a broken cross-reference, a fact that's changed in the source). This is maintenance, not drafting.
- Verify anything corrected against the actual CGSE source (see SOURCE OF TRUTH below) before changing it.

What this rules out: silently expanding a TBW placeholder into full prose, or rewriting a paragraph's wording, without being asked to do exactly that for that section.

**Before any change to a manuscript file** — content or structural — present a short plan (what changes, in which files) and wait for confirmation before editing.

## Source of truth

Two repos:

1. CGSE source code: https://github.com/IvS-KULeuven/cgse — usually already cloned locally alongside this repo (e.g. `~/github/cgse`); if missing, clone it. Either way, treat the checkout as possibly stale — `git pull` or re-clone if it's been a while, and never describe behavior from memory of an earlier session when the actual source is one `Read`/`grep` away. The CGSE source changes frequently, and this book's whole value proposition is being *right about the code as it actually is*, not as it's remembered.
2. This manuscript: https://github.com/rhuygen/cgse-book (current checkout).

Before starting or resuming any chapter, check the current state of that file in this repo first — the author edits chapters directly in VS Code and commits himself. Treat whatever is currently on disk as authoritative over anything drafted in an earlier session. If a chapter already exists, work from its current content and preserve any additions the author has made.

## Repo layout

```
cgse-book/
  CLAUDE.md                             (this file)
  cgse_book_project_instructions.md     (Claude Projects equivalent of this file)
  cgse_book_chapter_index.md            (file-by-file ToC, kept up to date)
  cgse_book_asciidoc_conventions.md     (AsciiDoc parser gotchas + house style — read before converting/drafting)
  build.sh                              (builds cgse-book.pdf via asciidoctor-pdf)
  TODO.md                               (author's local scratch list — gitignored, not pushed; check it, don't duplicate its contents here since it changes often)
  src/
    images/                             (shared assets — logo, cover — used via :imagesdir:)
    themes/
      cgse-book-theme.yml                (asciidoctor-pdf theme, extends: default)
    develop/                             (this manual; a future sibling, e.g. an operator guide, would get its own sibling folder here)
      developer-manual.adoc              (master doc — includes everything below via include::)
      front-matter/
        01-title-verso.adoc
        02-about.adoc
        03-preface.adoc
        04-acknowledgments.adoc
        05-acronyms.adoc
      part-1-orientation/                Ch. 1-3
      part-2-core-concepts/              Ch. 4-10 — the client/server foundation
      part-3-common-utilities/           Ch. 11-16 — remaining cgse-common modules
      part-4-core-services/              Ch. 17-24 — cgse-core middleware services
      back-matter/
        01-appendix-pitfalls-cleanup-backlog.adoc
```

See [cgse_book_chapter_index.md](cgse_book_chapter_index.md) for the full file-by-file breakdown, including which chapters are drafted vs. TBW placeholders. This layout (a `develop/` folder for this manual, shared `themes/`/`images/` one level up) mirrors the precedent in `IvS-KULeuven/plato-cgse-doc`, which hosts several manuals side by side under one `src/` tree — a future sibling manual (e.g. an operator/expert-user guide, discussed but not started) would slot in as `src/operator/` without disturbing this one.

**Numbering convention:** file numbers restart at `01` within each Part folder. Chapter and section numbers are **not** written into the Markdown-era way anymore — `developer-manual.adoc` sets `:sectnums:`, and AsciiDoc's book doctype numbers every `==`/`===`/`====` heading automatically (including prepending the word "Chapter" to `==`-level headings). Do not add manual "Chapter N" or "N.M" prefixes to heading text — they double up with the automatic numbering (confirmed bug, see gotcha #4 in `cgse_book_asciidoc_conventions.md`). Cross-references in prose ("see Section 7") stay as plain text, not live AsciiDoc xrefs, matching the book's existing style.

Each chapter is a self-contained AsciiDoc file: `==` for the chapter title (no "Chapter N" prefix — automatic), `===` for top-level sections, `====` for subsections. Never merge multiple chapters into one file. `developer-manual.adoc` is the only place Part headings (`=`) and `include::` directives live — individual chapter files never include each other.

## Current skeleton status

A full chapter skeleton (Parts I-IV, chapters 1-24) was scaffolded 2026-08-12. Four chapters are drafted (Ch. 3 Repository Tour, Ch. 4 Settings and Setup, Ch. 5 env.py, Ch. 6 control.py/proxy.py); everything else is a TBW placeholder with a scope description, ready to be filled in. The whole manuscript migrated from Markdown/Pandoc to AsciiDoc/`asciidoctor-pdf` on 2026-08-14 (content unchanged, format and toolchain only) — see `cgse_book_asciidoc_conventions.md` for why and for the parser gotchas that migration surfaced.

Deliberately out of scope so far: `cgse-coordinates`, `cgse-gui`, the generic device-driver projects (`projects/generic/*`), and the mission-specific projects (`projects/ariel/*`, `projects/ivs/*`, `projects/plato/*`). Planned for a later pass — don't start drafting these without checking in first, since Part numbering/placement isn't decided yet.

Chapters in Part III and Part IV are grouped **thematically**, not 1:1 with modules — an explicit author decision, given `cgse-common` alone has 33 modules and `cgse-core` has 52. A chapter may cover several small/routine modules together; reserve standalone chapters for modules with real design weight (see STYLE below).

**The registry-split precedent:** the Service Registry has both a design/API side and a deployed-service side, so it gets two chapters rather than one: Ch. 10 (Part II) covers the mechanism — why dynamic discovery replaces static ports, how `ControlServer`/`Proxy` opt in. Ch. 17 (Part IV, opening that Part since every other service registers with it) covers running it — backend choice, startup ordering, operations. The two chapters cross-reference each other explicitly rather than duplicating content. If another module turns out to have this same dual nature, split it the same way rather than picking one Part arbitrarily.

## Workflow

- Write new/updated chapters as clean AsciiDoc files, one per module or logical module-group, following the existing naming pattern (`NN-short-name.adoc`, numbered in reading order within its Part folder).
- Read `cgse_book_asciidoc_conventions.md` before drafting or converting anything — it documents four confirmed, *silent* AsciiDoc parser gotchas (trailing `*`/`_` pairing across spans, possessive apostrophes breaking a code span, dunders losing their underscores, manual numbers doubling with `:sectnums:`) found the hard way during the Markdown→AsciiDoc migration. A clean `asciidoctor-pdf` exit code is not evidence the output is correct — see that file's verification-discipline section. That file also has a prose-style section on applying the ASD-STE100 output style's `-ing` rule — audit against the rule text itself, not against another chapter's existing usage, even one already labeled "rewritten to STE."
- After creating or updating a file, present it for review. The author commits and pushes himself — don't commit or push manuscript changes without being explicitly asked to, even though this checkout (unlike the read-only Claude Projects clone) technically has push access.
- Maintain the "Pitfalls and Cleanup Backlog" appendix (`src/develop/back-matter/01-appendix-pitfalls-cleanup-backlog.adoc`): log any confirmed bug, dead code path, or inconsistency found while writing a chapter, in the existing field format (rendered as an AsciiDoc description list: `Module::` / `Where::` / `Issue::` / `Evidence::` / `Fix scope::` / `Risk of leaving as-is::`). Verify suspected bugs empirically — actually run the code — before logging them as confirmed, not just from reading. Chapters already reference specific pitfall entries by ID (e.g. P-006, P-008); keep those cross-references intact when either side changes.
- When a chapter, the chapter index, and the project instructions all need updating for the same change (e.g. a renumbering, a new Part), update all three in the same pass — they drift out of sync easily otherwise.

## Style — "brief for routine code, deep for tricky decisions"

- Cover every function/class, but briefly, when the code is routine (boilerplate, obvious getters, standard patterns).
- Go deep — full reasoning, trade-offs, alternatives considered, performance notes where measured — on non-obvious design decisions, anything that looks like a mistake until verified, and anything a departing architect would otherwise take reasoning about "why" to the grave.
- Tie module-level decisions back to the running framework already established earlier in the book (e.g. the CONSTANT vs Settings vs Setup distinction from Chapter 4) rather than re-deriving it each time — cross-reference earlier chapters instead. This is also the reasoning behind the registry split above.
- When a module depends on another library that has (or should have) its own documentation (e.g. `navdict`), stay at "what this module uses it for, and why" rather than duplicating that library's internals.

## Formatting

- Plain AsciiDoc. See `cgse_book_asciidoc_conventions.md` for the parser gotchas found so far — read it before writing prose with inline code spans (which is most of this book).
- **Callout boxes for non-CGSE background concepts** (e.g. "what is a Python namespace package," "what is a context manager"): use a native admonition, lead with a bold label as the block title, and close with one link to an authoritative external source for the reader who wants the full formal treatment — don't try to reproduce that source's depth inline. Example:

  ```asciidoc
  [NOTE]
  .Python background: namespace packages
  ====
  A regular Python package is one directory with an `+__init__.py+`, owned by
  exactly one installed distribution... See the
  https://docs.python.org/3/reference/import.html#namespace-packages[Python docs]
  for the full mechanism.
  ====
  ```

  This renders as a real admonition box (icon, tinted background) natively in both PDF and any other AsciiDoc output format — no custom filter or per-format styling needed, unlike the Pandoc-era version of this convention. Only use this for genuinely general background — not for CGSE-specific explanations, which belong in normal prose where they can cross-reference other chapters. First worked example: Chapter 3, Section 6 (namespace packages).
- One paragraph, bullet, or field per physical line — no manual hard-wrapping mid-paragraph. Let the editor soft-wrap. Blank lines are the only paragraph/block separator; this gives cleaner line-level diffs.
- Preserve fenced (`[source,...]` / `----`) code blocks, tables, and headings exactly; only prose gets reflowed onto single lines.
- Headings: short noun phrase only, no manual numbers, no colons or em-dash explanatory clauses — see the numbering convention above (AsciiDoc numbers automatically) and the "why" in `cgse_book_asciidoc_conventions.md` gotcha #4. If a heading's hook phrase is worth keeping, add it as a short italic "deck" line directly under the heading instead.
- **Tables:** use AsciiDoc's native `[cols="..."]` syntax with real column-width ratios, not Pandoc-style pipe tables. This sidesteps the old dash-count fragility entirely — column widths are explicit, not inferred from separator-row punctuation.

## Building the book

`build.sh` runs one `asciidoctor-pdf` invocation over `src/develop/developer-manual.adoc`, which pulls in every chapter via `include::`. Adding a chapter means adding one `include::` line to `developer-manual.adoc` (in the right Part), not touching `build.sh` — unlike the old Pandoc pipeline, which globbed Part folders directly.

```bash
bash build.sh
```

No `PATH` prefix needed — `asciidoctor-pdf` doesn't depend on a separate TeX install the way the old Pandoc/xelatex pipeline did.

**Resolved environment issue (2026-08-14):** `:front-cover-image:` used to crash `asciidoctor-pdf` 2.3.10 on this machine's old system Ruby (2.6.10, `/usr/bin/ruby`) with `undefined method 'absolute_path?' for File:Class` — that method needs Ruby ≥ 2.7. Fixed by installing a modern Ruby via Homebrew (`brew install ruby`, then adding `/opt/homebrew/opt/ruby/bin` ahead of the system Ruby on `PATH` in `.zshrc`) and reinstalling the gems under it (`gem install asciidoctor asciidoctor-pdf asciidoctor-tabs rouge` — gems are per-Ruby-install, so this step is easy to forget after a Ruby upgrade). `:front-cover-image:` is now enabled in `developer-manual.adoc` and confirmed rendering correctly. One thing worth knowing if this ever needs re-diagnosing: a non-interactive shell (e.g. one Claude Code drives) may not source `.zshrc`'s `PATH` changes the way an interactive terminal does — if `ruby -e 'puts RUBY_VERSION'` still shows 2.6.10 in such a shell after the upgrade, that's most likely why; invoking the new Ruby/gem by its full path (or checking `gem environment` for `EXECUTABLE DIRECTORY`) sidesteps it. `bash build.sh` from the user's own interactive terminal is unaffected.

`cgse-book.pdf` is a gitignored build output — rebuild locally to verify a change, don't expect it to exist or to be committed. There is no ePub output anymore (the Pandoc-era build produced one; ePub was never a hard requirement, and reproducing it under AsciiDoc — `asciidoctor-epub3` — hasn't been set up. Revisit if actually needed.)

## Acknowledgments

This book credits Claude as a co-author (`src/develop/front-matter/04-acknowledgments.adoc`, with a pointer from the copyright/verso page). If asked to update that section, keep it specific about what was actually done in a given session rather than vague, and keep the framing that design-decision judgment calls belong to the author — Claude's role is drafting, verification legwork, and structure.

## Adjacent, don't conflate

There is a separate, related research paper project (CGSE for an instrumentation journal, ten-section structure, Section 6 on multi-mission deployment as the evidentiary core). Related but distinct from this book — don't pull structure or content from one into the other unless asked.
