---
name: build-book
description: Build the cgse-book PDF with asciidoctor-pdf, or troubleshoot a build failure. Use when the user asks to build, render, or compile the book, runs into an asciidoctor-pdf error, or asks about the Ruby/PATH setup behind build.sh.
---

`build.sh` runs one `asciidoctor-pdf` invocation over `src/develop/developer-manual.adoc`, which pulls in every chapter via `include::`. Adding a chapter means adding one `include::` line to `developer-manual.adoc` (in the right Part), not touching `build.sh` — unlike the old Pandoc pipeline, which globbed Part folders directly.

```bash
bash build.sh
```

No `PATH` prefix needed — `asciidoctor-pdf` doesn't depend on a separate TeX install the way the old Pandoc/xelatex pipeline did.

**Resolved environment issue (2026-08-14):** `:front-cover-image:` used to crash `asciidoctor-pdf` 2.3.10 on this machine's old system Ruby (2.6.10, `/usr/bin/ruby`) with `undefined method 'absolute_path?' for File:Class` — that method needs Ruby ≥ 2.7. Fixed by installing a modern Ruby via Homebrew (`brew install ruby`, then adding `/opt/homebrew/opt/ruby/bin` ahead of the system Ruby on `PATH` in `.zshrc`) and reinstalling the gems under it (`gem install asciidoctor asciidoctor-pdf asciidoctor-tabs rouge` — gems are per-Ruby-install, so this step is easy to forget after a Ruby upgrade). `:front-cover-image:` is now enabled in `developer-manual.adoc` and confirmed rendering correctly. One thing worth knowing if this ever needs re-diagnosing: a non-interactive shell (e.g. one Claude Code drives) may not source `.zshrc`'s `PATH` changes the way an interactive terminal does — if `ruby -e 'puts RUBY_VERSION'` still shows 2.6.10 in such a shell after the upgrade, that's most likely why; invoking the new Ruby/gem by its full path (or checking `gem environment` for `EXECUTABLE DIRECTORY`) sidesteps it. `bash build.sh` from the user's own interactive terminal is unaffected.

`cgse-book.pdf` is a gitignored build output — rebuild locally to verify a change, don't expect it to exist or to be committed. There is no ePub output anymore (the Pandoc-era build produced one; ePub was never a hard requirement, and reproducing it under AsciiDoc — `asciidoctor-epub3` — hasn't been set up. Revisit if actually needed.)
