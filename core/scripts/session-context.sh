#!/usr/bin/env bash
# session-context.sh: lists open sessions in every kit-enabled repo on this machine. Read-only; never
# fails. Harness adapters run it at session start so the agent begins with the current state.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
here="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "ADLC kit: $KIT. Launched in: $here"
found=0
while IFS= read -r repo; do
  [ -f "$repo/.adlc/config.env" ] || continue
  idx="$repo/docs/sessions/INDEX.md"
  rows="$( [ -f "$idx" ] && grep -E '^\|[^|]+\|[^|]+\|[[:space:]]*(active|queued|in-review)[[:space:]]*\|' "$idx" )"
  [ -n "$rows" ] || continue
  found=1
  echo "## $(basename "$repo") (branch: $(git -C "$repo" branch --show-current 2>/dev/null || echo '?'))"
  echo "$rows"
done < <({ cat "$KIT/.adlc/repos" 2>/dev/null; echo "$here"; } | awk 'NF && !seen[$0]++')
[ "$found" = 1 ] || echo "No open sessions. Start new work with the intent playbook: /intent <repo> \"...\"."
echo "Resume with /session-start <session-id>."
exit 0
