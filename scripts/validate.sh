#!/usr/bin/env bash
set -euo pipefail

# v2.3+ CLI dropped the standalone validate command. `xpkg build` is a
# strict structural check: XRDs/Compositions/metadata must parse and
# cross-reference correctly or the build fails.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

crossplane xpkg build \
  --package-root=. \
  --examples-root=./examples \
  --ignore=".github/workflows/*.yaml,tests/functions.yaml,tests/*/*.yaml" \
  --package-file="${tmp}/skylab-platform.xpkg"

echo ">> package built OK"
