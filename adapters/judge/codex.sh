#!/usr/bin/env bash
# Judge adapter: OpenAI Codex CLI, read-only sandbox, output held to the verdict schema.
# usage: codex.sh <prompt-file> <schema-file> <verdict-out.json> [model]
# Uses your saved `codex login`. See adapters/judge/CONTRACT.md. Status: tested by maintainers.
set -euo pipefail
prompt="${1:?prompt file}"; schema="${2:?schema file}"; out="${3:?output file}"; model="${4:-}"
command -v codex >/dev/null || { echo "codex CLI not found" >&2; exit 127; }
args=(exec --sandbox read-only --output-schema "$schema" -o "$out")
[ -z "$model" ] || args+=(-m "$model")
# stdin is closed on purpose: with an open pipe codex waits for more input instead of starting.
codex "${args[@]}" "$(cat "$prompt")" < /dev/null
