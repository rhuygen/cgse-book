echo "Building PDF file: cgse-book.pdf ..."
asciidoctor-pdf \
  -a pdf-theme=cgse-book \
  -a pdf-themesdir=src/themes \
  -o cgse-book.pdf \
  src/develop/developer-manual.adoc
