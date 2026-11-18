# Codex CLI harness

**What you get**
- Codex reads the repo's `AGENTS.md`. The kit block there holds the rules and maps each command to its playbook. Say `adlc sessions`, `adlc ship`, or type the command name.
- The kit path comes from `.adlc/kit-path`.
- The git pre-push hook blocks pushes to protected branches, tag pushes, force pushes and branch deletes.

**What you do not get (yet)**
- No check of shell commands or file edits before they run. Rules about merges, statuses and the kit's files are instructions Codex follows, not blocks.
- No named subagents. For a role (`verifier`, `release-gate`, `intent-critic`), start a separate run with the role brief, for example:
  `codex exec --sandbox read-only "$(cat "$(cat .adlc/kit-path)/core/roles/verifier.md") Repo: $PWD. Change: <id>."`
  The `release-gate` role needs to run `release-decision.sh`, so it cannot be read-only.
- Because the role cannot be checked here, treat `adlc/final-check` as advisory with this harness and keep the server-side gate on (`docs/server-gate.md`). `merge: human` is the safe default for risky changes.

Codex as the **judge** for another builder is a separate thing and fully supported: `JUDGE_ADAPTER="codex"`.
