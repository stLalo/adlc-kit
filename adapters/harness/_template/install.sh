#!/usr/bin/env bash
# Harness adapter template. Copy this folder to adapters/harness/<your-agent>/ and adapt.
# Contract: adapters/harness/CONTRACT.md. usage: install.sh <repo-path>
set -euo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # KIT is for the steps you add below
KIT="$(cd "$H/../../.." && pwd)"
REPO="$(cd "${1:?usage: install.sh <repo-path>}" && pwd)"

# 1. Entry points: make the eight playbooks in $KIT/core/playbooks/ easy to start in your agent
#    (custom commands, prompt files, rules files). AGENTS.md already maps each command to its playbook.
# 2. Roles: if your agent has subagents or separate modes, create one per file in $KIT/core/roles/.
# 3. Guard: if your agent can run a program before a shell command or a file edit, call the guard:
#       echo '{"kind":"bash","command":"<cmd>","cwd":"<dir>","role":"<role or empty>"}' | python3 "$KIT/core/guard/guard.py"
#       echo '{"kind":"edit","path":"<file>","cwd":"<dir>","content":"<full new text>"}' | python3 "$KIT/core/guard/guard.py"
#    Exit 2 = block and show stderr to the agent. If it cannot, install the git-hook floor instead:
"$H/../git-hooks/install.sh" "$REPO"
# 4. Session start: if your agent can run a program when a session starts, run
#       bash "$KIT/core/scripts/session-context.sh"
# 5. List files in the repo that only the owner may edit (your hook config) in protected_paths.txt.
echo "  template harness: only the git pre-push hook was installed for $REPO"
