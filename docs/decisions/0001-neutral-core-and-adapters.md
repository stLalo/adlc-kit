# 0001: Neutral core, adapters for every tool

Status: accepted

## Context

The kit started inside one team's workspace, written directly against GitHub (`gh`), Claude Code (hooks, slash commands, subagents), Codex (the judge) and OpenSpec. It worked, and it could not be shared: people use other hosts, other agents, one agent instead of two, and other spec habits. Maintainers can only test a few of those combinations.

## Decision

Split the kit in two.

- `core/` holds the process: gated scripts, the guard's policy, playbooks, role briefs, templates. It names no vendor. CI fails if it does.
- `adapters/` holds one small piece per tool, behind a written contract: host, harness, judge, spec, identity, secrets.

Ship only adapters maintainers run (GitHub, Claude Code, Codex, OpenSpec, plain markdown). For everything else ship the contract, a template and a test, and an install guide that has the user's own agent write the adapter with them.

## Why

- A contract plus a conformance suite lets someone add GitLab without understanding the merge gate, and lets maintainers accept it without owning a GitLab instance.
- Untested adapters shipped as if they worked would cost users more than an honest "write it, here is the test".
- Playbooks as plain markdown work in any agent that can read a file. Harness adapters add convenience and enforcement where the agent allows it.

## Rejected

- **Publish as-is and document what to change.** Every non-GitHub user would fork and rewrite the scripts; improvements would not flow back.
- **Ship best-effort adapters for every host.** Code nobody has run, in the path that merges to main.
- **One abstraction library or a rewrite in another language.** Bash, git and Python are already on every developer machine; the adapters stay readable in one sitting.

## Consequences

- Hosts differ (pinned merges, commit statuses, review semantics). The contract states the required behaviour, and adapters must say where their host falls short.
- Enforcement differs by agent. The kit names three levels and never claims more than a harness can do.
- Renamed from the private version: statuses are `adlc/*`, config lives in `.adlc/`, the pull request trailer is `adlc-change:`.
