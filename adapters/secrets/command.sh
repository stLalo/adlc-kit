#!/usr/bin/env bash
# Secrets adapter: command. usage: command.sh NAME=<ref>... -- <command...>
# Reads each secret by running SECRET_CMD (set in kit.env) with the ref as its last argument, e.g.
#   SECRET_CMD="op read"                      ref: op://vault/item/field
#   SECRET_CMD="vault kv get -field=value"    ref: secret/adlc/app-key
#   SECRET_CMD="pass show"                    ref: adlc/app-key
# Runs <command> with each NAME set. Values never appear in argv. See adapters/secrets/CONTRACT.md.
set -euo pipefail
[ -n "${SECRET_CMD:-}" ] || { echo "✗ SECRET_CMD is not set in kit.env" >&2; exit 3; }
read -r -a reader <<<"$SECRET_CMD"
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  name="${1%%=*}"; ref="${1#*=}"; shift
  value="$("${reader[@]}" "$ref")" || { echo "✗ could not read the secret for $name" >&2; exit 3; }
  [ -n "$value" ] || { echo "✗ secret for $name is empty" >&2; exit 3; }
  export "$name=$value"
done
[ "${1:-}" = "--" ] && shift
exec "$@"
