## ADLC kit (agentic development life cycle)

This repo uses the ADLC kit. The kit folder (`K` below) is the path in `.adlc/kit-path`, also in the environment variable `ADLC_KIT` when your harness sets it. If neither exists, the kit is not installed on this machine: tell the owner to run the kit's `install-repo.sh`.

Intent → spec → build → judge → merge → UAT → prod. Stages hand off through committed files, never conversation.

**Commands.** When the owner types one of these (with or without the slash, or as "adlc <name>"), read the playbook and follow it exactly:

| Command | Playbook |
|---|---|
| `/sessions` | `K/core/playbooks/sessions.md` |
| `/intent <repo> "..."` | `K/core/playbooks/intent.md` |
| `/handoff` | `K/core/playbooks/handoff.md` |
| `/session-start <id>` | `K/core/playbooks/session-start.md` |
| `/checkpoint` | `K/core/playbooks/checkpoint.md` |
| `/ship` | `K/core/playbooks/ship.md` |
| `/promote <change>` | `K/core/playbooks/promote.md` |
| `/session-close [mode]` | `K/core/playbooks/session-close.md` |

Run `K/core/scripts/kit-info.sh [change-id]` to see this repo's folders, adapters, spec-tool steps and role models.

**Roles**
- **The planner defines:** intent, spec, plan and `BUILD_PROMPT.md`. The owner approves; the planner merges the docs PR.
- **The builder builds** from `BUILD_PROMPT.md`. Two failed attempts at the same fix → checkpoint and `/session-close rollover` (kind: define).
- **The judge reviews** through `judge.sh` (an independent, read-only reviewer). Blocking; only the owner overrides.
- **The releaser releases:** the `release-gate` role does the final pre-merge check and the prod approval from UAT evidence. It can block, never override the judge.

**Files**
- Change folder (`change_dir` in `kit-info.sh`): intent.md, proposal, specs, design.md, tasks.md, BUILD_PROMPT.md. Every task ends with `proof:`.
- Sessions: `docs/sessions/<YYYY-MM-DD>-<change-id>-<define|build>/`. Registry: `docs/sessions/INDEX.md`.
- Work across repos = one parent issue with one child intent per repo.

**Rules** (a guard enforces them where your harness supports hooks; they hold everywhere)
- Closed sessions are frozen. STATE.md and DECISIONS.md are append-only. No long output in them or in this file.
- Merge, tag, status posts and deploys only through `K/core/scripts/*`. Never the host's merge command or API, `git tag`, or a push to a protected branch.
- Pull requests, issues and comments go through `K/core/scripts/host.sh`; pushes through `K/core/scripts/agent-push.sh`. They act as the agent's own identity when one is configured.
- Once a pull request is open, checkpoints are saved with `session-save.sh` (branch `session/<id>`), never committed to the PR branch.
- Prod needs `deploy: prod` in intent, UAT tests passed on that exact commit, a rollback command, and release-gate approval. No UAT suite = no prod.
- Never edit the kit, or this repo's `.adlc/config.env`.
- A blocked action is a rule, not an error to work around. Read the reason and use the script it names.

**While working**
- Choosing between real alternatives → append one line to the session's DECISIONS.md right away.
- `/checkpoint` when a task is verified with its proof, direction changes, before a risky step, when the conversation is long, or when asked. "Verified" = command + result.
