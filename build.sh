echo "Building PDF file: cgse-book.pdf ..."
pandoc src/00-preface.md src/part-1-orientation/*.md src/part-2-core-concepts/*.md src/99-appendix-pitfalls-cleanup-backlog.md \
  -o cgse-book.pdf \
  --metadata title="CGSE: A Field Guide" \
  --metadata author="Rik Huygen" \
  --toc --toc-depth=2 \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -V mainfont="Georgia" \
  -V colorlinks=true \
  -V toc-title="Contents"

echo "Building ePub file: cgse-book.epub ..."
pandoc src/00-preface.md src/part-1-orientation/*.md src/part-2-core-concepts/*.md src/99-appendix-pitfalls-cleanup-backlog.md \
  -o cgse-book.epub \
  --metadata title="CGSE: A Field Guide" \
  --metadata author="Rik Huygen" \
  --toc --toc-depth=2
