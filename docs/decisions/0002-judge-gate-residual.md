# 0002: The judge gate has a known residual

Status: accepted

## Context

`adlc/judge` and `adlc/final-check` are commit statuses posted by the agent's identity. `agent-merge.sh` refuses to merge without them. But an agent that can reach the credentials of that identity could post them itself, and the code host cannot tell the difference. The guard blocks the obvious routes (running the identity adapter, reading the stored token, posting statuses through the host CLI). It cannot see code that is written to a file and run later.

## Decision

Accept the residual, and say so.

- The hard gate is the server-side one: a pull request plus a required check from CI, an identity the agent does not control.
- The judge and final-check statuses are enforced by the kit's scripts and guard, not by the host.
- Intents that set policy need a human approving review. Risky changes use `merge: human`.

## Why

Closing it means running the judge where the agent has no access: inside CI. That costs CI minutes on every round and puts a model API key in CI secrets. For most teams the CI gate plus human approval of policy is the better trade. Teams that need more can move the judge into CI without changing the rest: same prompt, same schema, and then require that check on the host.

## Consequences

- `docs/security-model.md` states the residual on the first screen that mentions `merge: auto`.
- The kit never tells users to make `adlc/*` statuses required checks on the host, because that would look stronger than it is.
- A contribution that runs the judge as a CI job, as an optional mode, is welcome.
