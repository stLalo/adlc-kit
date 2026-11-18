#!/usr/bin/env bash
# Judge adapter: Claude Code CLI in print mode, read-only tools, output held to the verdict schema.
# usage: claude.sh <prompt-file> <schema-file> <verdict-out.json> [model]
# For setups whose only agent is Claude Code. The judge is then the same vendor as the builder: run it
# with a different model than the builder when you can. See adapters/judge/CONTRACT.md.
set -euo pipefail
prompt="${1:?prompt file}"; schema="${2:?schema file}"; out="${3:?output file}"; model="${4:-}"
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 127; }
args=(-p --output-format json --json-schema "$(cat "$schema")" --allowedTools "Read,Grep,Glob" --permission-mode default)
# Only your user settings: the checkout under review must not bring its own hooks or permissions.
args+=(--setting-sources user)
[ -z "$model" ] || args+=(--model "$model")
raw=$(claude "${args[@]}" < "$prompt")
printf '%s' "$raw" | python3 -c '
import json, sys
r = json.load(sys.stdin)
v = r.get("structured_output")
if v is None:                      # older CLIs: the JSON object is the text result
    v = json.loads(r["result"])
json.dump(v, open(sys.argv[1], "w", encoding="utf-8"))' "$out"
