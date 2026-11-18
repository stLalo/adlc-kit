# Adapting the kit to your tools

The kit has six plug points. For each one you either use a shipped adapter, write a small one, or skip it knowingly. The [agent install guide](install/AGENT_INSTALL.md) has your coding agent walk through these with you and write the plan.

## Decide per part

| Part | Shipped | You need your own when | Contract |
|---|---|---|---|
| **Host** | `github` | your pull requests live on GitLab, Bitbucket, Azure DevOps, Gitea or an in-house system | [adapters/host/CONTRACT.md](../adapters/host/CONTRACT.md) |
| **Harness** | `claude-code`, `codex`, `git-hooks` | you use Copilot, Cursor or another agent and want commands, roles or hooks wired in | [adapters/harness/CONTRACT.md](../adapters/harness/CONTRACT.md) |
| **Judge** | `codex`, `claude`, `human` | your independent reviewer is another CLI or an internal model gateway | [adapters/judge/CONTRACT.md](../adapters/judge/CONTRACT.md) |
| **Spec** | `openspec`, `plain` | you keep specs in another layout or tool | [adapters/spec/CONTRACT.md](../adapters/spec/CONTRACT.md) |
| **Identity** | `own-login`, `github-app` | you want the agent to act as a bot on a host other than GitHub | [adapters/identity/CONTRACT.md](../adapters/identity/CONTRACT.md) |
| **Secrets** | `env`, `command` | rarely: `command` wraps most secret manager CLIs | [adapters/secrets/CONTRACT.md](../adapters/secrets/CONTRACT.md) |

## Common setups

**Claude Code and Codex on GitHub** (the reference setup)
`--harness claude-code --judge codex --host github`. Planner and releaser on your strongest Claude model, builder on a faster one, Codex judges.

**Only Claude Code**
`--harness claude-code --judge claude`. Set `JUDGE_MODEL` to a different model than your builder. Use `merge: human` for anything above low risk.

**Only Codex**
`--harness codex --judge codex`. No command hooks: you are on the git-hook floor, so the server gate matters most. Default to `merge: human`.

**GitHub Copilot (or Cursor, or another agent) on GitHub**
`--harness git-hooks` today, plus `AGENTS.md`, which most agents read. The agent follows the playbooks from there. `--judge human` unless you have a CLI that can act as judge. To get commands and hooks wired in, write a harness adapter from `adapters/harness/_template/`: it is mostly an install script.

**GitLab or Bitbucket**
Write a host adapter first. It is the only real work: about 30 small functions over your host's CLI or API, with a conformance suite that tells you when you are done. Everything else is unchanged.

**No agent may merge (policy)**
Keep the kit and set `merge: human` in every intent. You still get approved intents, specs, the judge's review on every pull request, and resumable sessions. The owner clicks merge.

**No second model at all**
`--judge human`. An approving review from a repo admin on the exact commit is the verdict.

## Writing a host adapter

1. `cp adapters/host/_template.sh adapters/host/<name>.sh` and fill in each function. Keep `github.sh` open next to it.
2. Create a scratch repo on your host. Clone it.
3. `CONFORMANCE_REPO=/path/to/scratch bash tests/host-conformance.sh <name>` until every line says `ok`.
4. `cp adapters/host/github_rules.py adapters/host/<name>_rules.py` and rewrite the patterns for your host's CLI. Add blocked and allowed examples to `tests/guard_cases.tsv`.
5. Set `HOST_ADAPTER="<name>"` in a repo's `.adlc/config.env`.
6. Protect the main branch: [server-gate.md](server-gate.md).

Things that differ between hosts, and what to do:

| Topic | Guidance |
|---|---|
| Commit statuses | Use the host's commit or build status API. The state must be readable back per commit and context. |
| Pinned merge | Prefer a server-side "merge only if head is X". Otherwise re-check the head right before merging and document the race. |
| Reviews bound to a commit | If approvals are not tied to a commit, only count approvals given after the head commit's push time, or say that your host resets approvals on new commits and require that setting. |
| Admin check | Map to the role that can change branch protection. |
| File list limits | Page through everything. Fail rather than return a partial list. |

## Writing a judge adapter

Ten lines: run your reviewer on the prompt file, make it return JSON matching the schema, write it to the output path. See `adapters/judge/_template.sh`. The judge must be read-only.

## Writing a harness adapter

Start from `adapters/harness/_template/install.sh`. Decide what your agent can do: custom commands, subagents, a hook before commands and edits, a hook at session start. Wire what exists, install `git-hooks` for the rest, and state your enforcement level honestly.

## Roles and models

`ROLE_PLANNER`, `ROLE_BUILDER`, `ROLE_RELEASER`, `ROLE_CRITIC_DEEP` in `.adlc/config.env` are free text shown to the agent ("am I the right model for this session?"). The Claude Code harness also uses them as the `model:` of the subagents it generates, so there they must be names Claude Code accepts. Empty means any model.

## What the installer writes

In your repo:

| Path | Committed | Purpose |
|---|---|---|
| `.adlc/config.env` | yes | repo settings; owner-only; read from the main branch |
| `.adlc/kit-path` | no (git-ignored) | where the kit is on this machine |
| `.adlc/reports/` | no (git-ignored) | UAT reports |
| `docs/sessions/INDEX.md` | yes | session registry |
| `AGENTS.md` (one marked block) | yes | rules and the command-to-playbook map; the rest of your file is kept |
| `.git/hooks/pre-push` | no | git-hook harness |
| `.claude/settings.local.json` | no (git-ignored) | Claude Code: kit path and hooks |
| `.claude/commands/*.md`, `.claude/agents/*.md`, `CLAUDE.md` | yes | Claude Code: generated commands and subagents |

In the kit folder, machine-local and git-ignored: `.adlc/kit.env` (settings) and `.adlc/repos` (the repos you enabled).

No symlinks. No changes outside your repo and the kit folder.

## Several repos, a team

- One kit clone per machine serves any number of repos.
- Each teammate clones the kit and runs `install-repo.sh` once per repo; the committed files are shared, the machine-local ones are theirs.
- Pin the kit version for a team by checking out a tag in everyone's clone.
- Multi-repo work is one parent issue with one intent per repo.
