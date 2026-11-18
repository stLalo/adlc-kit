# Sessions overview (read-only: change nothing)

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: `all` to include closed sessions.

1. For every enabled repo (the paths in `K/.adlc/repos`, plus the repo you are in), read its `docs/sessions/INDEX.md` and run `git fetch --quiet`, `git branch -a --list`, `git worktree list`, `git branch --show-current`.
2. One table per repo of `queued`, `active` and `in-review` sessions (all if the input is `all`): ID, kind, status, change, PR, last checkpoint (title + date), next action. Mark the current branch's session with →.
3. For `in-review`: the pull request state and the latest `adlc/*` statuses on its head (`K/core/scripts/host.sh pr_info <pr>`, then `statuses <head-sha>`).
4. For `queued`: is it blocked? (intent.md `blocked-by` tag/issue.)
5. Flag problems, one line each, with a suggested fix (don't apply it):
   - active/in-review session whose branch is gone
   - in-review session whose pull request was merged (→ `/session-start` it to continue ship)
   - two active sessions on the same branch
   - rolled-over session whose `rolled_to` folder is missing
   - folder without an INDEX.md row, or a row without a folder
   - active session with no checkpoint in 7+ days
   - open change in `changes_dir` with no session
