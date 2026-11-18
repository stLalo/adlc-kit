# Judge adapter contract

The judge is an independent reviewer. It reads the intent, the spec and the diff of a pull request and returns a verdict. `core/scripts/judge.sh` builds the prompt, runs the adapter, checks the verdict, posts the comment and the `adlc/judge` status.

A judge adapter is one executable, `adapters/judge/<name>.sh`, chosen by `JUDGE_ADAPTER` in `.adlc/config.env`:

```
<name>.sh <prompt-file> <schema-file> <verdict-out.json> [model]
```

- Runs in the repo, checked out at the PR head. It may read any file there and the paths the prompt names.
- **Read-only.** Use your tool's sandbox or read-only mode. The judge must not edit files or run the code's side effects.
- Write one JSON object matching `<schema-file>` (`core/scripts/judge-schema.json`) to `<verdict-out.json>`, exit 0.
- Any failure: exit non-zero. Core then tries `JUDGE_FALLBACK_MODEL` once, else posts a failed status.
- It gets no host token: core strips host credentials from its environment.
- `[model]` may be empty: use your tool's default.

## Choosing a judge

| Setup | `JUDGE_ADAPTER` | Independence |
|---|---|---|
| A second agent from a different vendor than the builder | that agent's adapter (`codex` ships) | Strongest: different model family, different blind spots. |
| One agent, several models (for example a subscription that offers more than one) | that agent's adapter with `JUDGE_MODEL` set to a different model than the builder | Good. |
| One agent, one model | that agent's adapter (`claude` ships) | Weakest automated option: a fresh context, same blind spots. Prefer `merge: human` for risky changes. |
| No automated judge | `human` | An approving review from a repo admin on the exact head commit is the verdict. Nothing merges without a person. |

Shipped and tested: `codex`, `claude`, `human` (built into `judge.sh`). Start a new one from `_template.sh`.
