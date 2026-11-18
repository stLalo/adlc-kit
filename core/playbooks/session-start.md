# Start or resume a session

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: a session id, a change id, or a repo.

## 1. Orient (read-only)
`git fetch --quiet`, `git status`, `git branch --show-current`, `git worktree list`, `git log --oneline -5`.
Read `docs/sessions/INDEX.md` of every enabled repo (`bash K/core/scripts/session-context.sh` lists their open sessions), or only the given repo. A repo without INDEX.md → tell the owner to run `install-repo.sh` on it. Don't invent history.

## 2. Pick the session (first match wins)
a. Input matches a session ID, or a change id with one open session.
b. Launched inside a repo: `active` or `in-review` row whose branch = that repo's current branch.
c. `queued` rows → list them and ask which (propose the oldest unblocked one).
d. Nothing fits → new work starts with `/intent`, not here. Say so.
Never reopen `complete`, `rolled-over` or `abandoned` sessions (they are frozen).

## 3. Model check
Read SESSION.md `kind`. define → the planner model (`role_planner`); build → the builder model (`role_builder`). If the role names a model and you are not it, tell the owner to switch and wait.

## 4a. Queued build session
1. Read SESSION.md, then the `brief` file (BUILD_PROMPT.md) and only the files it names.
2. Blocked-by: read intent.md `blocked-by`. If it names a tag, check `git ls-remote --tags origin <tag>`; if an issue, `K/core/scripts/host.sh issue_state <n>`. Still blocked → report and stop.
3. Branch: `git switch -c feat/<change-id> origin/<main_branch>` (or reuse it if it exists).
4. SESSION.md: status active, branch, worktree, opened. INDEX.md row. Commit `chore(session): open <id>`.
5. Tell the owner to name this conversation `<id>`.

## 4b. Active session (resume)
If `origin/session/<id>` exists (saved while a pull request was open) and has more checkpoints than the working tree, run `K/core/scripts/session-save.sh --restore <id>` first.
Read SESSION.md, the LAST entry of STATE.md, last 5 lines of DECISIONS.md, unchecked tasks in tasks.md.
If the last checkpoint's commit isn't in `git log`, or branch/worktree differ, trust git and say exactly what differs.

## 4c. In-review session
Restore saved logs if needed (as in 4b). Check the pull request: `K/core/scripts/host.sh pr_info <pr>`, `pr_labels <pr>` and `statuses <head-sha>`.
- Merged by the owner → continue `/ship` from the deploy step.
- Open with `needs-human` → summarize the latest judge comment and what the owner must decide; stop.
- Closed unmerged → ask whether to abandon or roll over.

## 5. Report, then wait
Max 5 lines: Session · Goal · Done · Next action · Blockers. Wait for "go" unless the owner said "continue".
Read only what the next action needs.
