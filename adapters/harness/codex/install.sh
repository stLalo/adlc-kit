#!/usr/bin/env bash
# install.sh <repo-path>      Codex CLI harness for one repo.
# Codex reads AGENTS.md, which install-repo.sh already fills with the kit block (rules plus the map
# from each command to its playbook), and finds the kit through .adlc/kit-path. Codex has no hook this
# kit can use to check commands before they run, so enforcement here is the git pre-push hook plus the
# server-side gate. See NOTES.md in this folder.
set -euo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${1:?usage: install.sh <repo-path>}" && pwd)"
"$H/../git-hooks/install.sh" "$REPO"
echo "  Codex harness ready: start codex in this repo and say e.g. \"adlc sessions\" or \"adlc ship\"."
