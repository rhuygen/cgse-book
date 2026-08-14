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
  CLAUDE.md                           (this file)
  cgse_book_project_instructions.md   (Claude Projects equivalent of this file)
  cgse_book_chapter_index.md          (file-by-file ToC, kept up to date)
  build.sh                            (builds cgse-book.pdf and cgse-book.epub via Pandoc)
  metadata.yaml                       (Pandoc title/author/date metadata)
  TODO.md                             (author's local scratch list — gitignored, not pushed; check it, don't duplicate its contents here since it changes often)
  src/
    front-matter/
      01-title-verso.md
      02-about.md
      03-preface.md
      04-acknowledgments.md
    part-1-orientation/               Ch. 1-3, all TBW
    part-2-core-concepts/             Ch. 4-10 — the client/server foundation
    part-3-common-utilities/          Ch. 11-16 — remaining cgse-common modules
    part-4-core-services/             Ch. 17-24 — cgse-core middleware services
    back-matter/
      01-appendix-pitfalls-cleanup-backlog.md
```

See [cgse_book_chapter_index.md](cgse_book_chapter_index.md) for the full file-by-file breakdown, including which chapters are drafted vs. TBW placeholders.

**Numbering convention:** file numbers restart at `01` within each Part folder; the chapter number in each file's `# Chapter N Title` heading is global across the whole book. When inserting a chapter ahead of existing ones (as happened when the Registry Service chapter was added — see below), renumber every file and heading after it, plus any internal cross-references (`grep -rn "Chapter [0-9]"` across `src/` to find them) — cheap to do while chapters are still TBW placeholders, much less cheap once they're drafted.

Each chapter is a self-contained Markdown file: H1 for the chapter title, H2 for top-level sections, H3/H4 for subsections. Never merge multiple chapters into one file. Never pre-emptively demote heading levels to nest under a "Part" — Parts are just folders for organization; how the book gets assembled (and whether heading levels need adjusting) is a separate, not-yet-decided step.

## Current skeleton status

A full chapter skeleton (Parts I-IV, chapters 1-24) was scaffolded 2026-08-12. Four chapters are drafted (Ch. 3 Repository Tour, Ch. 4 Settings and Setup, Ch. 5 env.py, Ch. 6 control.py/proxy.py); everything else is a TBW placeholder with a scope description, ready to be filled in.

Deliberately out of scope so far: `cgse-coordinates`, `cgse-gui`, the generic device-driver projects (`projects/generic/*`), and the mission-specific projects (`projects/ariel/*`, `projects/ivs/*`, `projects/plato/*`). Planned for a later pass — don't start drafting these without checking in first, since Part numbering/placement isn't decided yet.

Chapters in Part III and Part IV are grouped **thematically**, not 1:1 with modules — an explicit author decision, given `cgse-common` alone has 33 modules and `cgse-core` has 52. A chapter may cover several small/routine modules together; reserve standalone chapters for modules with real design weight (see STYLE below).

**The registry-split precedent:** the Service Registry has both a design/API side and a deployed-service side, so it gets two chapters rather than one: Ch. 10 (Part II) covers the mechanism — why dynamic discovery replaces static ports, how `ControlServer`/`Proxy` opt in. Ch. 17 (Part IV, opening that Part since every other service registers with it) covers running it — backend choice, startup ordering, operations. The two chapters cross-reference each other explicitly rather than duplicating content. If another module turns out to have this same dual nature, split it the same way rather than picking one Part arbitrarily.

## Workflow

