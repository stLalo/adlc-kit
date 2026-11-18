# Git-hook harness

Works with every coding agent, because it lives in git, not in the agent.

`install.sh <repo>` writes a `pre-push` hook that asks the guard before any push:
- no push to a protected branch (`ADLC_PROTECTED_BRANCHES` in `kit.env`, plus the repo's `MAIN_BRANCH`)
- no tag push, except by the kit scripts
- no force push, no branch delete

Limits, stated plainly:
- It sees pushes only. It cannot see a direct merge through the host's CLI, a status post, or an edit to a session log.
- `git push --no-verify` skips it. Hooks are per clone and not shared by git.
- It is a seat belt for honest mistakes. The control that holds is on the server: `docs/server-gate.md`.
