#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

normalize() {
  sed -E 's/lastTransitionTime: "[^"]*"/lastTransitionTime: "REDACTED"/g'
}

fail=0
shopt -s nullglob
for example in examples/*/*.yaml; do
  api=$(basename "$(dirname "$example")")
  cloud=$(basename "$example" .yaml)
  composition="apis/${api}/composition.yaml"
  expected="tests/${api}/${cloud}.expected.yaml"
  actual="${tmp}/${api}-${cloud}.actual.yaml"

  echo ">> rendering ${api}/${cloud}"
  crossplane composition render --include-full-xr \
    "$example" "$composition" tests/functions.yaml > "$actual"

  if [[ ! -f "$expected" ]]; then
    echo "   no expected file at ${expected}; actual output:"
    cat "$actual"
    fail=1
    continue
  fi

  if ! diff -u <(normalize < "$expected") <(normalize < "$actual"); then
    echo "   drift in ${api}/${cloud} (actual below)"
    cat "$actual"
    fail=1
  fi
done

exit "$fail"
