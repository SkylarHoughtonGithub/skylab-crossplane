#!/usr/bin/env bash
set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

normalize() {
  python3 -c '
import sys, re, yaml
content = sys.stdin.read()
content = re.sub(r"lastTransitionTime:\s*\"[^\"]*\"", "lastTransitionTime: \"REDACTED\"", content)
docs = [d for d in yaml.safe_load_all(content) if d]
docs.sort(key=lambda d: (
    d.get("apiVersion", ""),
    d.get("kind", ""),
    (d.get("metadata") or {}).get("name", ""),
))
for d in docs:
    print("---")
    print(yaml.dump(d, sort_keys=True, default_flow_style=False), end="")
'
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
