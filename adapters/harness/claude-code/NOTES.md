---
**Claude Code notes** (how the neutral words above map to this harness)
- "The kit" is the folder in the environment variable `ADLC_KIT` (set in `.claude/settings.local.json`). If it is empty, stop and tell the owner to run the kit's `install-repo.sh` on this repo.
- "Ask the owner" → use AskUserQuestion when the answer is a choice. "Notify the owner" → use a push notification tool if you have one, otherwise put it first in your reply.
- "Run the `<name>` role" → run the subagent with that name. Give it the repo folder and the ids it needs.
- "Planner / builder model" → the owner switches with `/model`. "Name this conversation" → `/rename <session-id>`.
- A PreToolUse hook (the guard) blocks direct merges, tags, pushes to protected branches, status posts and edits to the kit or to closed sessions. A block is a rule, not an error to work around: read the reason and use the kit script it names.
