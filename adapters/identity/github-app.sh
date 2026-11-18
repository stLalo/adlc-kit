#!/usr/bin/env bash
# Identity adapter: GitHub App. Prints a one-hour installation token on stdout, so the agent pushes,
# comments and posts statuses as the app's bot user instead of as you.
#
# Configure in $ADLC_KIT/.adlc/kit.env (machine-local, never committed):
#   IDENTITY_ADAPTER="github-app"
#   ADLC_APP_CLIENT_ID_REF, ADLC_APP_INSTALLATION_ID_REF, ADLC_APP_PRIVATE_KEY_REF
#       references the secrets adapter understands (see adapters/secrets/CONTRACT.md)
#   ADLC_GITHUB_API="https://api.github.com"     (GitHub Enterprise: https://<host>/api/v3)
#
# The secrets reach this script only as environment variables set by the secrets adapter, never argv.
# Exit 1 = not configured (callers use the user's login); any other failure exits 3.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -z "${APP_PRIVATE_KEY:-}" ]; then
  unset ADLC_APP_CLIENT_ID_REF ADLC_APP_INSTALLATION_ID_REF ADLC_APP_PRIVATE_KEY_REF ADLC_GITHUB_API SECRETS_ADAPTER SECRET_CMD
  # shellcheck disable=SC1091
  [ -f "$KIT/.adlc/kit.env" ] && source "$KIT/.adlc/kit.env"
  [ -n "${ADLC_APP_PRIVATE_KEY_REF:-}" ] || exit 1
  secrets="$KIT/adapters/secrets/${SECRETS_ADAPTER:-env}.sh"
  [ -x "$secrets" ] || { echo "✗ secrets adapter '${SECRETS_ADAPTER:-env}' not found" >&2; exit 3; }
  export SECRET_CMD="${SECRET_CMD:-}" ADLC_GITHUB_API="${ADLC_GITHUB_API:-https://api.github.com}"
  exec "$secrets" \
    APP_CLIENT_ID="${ADLC_APP_CLIENT_ID_REF:?}" \
    APP_INSTALLATION_ID="${ADLC_APP_INSTALLATION_ID_REF:?}" \
    APP_PRIVATE_KEY="$ADLC_APP_PRIVATE_KEY_REF" \
    -- "$0"
fi

: "${APP_CLIENT_ID:?}" "${APP_INSTALLATION_ID:?}"
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
# iat 60s back absorbs clock drift; GitHub rejects exp more than 10 minutes out.
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now-60)) $((now+540)) "$APP_CLIENT_ID" | b64url)
keyfile=$(mktemp); trap 'rm -f "$keyfile"' EXIT; chmod 600 "$keyfile"
printf '%s\n' "$APP_PRIVATE_KEY" > "$keyfile"
sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$keyfile" | b64url)
# The JWT goes to curl on stdin (-K -), never argv.
printf 'header = "Authorization: Bearer %s"\n' "$header.$payload.$sig" | curl -fsS -K - -X POST \
  -H "Accept: application/vnd.github+json" \
  "${ADLC_GITHUB_API:-https://api.github.com}/app/installations/$APP_INSTALLATION_ID/access_tokens" \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["token"])' \
  || { echo "✗ GitHub App token request failed" >&2; exit 3; }
