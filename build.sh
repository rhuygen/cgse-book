echo "Building PDF file: cgse-book.pdf ..."
pandoc src/front-matter/*.md src/part-1-orientation/*.md src/part-2-core-concepts/*.md src/back-matter/*.md \
  -o cgse-book.pdf \
  --from markdown \
  --template eisvogel \
  --syntax-highlighting=idiomatic \
  --metadata-file=metadata.yaml \
  --metadata book=true \
  --metadata titlepage=true \
  --metadata titlepage-color="FFFFFF" \
  --metadata titlepage-rule-color="360049" \
  --metadata titlepage-logo="src/images/cover.png" \
  --metadata logo-width="250pt" \
  --top-level-division=chapter \
  --toc --toc-depth=2 \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -V mainfont="Georgia" \
  -V colorlinks=true \
  -V toc-title="Contents" \
  -V classoption=oneside

echo "Building ePub file: cgse-book.epub ..."
pandoc src/front-matter/*.md src/part-1-orientation/*.md src/part-2-core-concepts/*.md src/back-matter/*.md \
  -o cgse-book.epub \
  --metadata-file=metadata.yaml \
  --toc --toc-depth=2