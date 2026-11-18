# Host adapter contract

A host adapter teaches the kit to talk to one code host (GitHub, GitLab, Bitbucket, Azure DevOps, Gitea, an in-house system). It is one bash file, `adapters/host/<name>.sh`, that `core/scripts/lib.sh` sources. Core never calls a host CLI or API itself.

- Start from `_template.sh`. The reference is `github.sh`.
- Select it per repo with `HOST_ADAPTER="<name>"` in `.adlc/config.env`.
- Prove it with `tests/host-conformance.sh <name>` against a throwaway repo. Every check must pass.
- Add `<name>_rules.py` so the guard blocks the direct routes around the gates on your host.

"PR" below means whatever your host calls a reviewable merge request.

## Rules for every function

- Print only the documented output on stdout. Errors go to stderr with a non-zero exit.
- Never print a credential, and never put one in a command's arguments.
- Use `die "<message>"` for failures the user must fix.
- When `$ADLC_HOST_TOKEN` is set, act as that identity. Core calls `host_use_token <token>` first.

## Setup

| Function | Input | Output / behaviour |
|---|---|---|
| `HOST_TOKEN_VARS` | (variable) | Names of environment variables that carry a credential for this host. Core removes them before it runs repo code (tests, deploys) or the judge. |
| `host_use_token` | `<token>` | Make later calls use this token. |
| `host_check` | | Die unless the host CLI is installed and logged in. |
| `host_repo_id` | | The repo's id on the host, for example `group/project`. |

## Reads

| Function | Input | Output |
|---|---|---|
| `host_pr_info` | `<pr>` | One line: `<OPEN\|MERGED\|CLOSED> <head sha> <head branch> <true\|false>` (last field: the PR comes from a fork). |
| `host_pr_head` | `<pr>` | Head commit sha (40 hex). |
| `host_pr_body` | `<pr>` | Description text. |
| `host_pr_diff` | `<pr>` | Unified diff. |
| `host_pr_labels` | `<pr>` | One label per line. |
| `host_pr_checks` | `<pr>` | `<check name>\t<state>` per line (CI results; informational). |
| `host_pr_comments` | `<pr>` | Comment bodies, oldest first. The judge counts its rounds from them. |
| `host_pr_mergeable` | `<pr>` | Exit 0 only if the PR can merge without conflicts. If the host computes this in the background, wait for the answer (bounded) instead of failing. |
| `host_pr_merge_commit` | `<pr>` | Merge commit sha of a merged PR. |
| `host_pr_for_branch` | `<branch>` | `<number> <OPEN\|MERGED\|CLOSED>` for the newest PR from that branch, or nothing. |
| `host_pr_files` | `<pr>` | `<path>\t<old path or empty>\t<added\|modified\|removed\|renamed>\t<changed lines>` per file. **Must fail if the list is incomplete** (pagination, API caps): a short list could hide a code file in a docs-only merge. |
| `host_pr_approvers_at` | `<pr> <sha>` | Users whose latest decisive review approves exactly `<sha>`. An approval of an older commit, or one later withdrawn, does not count. |
| `host_user_is_admin` | `<user>` | Exit 0 only for people allowed to set policy on the repo (admin, owner, maintainer: pick the role that can change branch protection). |
| `host_issue_state` / `host_issue_body` | `<n>` | `OPEN\|CLOSED` / description text. |
| `host_status_get` | `<sha> <context>` | Latest state for that context: `success`, `failure` or `pending`. Nothing if there is none. |
| `host_statuses` | `<sha>` | `<context>\t<state>\t<description>` per line. |

## Ordinary writes (agents reach these through `host.sh`)

| Function | Input | Output |
|---|---|---|
| `host_pr_create` | `--base <b> --head <h> --title <t> --body-file <f>` | The new PR number, digits only. |
| `host_pr_edit_body` | `<pr> <file>` | |
| `host_pr_comment` | `<pr> <file>` | |
| `host_issue_create` | `--title <t> --body-file <f>` | The new issue number, digits only. |

## Gated writes (only core scripts call these)

| Function | Input | Output / behaviour |
|---|---|---|
| `host_pr_merge_pinned` | `<pr> <sha> <merge\|squash>` | Merge commit sha. **Must fail if the PR head is no longer `<sha>`.** If your host has no server-side pinned merge, re-read the head immediately before merging and say in your adapter's header that a small race remains. |
| `host_branch_delete` | `<branch>` | Delete the branch on the host. |
| `host_status_post` | `<sha> <context> <success\|failure\|pending> <description>` | Attach a status to that exact commit. Contexts are `adlc/judge`, `adlc/final-check`, `adlc/uat-deploy`, `adlc/uat-tests`, `adlc/prod-approval`, `adlc/prod-deploy`. A host without commit statuses can map them to build statuses or labelled comments, as long as `host_status_get` reads back the latest one for the same commit. |
| `host_pr_label_add` | `<pr> <label>` | |
| `host_label_ensure` | `<label> <description>` | Create the label if missing. Exit 0 if it exists afterwards. |
| `host_push` | `<git push args...>` | Push to origin's repo as `$ADLC_HOST_TOKEN`. The token must reach git through a credential helper or an environment variable, never argv or the remote URL saved in config. |

## Guard rule pack

`adapters/host/<name>_rules.py` defines `RULES = [(regex, reason), ...]`. Block, for your host's CLI and API:
direct PR merges, status or check writes, tag and ref writes, release creation, branch-protection changes, PR approvals, removing `needs-human`, and reading the stored token. Add each rule to `tests/guard_cases.tsv` with one blocked and one allowed example.
