# Identity adapter contract

An identity adapter decides **who the agent is** on the code host. With an agent identity, pushes, comments and statuses come from a bot account, so the history shows what a person did and what an agent did, and branch protection can treat them differently.

It is one executable, `adapters/identity/<name>.sh`, chosen by `IDENTITY_ADAPTER` in the kit's machine-local `.adlc/kit.env`.

| Exit | Meaning | What core does |
|---|---|---|
| 0, token on stdout | Here is a credential for the agent identity. | Uses it for every host call and push. |
| 1 | Not configured. | Acts as the user's own login. |
| anything else | Configured but failed. | Stops. It never falls back to the user's login silently. |

Rules:
- No arguments. Read settings from `$ADLC_KIT/.adlc/kit.env`, secrets through a secrets adapter.
- Print the token and nothing else on stdout. Never log it.
- Prefer short-lived tokens. Core asks again (`agent_identity fresh`) after long steps.
- The guard blocks agents from running or copying identity adapters directly.

Shipped: `own-login` (no agent identity) and `github-app` (GitHub App installation token).
For another host, mint whatever that host offers a bot: a project or group access token, an app password, a service account.
