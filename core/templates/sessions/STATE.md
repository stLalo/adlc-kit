# State

Append-only checkpoint log. The LAST entry is the current state.
Never edit, reorder or delete earlier entries. Add entries only with `/checkpoint` or `/session-close`.

## Checkpoints