- Write new/updated chapters as clean plain-Markdown files, one per module or logical module-group, following the existing naming pattern (`NN-short-name.md`, numbered in reading order within its Part folder).
- After creating or updating a file, present it for review. The author commits and pushes himself — don't commit or push manuscript changes without being explicitly asked to, even though this checkout (unlike the read-only Claude Projects clone) technically has push access.
- Maintain the "Pitfalls and Cleanup Backlog" appendix (`src/back-matter/01-appendix-pitfalls-cleanup-backlog.md`): log any confirmed bug, dead code path, or inconsistency found while writing a chapter, in the existing field format (Module / Where / Issue / Evidence / Fix scope / Risk of leaving as-is). Verify suspected bugs empirically — actually run the code — before logging them as confirmed, not just from reading. Chapters already reference specific pitfall entries by ID (e.g. P-006, P-008); keep those cross-references intact when either side changes.
- When a chapter, the chapter index, and the project instructions all need updating for the same change (e.g. a renumbering, a new Part), update all three in the same pass — they drift out of sync easily otherwise.

## Style — "brief for routine code, deep for tricky decisions"

- Cover every function/class, but briefly, when the code is routine (boilerplate, obvious getters, standard patterns).
- Go deep — full reasoning, trade-offs, alternatives considered, performance notes where measured — on non-obvious design decisions, anything that looks like a mistake until verified, and anything a departing architect would otherwise take reasoning about "why" to the grave.
- Tie module-level decisions back to the running framework already established earlier in the book (e.g. the CONSTANT vs Settings vs Setup distinction from Chapter 4) rather than re-deriving it each time — cross-reference earlier chapters instead. This is also the reasoning behind the registry split above.
- When a module depends on another library that has (or should have) its own documentation (e.g. `navdict`), stay at "what this module uses it for, and why" rather than duplicating that library's internals.

## Formatting

