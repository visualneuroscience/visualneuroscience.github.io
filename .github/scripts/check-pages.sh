#!/usr/bin/env bash
# Checks that every page is in the sidebar and on its section page, and that
# its header has a title, description, categories and a date as YYYY-MM-DD.
# Run from the repository root: bash .github/scripts/check-pages.sh

status=0
error() { echo "::error file=$1::$2"; status=1; }

for page in $(git ls-files '*/*.qmd' ':!*/index.qmd'); do
  section=${page%%/*}
  grep -qF "$page" _quarto.yml || error "$page" "not in the sidebar in _quarto.yml"
  grep -qF "${page#*/}" "$section/index.qmd" || error "$page" "not in $section/index.qmd"
  for key in title description categories; do
    grep -q "^$key:" "$page" || error "$page" "no '$key:' in the header"
  done
  grep -Eq '^date: "?[0-9]{4}-[0-9]{2}-[0-9]{2}' "$page" || error "$page" "no 'date:' as YYYY-MM-DD in the header"
done

exit $status
