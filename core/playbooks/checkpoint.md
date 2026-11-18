# Checkpoint

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: an optional note.

1. Find the active session for the current branch in INDEX.md. None → say so and stop.
2. Commit code that belongs to this checkpoint first (conventional message). List unrelated uncommitted work.
3. APPEND one entry to the end of STATE.md (anything else is rejected). Number after the last (CP-1, CP-2...).

```
### CP-<n> · <YYYY-MM-DD HH:MM> · <short title>
- Commit: <short sha> on <branch>
- Verified: `<command>` → <result line>   (one line per proof; no proof = not verified)
- Tasks done: <task numbers from tasks.md>
- In progress: <partial work, or none>
- Uncommitted: <files, or none>
- Next action: <one concrete step a fresh session can start with>
- Watch out: <failed attempts, traps; omit if none>
```

4. Max 10 lines. No logs or diffs.
5. Save it:
   - Check `K/core/scripts/host.sh pr_for_branch <branch>`. Network or auth error → stop and report; don't guess.
   - No pull request for this branch, or only a CLOSED/MERGED one → commit `chore(session): <id> CP-<n>` on the branch.
   - `OPEN` → do NOT commit to the PR branch (a new head drops the judge statuses and reruns CI). Run `K/core/scripts/session-save.sh <id>`; the logs land on the main branch with the close PR.
6. Reply with the entry only.
