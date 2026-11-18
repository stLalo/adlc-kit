# Ship

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: a change id (default: the active build session's change).

Run the stages in order. Each stage either passes or stops at a gate; never skip one. The scripts in `K/core/scripts/` are the only way to judge, merge, tag and deploy. Read the policy from intent.md front matter (`merge`, `tag`, `deploy`).

When you stop for the owner: notify them (put it first in your reply if you have no notification tool), write a checkpoint, set SESSION.md status `in-review`, update INDEX.md, and save the logs with `K/core/scripts/session-save.sh <session-id>` (never a commit on the PR branch once the pull request is open). The session can be resumed later with `/session-start`.

## 1. Verify
Run the `verifier` role (in a fresh context: a subagent or a separate session). Fail → fix and re-run. Same failure twice → stop for the owner (or roll over to a define session if the spec is the problem).

## 2. Pull request
First archive the change on the feature branch and commit it (`spec_archive` from `kit-info.sh`): the judge checks acceptance criteria against `specs_dir`, so the spec must be synced in this pull request (an unsynced change fails the judge). The intent stays readable on the main branch until merge.

Push with `K/core/scripts/agent-push.sh -u feat/<change-id>`. From here on, session logs are saved with `session-save.sh`, not committed to this branch. Open the pull request with `K/core/scripts/host.sh pr_create --base <main_branch> --head feat/<change-id> --title <t> --body-file <f>` (or update it with `pr_edit_body`):
- The body includes the line `adlc-change: <change-id>` and a closing reference to the issue.
- Summary of what changed, the acceptance-criteria checklist with evidence, and the verifier result.
Record `pr:` in SESSION.md.

## 3. Judge
`K/core/scripts/judge.sh <pr>`
- exit 0 → approved, continue.
- exit 2 → read the findings in the output. Fix every critical/high and every unmet criterion; fix medium/low when cheap, otherwise reply on the pull request why not. Commit the fix, push, checkpoint (saved with `session-save.sh`), run judge.sh again. (New commit = new judgment; old approvals don't carry over.) With `judge: human` in `kit-info.sh`, exit 2 means the owner has not approved the current head yet: stop for the owner.
- exit 3 → max rounds reached; stop for the owner.
- other → script/tool failure; report it and stop.

## 4. Final check
Run the `release-gate` role with: context **final-check**, the PR number, the change id. It posts `adlc/final-check`.
Reject → if it lists something fixable, fix it and go back to stage 3. Otherwise stop for the owner.

## 5. Merge and tag
- `merge: human` → stop for the owner ("ready to merge").
- `merge: auto` → `K/core/scripts/agent-merge.sh <pr>`. It merges pinned to the judged head with `MERGE_METHOD` and prints the rc tag if `tag: rc`. Rerun it after a partial failure: it skips the merge and reuses an existing tag. Note the merge sha and tag.

## 6. UAT
- `deploy: none` → skip to 8.
- `deploy: uat|prod` → `K/core/scripts/agent-deploy.sh uat <tag-or-merge-sha> <change-id>`. It deploys, then runs the UAT suite.
  - exit 4 (no UAT suite) → note "prod blocked: no UAT suite configured" and skip to 8.
  - deploy or tests fail → stop for the owner with the report path. Don't hot-fix on the main branch.

## 7. Prod
- `deploy: prod` → run `/promote <change-id> <tag-or-merge-sha>`.

## 8. Close
1. Branch `chore/close-<change-id>` from the updated main branch. Uncommitted session logs carry over; if this worktree lacks them, `session-save.sh --restore <session-id>`.
2. `/session-close complete` (writes RECAP with the release trail).
3. Pull request whose body has `adlc-change: <change-id>` → `K/core/scripts/agent-merge.sh <pr> --docs`, then `session-save.sh --drop <session-id>`.

## 9. Report (max 6 lines)
PR, judge rounds, merge sha + tag, UAT result, prod result, anything left over (and whether it needs a new `/intent`).
