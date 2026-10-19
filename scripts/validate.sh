#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
for composition in apis/*/composition.yaml; do
  api_dir=$(dirname "$composition")
  xrd="${api_dir}/definition.yaml"
  echo ">> validating ${api_dir}"
  crossplane beta validate "$xrd" "$composition"
done
