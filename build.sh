echo "Building PDF file: cgse-book.pdf ..."
/Users/rik/homebrew/lib/ruby/gems/4.0.0/bin/asciidoctor-pdf \
  -a pdf-theme=cgse-book \
  -a pdf-themesdir=src/themes \
  -o cgse-book.pdf \
  src/develop/developer-manual.adoc
