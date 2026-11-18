#!/usr/bin/env bash
# Judge adapter template. Copy to adapters/judge/<name>.sh, make it executable, set
# JUDGE_ADAPTER="<name>" in .adlc/config.env. Contract: adapters/judge/CONTRACT.md.
# usage: <name>.sh <prompt-file> <schema-file> <verdict-out.json> [model]
set -euo pipefail
prompt="${1:?prompt file}"; schema="${2:?schema file}"; out="${3:?output file}"; model="${4:-}"

# 1. Run your reviewer on the text in "$prompt". It must be able to read files in the current
#    directory (the repo at the PR head) and the paths the prompt names, and must not write.
# 2. Make it answer with one JSON object that matches "$schema" (JSON Schema).
# 3. Write that object to "$out" and exit 0. Exit non-zero on any failure; core then tries the
#    fallback model, or fails the judge status.
echo "judge adapter not implemented: prompt=$prompt schema=$schema out=$out model=$model" >&2
exit 1
