#!/usr/bin/env bash
# Secrets adapter: environment. usage: env.sh NAME=<ref>... -- <command...>
# A <ref> is the name of an environment variable that already holds the secret (for example one your
# CI or shell profile injects), or file:<path> to read the secret from a file.
# Runs <command> with each NAME set. Values never appear in argv. See adapters/secrets/CONTRACT.md.
set -euo pipefail
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  name="${1%%=*}"; ref="${1#*=}"; shift
  case "$ref" in
    file:*) [ -r "${ref#file:}" ] || { echo "✗ secret file for $name is not readable" >&2; exit 3; }
            value="$(cat "${ref#file:}")" ;;
    *)      [[ "$ref" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "✗ secret ref for $name must be a variable name or file:<path>" >&2; exit 3; }
            value="${!ref:-}" ;;
  esac
  [ -n "$value" ] || { echo "✗ secret for $name is empty" >&2; exit 3; }
  export "$name=$value"
done
[ "${1:-}" = "--" ] && shift
exec "$@"
