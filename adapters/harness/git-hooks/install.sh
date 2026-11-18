#!/usr/bin/env bash
# install.sh <repo-path>      Git-hook harness: works with every coding agent, because it lives in git.
# Installs a pre-push hook that asks the ADLC guard: no pushes to protected branches, no tag pushes,
# no force pushes, no branch deletes. It is the floor for agents that have no command hooks.
# It cannot see shell commands or file edits, and `git push --no-verify` skips it: see README.md here.
set -euo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; KIT="$(cd "$H/../../.." && pwd)"
REPO="$(cd "${1:?usage: install.sh <repo-path>}" && pwd)"
hooks="$(git -C "$REPO" rev-parse --git-path hooks)"; case "$hooks" in /*) ;; *) hooks="$REPO/$hooks" ;; esac
mkdir -p "$hooks"; hook="$hooks/pre-push"
if [ -f "$hook" ] && ! grep -qF "adlc-kit" "$hook"; then
  echo "  ⚠ $hook exists and is not from the kit: add this line to it yourself:"
  echo "      python3 \"$KIT/core/guard/guard.py\" pre-push \"\$(git rev-parse --show-toplevel)\" || exit 1"
  exit 0
fi
cat > "$hook" <<HOOK
#!/usr/bin/env bash
# adlc-kit pre-push guard (installed by adapters/harness/git-hooks/install.sh)
exec python3 "$KIT/core/guard/guard.py" pre-push "\$(git rev-parse --show-toplevel)"
HOOK
chmod +x "$hook"
echo "  installed $hook"
