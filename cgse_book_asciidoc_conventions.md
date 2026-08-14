# AsciiDoc Conventions and Gotchas

This book is migrating from Markdown/Pandoc to AsciiDoc/`asciidoctor-pdf` (decided 2026-08-14, after a side-by-side pilot of Chapter 3 — see `pilot/03-repository-tour.adoc` and the accompanying PDF). The reasons: native code-block callouts, real table column control (`[cols="..."]` instead of Pandoc's dash-count fragility), native captions, and native admonitions — all things the Markdown pipeline either couldn't do or needed custom LaTeX/Lua-filter machinery for.

The trade-off, found during the pilot: AsciiDoc's inline parser has a few silent failure modes that don't print a warning or error — they just render wrong, and the only way to catch them is to actually look at the built PDF page by page, not just check that the build exited cleanly. This file exists so those don't get rediscovered chapter by chapter. Read it before drafting or converting a chapter.

## Confirmed parser gotchas

### 1. Two monospace spans ending in `*` (or `_`) in the same paragraph can pair up as bold/italic

**The bug:** a plain, non-bold monospace span like `` `egse.*` `` — where the trailing `*` is part of the actual content (Python's glob/namespace notation), not a style marker — can have that `*` misinterpreted as an unconstrained-bold delimiter if a *second* monospace span ending in `*` appears later in the same paragraph. The two stray asterisks pair up across both spans, corrupting everything in between, including any other formatting nested in that stretch of text.

Confirmed example (`asciidoctor` 2.0.20):

```asciidoc
the `egse.*` namespace vs the `cgse_*` namespace
```

renders as `` the `egse.<strong></code> namespace vs the `cgse_</strong></code>` `` — both trailing asterisks vanish, invalid nested markup results, and everything between the two spans gets swallowed into a bogus `<strong>`.

**The fix:** use the passthrough monospace form, `` `+text+` ``, for any inline code span whose content ends in `*` or `_`:

```asciidoc
the `+egse.*+` namespace vs the `+cgse_*+` namespace
```

**When this matters:** any time two or more code spans ending in a trailing `*`/`_` appear in the same paragraph or list item — which happens constantly in this book (`egse.*`, `cgse_*`, `projects/generic/*`, and any other glob-style path). A *single* occurrence in a paragraph is safe; the bug only triggers when a second one exists nearby to pair with. Check every paragraph with more than one such span.

### 2. A closing backtick immediately followed by a possessive apostrophe doesn't close the span

**The bug:** `` `symetrie_hexapod`'s `` — no space between the closing backtick and the `'s` — isn't recognized as a valid closing delimiter. The span stays open and silently swallows every character (including other formatting) until the *next* backtick anywhere later in the paragraph, at which point *that* backtick becomes the de facto closing delimiter.

Confirmed example:

```asciidoc
None of `symetrie_hexapod`'s own code is ever imported directly by another package. It exists solely to be _discovered_ — its `pyproject.toml` registers `cgse_explore.py`.
```

renders with one corrupted code span running from `symetrie_hexapod` all the way to `pyproject.toml`, silently consuming the `_discovered_` italic and the intended `pyproject.toml` code span along the way, with no error printed.

**The fix:** use double backticks (the unconstrained monospace form) instead of single backticks whenever a code span is immediately followed by a possessive `'s`:

```asciidoc
None of ``symetrie_hexapod``'s own code is ever imported...
```

**When this matters:** any possessive right after an inline code term — a very common English construction in this book's style ("`cgse-common`'s primitives", "`egse/plugin.py`'s own treatment"). Grep a draft for `` `[^`]+`'s `` before considering it done.

### 3. A Python dunder (`__word__`) inside a monospace span loses its underscores, even alone

**The bug:** unlike gotcha #1 (which needs *two* spans to pair up), a single monospace span is enough to break if its content contains a matched `__word__` substring anywhere — not just as the whole span, also as a suffix like `` `ControlServer.__init__` `` or inside a filename like `` `__init__.py` ``. The leading and trailing double-underscore get consumed as AsciiDoc's unconstrained-italic delimiter (the `__word__` convention), and the whole span's monospace styling breaks along with it.

Confirmed example (`asciidoctor` 2.0.20):

```asciidoc
Where:: `ControlServer.__init__`, the `self.poller.register(...)` line
```

renders as plain text "ControlServer.init" — both pairs of underscores vanish and the code styling is lost, with no error printed.

**The fix:** wrap the entire span content in passthrough, `` `+...+` ``:

```asciidoc
Where:: `+ControlServer.__init__+`, the `self.poller.register(...)` line
```

**When this matters:** any inline (not fenced-code-block) mention of a Python dunder — `__init__`, `__eq__`, `__bool__`, `__getattr__`, `__rich__`, `__init__.py`, etc. This is extremely common in a Python codebase book. Fenced `[source,python]` blocks are unaffected — the bug is specific to inline backtick spans in prose.

## Style rules

### Don't combine inline code and bold

Decided 2026-08-14. Monospace styling (fixed-width, colored in the `asciidoctor-pdf` default theme) is already visually distinct from body prose — bold on top of it is redundant, not clarifying. Bullet-list lead terms should be plain code, not bold-wrapped code:

```asciidoc
* `projects/generic/*` — one package per device or instrument...
```

not

```asciidoc
* *`projects/generic/*`* — one package per device or instrument...
```

This is a style decision, not primarily a workaround for gotcha #1 above — that bug happens between plain (non-bold) code spans too, and still needs the passthrough fix regardless of whether bold is involved. But dropping the bold does eliminate the specific bold-wrapped-glob pattern as one less thing to get wrong.

### 4. Manual heading numbers double up with `:sectnums:`

**The bug:** this book's Markdown source numbered its own headings (`## 1. The Problem of...`, `## 2.1 What it needs to solve`) because Pandoc doesn't number sections automatically. AsciiDoc's book doctype with `:sectnums:` *does* — it also prepends the literal word "Chapter" and a number to every `==`-level heading automatically. Keeping the manual numbers produces doubled-up headings like "6.10. 9. self.service_id vs self._service_id" in the ToC and body.

**The fix:** strip every manual "Chapter N " prefix from `==` headings and every "N." / "N.M" prefix from `===`/`====` headings, and let `:sectnums:` generate all of it. Cross-references in prose ("see Section 7") stay as plain text — they don't need fixing as long as section order in the file isn't changed.

**When this matters:** once, when converting a chapter that carried manual numbering from the Markdown source. Not an ongoing risk once a chapter's headings are clean.

## Verification discipline

All the gotchas above are **silent**: `asciidoctor-pdf` exits 0, prints no warning, and the only symptom is wrong-looking text in the rendered PDF. A clean build is not evidence of correct output. Before considering any chapter conversion done:

1. Build the PDF.
2. Render every page to an image (`gs -dNOPAUSE -dBATCH -sDEVICE=png16m -r150 -sOutputFile=out_%02d.png file.pdf`, since no `pdftotext`/`pdftoppm` is reliably available in this environment — verify what's on hand each session) and actually look at each one.
3. Separately, grep the source for the patterns above — but **do this in Python, not bash/grep**. Backticks inside a bash double-quoted string can trigger command substitution and silently produce a broken pattern with no error; this cost a real miss during the full-book conversion (an appendix entry with `` `uv`'s `` and `` `symetrie-hexapod`'s `` passed a bash-grep check that looked correct but wasn't actually matching). Use `re.findall(...)` on the file contents instead:
   ```python
   import re, glob
   for fn in glob.glob('**/*.adoc', recursive=True):
       content = open(fn, encoding='utf-8').read()
       print(fn, re.findall(r"`[^`]+`'s", content))
   ```
4. A single trailing-`*`/`_` span in a paragraph is safe (gotcha #1 needs two to pair up) — don't over-fix; check per-paragraph, not per-file.

## Resolved: full-migration decisions (2026-08-14)

The migration happened in one pass rather than incrementally. What was actually decided, for reference:

- **Multi-file assembly:** `include::` from a single master document, `src/develop/developer-manual.adoc` (named for the audience — developer guide — not generically `book.adoc` — so a future sibling manual, e.g. an operator/expert-user guide, can be `src/develop/../operator/operator-manual.adoc` without renaming this one). Front matter is wrapped in `:sectnums!:` / `:sectnums:` to stay unnumbered while Parts and chapters are numbered.
- **Directory layout:** everything specific to this manual lives under `src/develop/` (mirroring the precedent in `IvS-KULeuven/plato-cgse-doc`, which hosts five manuals side by side under one `src/` tree); shared assets (`src/themes/`, `src/images/`) sit one level up so a sibling manual can reuse them.
- **PDF theme:** `src/themes/cgse-book-theme.yml`, `extends: default`, minimal — page margins, footer page numbers. Kept intentionally small; add to it only when a real need shows up.
- **Known environment issue, not fixed:** `:front-cover-image:` crashes `asciidoctor-pdf` 2.3.10 on this machine's Ruby 2.6.10 (`undefined method 'absolute_path?' for File:Class` — that method needs Ruby ≥ 2.7). Disabled (commented out with an explanation) in `developer-manual.adoc` rather than worked around. Re-enable once Ruby is upgraded, or once an `asciidoctor-pdf` version compatible with Ruby 2.6 is pinned.
- **Pandoc machinery removal:** `latex/`, `epub/`, `metadata.yaml`, and the old `.md` sources were removed once the AsciiDoc build was verified end-to-end — see git history for the removal commit rather than expecting them to still exist.
