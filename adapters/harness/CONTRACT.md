# Harness adapter contract

A harness adapter connects one coding agent (its "harness": the program that runs the model) to the kit. The core is plain files any agent can read: playbooks in `core/playbooks/`, role briefs in `core/roles/`, and rules in the kit block of the repo's `AGENTS.md`. A harness adapter makes them convenient and, where the agent allows it, enforced.

It is a folder, `adapters/harness/<name>/`, with an `install.sh <repo-path>` that `install-repo.sh --harness <name>` runs. It must be safe to re-run.

## What an adapter can provide

| Capability | What to do | If the agent cannot |
|---|---|---|
| **Entry points** | Turn the eight playbooks into the agent's custom commands or prompt files. | Nothing needed: `AGENTS.md` maps each command name to its playbook. |
| **Roles** | Create a subagent or mode per file in `core/roles/` (`intent-critic`, `intent-critic-deep`, `release-gate`, `verifier`). They must run in a fresh context. | The agent starts a separate session for the role, or the owner does. |
| **Guard on commands and edits** | Before a shell command or file edit runs, call `core/guard/guard.py` (JSON on stdin, exit 2 = block, reason on stderr). Pass the role name so only `release-gate` can post a release decision. | Install `git-hooks` as the floor and say so in your README. |
| **Session context** | Run `core/scripts/session-context.sh` when a session starts. | The agent runs the `sessions` playbook when asked. |
| **Protected paths** | List the files in a repo that hold your hook wiring in `protected_paths.txt` (one regex per line), so the agent cannot switch the guard off. | |
| **Notes** | A short `NOTES.md` mapping the playbooks' neutral words ("ask the owner", "run the role", "planner model") to this agent's features. | |

## Enforcement levels (state yours in `docs/compatibility.md`)

1. **Hooked**: the guard sees every shell command and file edit before it runs. (`claude-code`)
2. **Git-hook floor**: only pushes are checked (`git-hooks`). Rules about merges, statuses and edits are instructions the agent follows, backed by the server-side gate.
3. **Instructions only**: nothing local is enforced. The server-side gate in `docs/server-gate.md` is then the only hard control. Use `merge: human`.

No level replaces the server-side gate. See `docs/security-model.md`.

## Guard interface

```
echo '{"kind":"bash","command":"<command line>","cwd":"<dir>","role":"<role or omit>"}' | python3 core/guard/guard.py
echo '{"kind":"edit","path":"<file>","cwd":"<dir>","content":"<full new text>"}'       | python3 core/guard/guard.py
echo '{"kind":"edit","path":"<file>","cwd":"<dir>","edits":[{"old":"...","new":"..."}]}' | python3 core/guard/guard.py
python3 core/guard/guard.py pre-push <repo-dir> < (git pre-push stdin)
```

Or import it from Python: `guard.check_bash(command, cwd, role)`, `guard.check_edit(path, cwd, content=None, edits=None)`; both raise `guard.Blocked`.

Shipped: `claude-code` (hooked), `codex` (git-hook floor), `git-hooks`. Start a new one from `_template/`.
