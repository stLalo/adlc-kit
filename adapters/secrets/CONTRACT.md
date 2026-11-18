# Secrets adapter contract

A secrets adapter hands secrets to an identity adapter without them touching the command line, the chat, or a file in the repo.

It is one executable, `adapters/secrets/<name>.sh`, chosen by `SECRETS_ADAPTER` in `.adlc/kit.env`:

```
<name>.sh NAME=<ref> [NAME=<ref>...] -- <command...>
```

- Resolve each `<ref>` to its secret value and run `<command>` with `NAME` set in its environment.
- A `<ref>` is a pointer (a variable name, a file path, a vault path), never the secret itself. Refs live in `kit.env`.
- Exit 3 if any secret is missing or empty. Never print a value.

Shipped:
- `env`: the ref is the name of an environment variable that already holds the secret, or `file:<path>`.
- `command`: runs `SECRET_CMD <ref>` and uses its output. Works with most secret managers' CLIs (`op read`, `vault kv get -field=...`, `pass show`, a cloud provider's secrets CLI).

Set `SECRET_BLOCK_PATTERNS` in `kit.env` to a regex of command lines that would read the agent's credentials directly. The guard blocks them.
