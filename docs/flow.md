# The flow: how to drive it

**In short:** start with `/sessions`. Then `/session-start <id>`, work, `/checkpoint`, `/ship`.
**New idea?** `/intent <repo> "what you want"`.

Commands are playbooks in `core/playbooks/`. In Claude Code they are slash commands. In other agents, type the name ("adlc ship") and the agent reads the playbook named in your repo's `AGENTS.md`.

## The eight commands

| Command | What it does | Role |
|---|---|---|
| `/sessions` | Lists queued, active and in-review work in every enabled repo. Read-only. | any |
| `/intent <repo> "..."` | Turns your words into an approved `intent.md`. Starts a **define** session. | planner |
| `/handoff` | Ends a define session: checks the spec, writes `BUILD_PROMPT.md`, queues the build. | planner |
| `/session-start <id>` | Opens a queued session or resumes an active one. | planner to define, builder to build |
| `/checkpoint "note"` | Saves progress to `STATE.md` so any session can pick up later. Once a pull request is open it saves to branch `session/<id>`, so the judged commit and CI stay put. | any |
| `/ship` | Takes a finished build through verify, pull request, judge, final check, merge, tag and UAT. | builder |
| `/promote <change>` | Moves a UAT-tested release to prod. Fails if evidence is missing. | releaser |
| `/session-close [mode]` | Ends a session: `complete`, `rollover`, `in-review` or `abandon`. | any |

## Normal sequence, idea to prod

1. `/sessions`: see what is waiting.
2. On the planner model, `/intent my-repo "..."`: answer its questions and approve the intent.
3. Write the spec with the planner (proposal, design, tasks).
4. `/handoff`: approve the build prompt. Approve the docs pull request on your host; the agent merges it.
5. **New conversation** on the builder model: `/session-start <build-id>`.
6. Build. `/checkpoint` after each verified task.
7. `/ship`: the judge and gates run. Merge and UAT happen if the intent's policy allows them.
8. `/promote <change>`: only if the intent says `deploy: prod`.

## The policy in every intent

```yaml
merge: auto      # auto | human      may the script merge when the gates are green?
tag: rc          # none | rc         tag vX.Y.Z-rc.N on the merge commit?
deploy: uat      # none | uat | prod how far may this change go?
release: 1.4.0   # version the tags use
risk: low        # low | medium | high
```

Use `merge: human` for auth, data migrations, infrastructure, public API contracts and secrets, and whenever your judge is not independent.

## Other situations

**1. The chat got long, or you are out of time**
- `/checkpoint "stopping here"`, then close the window.
- Later: `/session-start <same id>` resumes from the last checkpoint.

**2. The build hits a wall (two failed fixes, or the spec is wrong)**
- `/session-close rollover`: it writes the next brief.
- If the spec is the problem, the next session is a **define** session, not a build.

**3. The work is waiting on you (merge review, "needs-human", UAT failed)**
- `/session-close in-review`: parks it without closing.
- When you are done: `/session-start <id>` picks up where `/ship` stopped.

**4. The idea is dead or replaced**
- `/session-close abandon`: one line of why. The folder freezes as history.

**5. You just want a status check**
- `/sessions` only. It changes nothing and flags problems, like a merged pull request or a missing branch.

**6. The work spans repos**
- `/intent` creates one parent issue and one intent per repo.
- Run each repo's sessions on its own, in order.

**7. You change your mind mid-session**
- Say "stop, don't do X": that work would follow the old spec, and the judge checks against it.
- Small (how it is built, not what it does): tell the agent, then `/checkpoint "direction change: ..."`.
- Big (behaviour or acceptance criteria change): `/checkpoint`, then `/session-close rollover` and choose **define**. In a new chat on the planner model, `/session-start <new id>`, then `/handoff`.
- Already merged by an earlier session: `/intent <repo> "change X because Y"`.

## Where things live

| What | Where |
|---|---|
| Session registry | `<repo>/docs/sessions/INDEX.md` |
| Intent and spec | the change folder (`kit-info.sh` prints it; `openspec/changes/<id>/` with OpenSpec) |
| Repo settings | `<repo>/.adlc/config.env` (owner-only, read from the main branch) |
| Machine settings | `<kit>/.adlc/kit.env` (never committed) |
| Session logs while a pull request is open | branch `session/<session-id>` (`session-save.sh`, `--restore`, `--drop`) |
| UAT reports | `<repo>/.adlc/reports/` |
| Everything the kit knows about a repo | `core/scripts/kit-info.sh [change-id]` |
