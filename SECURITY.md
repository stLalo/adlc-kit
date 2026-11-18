# Security policy

## What counts

- A way for an agent to merge, tag, deploy, or post an `adlc/*` status without the gates in `docs/security-model.md`, beyond the residual that document already describes.
- A guard rule that can be bypassed with a simple variation of a blocked command.
- A script that leaks a token (to argv, logs, a file in the repo, or the environment of repo-controlled commands).
- A way for a pull request to change the policy or config it is judged by.

Not a vulnerability: the documented residual (an agent that can read the agent identity's credentials can use them), and limits of a harness that the docs already state.

## How to report

Use GitHub's **private vulnerability reporting** on this repository (Security tab → Report a vulnerability). Please do not open a public issue or pull request for a bypass.

Include: the setup (host, harness, judge), the exact steps, and what you expected the kit to stop.

## What to expect

- An answer within 7 days.
- A fix or a documented decision, with a test that reproduces the report.
- Credit in the changelog, unless you prefer not.

## Supported versions

The latest release and `main`.
