# Compatibility

What has been run, by whom, and how. A row is only as good as its evidence.

## Tiers

| Tier | Meaning |
|---|---|
| **Tested** | A maintainer runs it. It is covered by the offline suite, and where a real service is involved, by a live run recorded below. Regressions block a release. |
| **Community** | Contributed with evidence of a real run (command and output in the pull request) and a named person who agreed to look at issues. Not run by maintainers. |
| **Experimental** | Merged so others can try and improve it. May not work. |
| **Contract only** | No adapter yet. The contract, a template and a test exist. |

## Host

| Host | Adapter | Tier | Evidence |
|---|---|---|---|
| GitHub (github.com) | `github` | Tested | `tests/run.sh` (fake CLI); `tests/host-conformance.sh github` against a live repository (38 checks); one live change from intent to rc tag, with three judge rounds |
| GitHub Enterprise Server | `github` | Experimental | Same adapter; `host_push` and the app identity take the host from the remote and `ADLC_GITHUB_API`. Not run by maintainers. |
| GitLab, Bitbucket, Azure DevOps, Gitea | none | Contract only | `adapters/host/_template.sh` |

## Coding agent (harness)

| Agent | Adapter | Enforcement | Tier | Evidence |
|---|---|---|---|---|
| Claude Code | `claude-code` | Hooked: every shell command and file edit | Tested | guard matrix through the real hook entry point; generated commands and subagents; live flow |
| Codex CLI | `codex` | Git-hook floor | Tested | reads the kit block in `AGENTS.md`; pre-push hook |
| Any agent | `git-hooks` | Git-hook floor | Tested | pre-push hook against a real push in the suite |
| GitHub Copilot, Cursor, others | none | Instructions via `AGENTS.md` + git-hook floor | Contract only | `adapters/harness/_template/` |

## Judge

| Judge | Adapter | Tier | Evidence |
|---|---|---|---|
| Codex CLI | `codex` | Tested | live verdict on a sample change; `judge.sh` flow in the suite |
| Claude Code CLI | `claude` | Tested | live verdict on a sample change |
| Human reviewer | `human` (built in) | Tested | suite: pending without review, success with an admin approval of the exact commit |

## Spec tool

| Tool | Adapter | Tier | Evidence |
|---|---|---|---|
| OpenSpec | `openspec` | Tested | suite: intent from the main branch, archive move, docs-only merges |
| Plain markdown | `plain` | Tested | suite: merge reads intent from `docs/changes/` |

## Identity and secrets

| Part | Adapter | Tier | Evidence |
|---|---|---|---|
| Your own login | `own-login` | Tested | every suite run |
| GitHub App bot | `github-app` | Tested offline | suite: the JWT is verified against a throwaway key and the token request is checked. Minting against github.com is the same code path that ran in private use before extraction; it is not part of the public suite because it needs a real app. |
| Secrets from env or file | `env` | Tested | suite |
| Secrets from a CLI | `command` | Tested | suite, with a stand-in command. Not run against a specific secret manager. |

## Platforms

| Platform | Tier | Evidence |
|---|---|---|
| Linux | Tested | CI and maintainer machines |
| macOS | Tested in CI | the offline suite runs on a macOS runner (system bash 3.2, BSD tools) |
| Windows (WSL) | Tested | maintainer machine (WSL 2) |
| Windows (native) | Not supported | bash scripts |

## Report your setup

Ran the kit somewhere not listed, or found a row that is wrong? Open a **Compatibility report** issue. It takes five minutes and helps the next person.