- Plain Markdown only. Standard CommonMark — no mkdocs-specific syntax (no `!!! note` admonitions, no wikilinks, no `{: .class}` tags), since the target editor and export tooling beyond Pandoc aren't fixed yet. Pandoc's own fenced-div syntax (`::: {.classname} ... :::`) is fine — see the callout-box convention below, which uses it; it's a Pandoc-native Markdown extension, not an mkdocs one, and degrades gracefully to a plain `<div class="classname">` in any other renderer.
- **Callout boxes for non-CGSE background concepts** (e.g. "what is a Python namespace package," "what is a context manager"): wrap the explanation in a Pandoc fenced div with class `concept`, lead with a bold label, and close with one link to an authoritative external source for the reader who wants the full formal treatment — don't try to reproduce that source's depth inline. Example:

  ```markdown
  ::: {.concept}
  **Python background: namespace packages.** A regular Python package is one
  directory with an `__init__.py`, owned by exactly one installed distribution...
  See the [Python docs](https://docs.python.org/3/reference/import.html#namespace-packages)
  for the full mechanism.
  :::
  ```

  In the PDF build this renders as a tinted, left-bordered box (styled in `latex/callouts.tex`, converted from the Div via the `latex/div-environments.lua` Pandoc filter — Pandoc does not do div-to-LaTeX-environment conversion automatically, verified directly against the pandoc binary; don't assume otherwise without re-checking). In the ePub build it gets the same tinted, left-bordered look via `epub/callouts.css`, wired in with `--css=epub/callouts.css` — Pandoc embeds the stylesheet into the ePub package and links it from every content page automatically. Only use this for genuinely general background — not for CGSE-specific explanations, which belong in normal prose where they can cross-reference other chapters. First worked example: Chapter 3, Section 6 (namespace packages).
- One paragraph, bullet, or field per physical line — no manual hard-wrapping mid-paragraph. Let the editor soft-wrap. Blank lines are the only paragraph/block separator; this gives cleaner line-level diffs.
- Preserve fenced code blocks, tables, and headings exactly; only prose gets reflowed onto single lines.
- Headings: number + short noun phrase only, no colons or em-dash explanatory clauses — they wrap badly in print and clutter the ToC. If a heading's hook phrase is worth keeping, add it as a short italic "deck" line directly under the heading instead.
- **Pipe tables and PDF output:** Pandoc sizes a pipe table's LaTeX columns from the *dash-count* in the separator row, not from cell content — a short header with a short separator line (e.g. `----`) can render a column far too narrow for its actual content, and inline `` `code` `` spans in an overflowing cell won't wrap (LaTeX can't hyphenate `\texttt`), so they visually overlap the next column instead of erroring. If a table looks fine in the Markdown source but wrong in the built PDF, this is almost certainly why. Fix by rewriting the separator row with dash counts proportional to the widths you actually want (verify with `pandoc file.md -t latex | grep -A5 begin{longtable}` — the `\real{...}` fractions should match your intent), not by reformatting cell content.

## Building the book

`build.sh` runs two Pandoc invocations (PDF via `eisvogel`/`xelatex`, ePub) over every `src/*/​*.md` file in Part order. It globs each Part folder explicitly, so a new Part folder must be added to both invocations in `build.sh`, not just created under `src/`.

`xelatex` is typically installed at `/Library/TeX/texbin/xelatex` on this machine but that directory is often **not** on the shell's default `PATH` in a fresh Claude Code bash session — a bare `bash build.sh` can fail with `'xelatex' not found` even though it's actually installed. Prefix the build with the full PATH before concluding TeX is missing:

```bash
PATH="/Library/TeX/texbin:$PATH" bash build.sh
```

`cgse-book.pdf` and `cgse-book.epub` are both gitignored build outputs — rebuild locally to verify a change, don't expect them to exist or to be committed.

**Missing-character warnings (`Missing character: There is no → ... in font Georgia`):** Georgia doesn't have every Unicode symbol used in prose (e.g. U+2192 for "A → B"). Don't switch the book's main font or the PDF engine to fix this — eisvogel's built-in `mainfontfallback` mechanism only actually works under `lualatex` (it relies on `luaotfload.add_fallback`); under `xelatex`, which this build uses, the same `RawFeature={fallback=...}` option is silently a no-op, so setting `mainfontfallback` won't do anything here despite the template accepting it. The fix in place: `latex/unicode-fallback.tex`, included via `--include-in-header` in `build.sh`, uses `newunicodechar` to route the specific missing characters through **LaTeX's own math-mode symbol fonts** (e.g. `\newunicodechar{→}{\ensuremath{\rightarrow}}`), not a real Unicode font — Computer Modern ships with every TeX Live install on every OS, so the build has no dependency on which system fonts happen to be installed on the machine running it. (An earlier version of this fix routed through "Apple Symbols," a macOS-only system font; that broke on Linux/CI and was replaced for exactly that reason — don't reintroduce a system-font dependency here.) If a new missing-character warning shows up for a symbol with no sensible math-mode equivalent, prefer a font bundled with TeX Live itself (loaded via fontspec's `Path=` option pointing at a font file checked into the repo, e.g. under `latex/fonts/`) over any OS-installed font, so the build stays portable.

**Don't switch to `lualatex` to get automatic fallback "for free."** It was tried and tested directly: `--pdf-engine=lualatex` with `mainfontfallback` set (either "Apple Symbols" or a proper OpenType font like "STIX Two Text") fails outright on this install — `! error: (pdf backend): invalid font identifier when asking 'fontsize'` — even though a minimal eisvogel+lualatex document with plain `mainfont` and no fallback compiles fine. So the specific mechanism (`luaotfload` fallback) that would make lualatex the "correct" engine for this is itself broken with the current TeX Live 2026 + eisvogel combination. Don't re-attempt this without first figuring out the template/package version mismatch behind that error; the `xelatex` + `newunicodechar` workaround above has no such issue and costs one line per new symbol, which so far has been rare enough not to matter.

## Acknowledgments

This book credits Claude as a co-author (`src/front-matter/04-acknowledgments.md`, with a pointer from the copyright/verso page). If asked to update that section, keep it specific about what was actually done in a given session rather than vague, and keep the framing that design-decision judgment calls belong to the author — Claude's role is drafting, verification legwork, and structure.

## Adjacent, don't conflate

There is a separate, related research paper project (CGSE for an instrumentation journal, ten-section structure, Section 6 on multi-mission deployment as the evidentiary core). Related but distinct from this book — don't pull structure or content from one into the other unless asked.
