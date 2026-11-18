## What and why

<!-- One concern. Link the issue. -->

## Kind

- [ ] Adapter (which: )
- [ ] Core fix
- [ ] Guard or gate change
- [ ] Docs
- [ ] Other

## Proof

<!-- Commands you ran and their result lines. "Should work" is not evidence. -->

```
bash tests/run.sh          →
bash tests/public-scan.sh  →
```

<!-- Adapters: the last line of the conformance run or one real verdict line. -->

## Checklist

- [ ] Tests added for what changed (guard changes: blocked and allowed cases in `tests/guard_cases.tsv`)
- [ ] Docs updated: `docs/compatibility.md`, contract, `CHANGELOG.md`
- [ ] `core/` names no vendor
- [ ] Loosens a gate? Decision record in `docs/decisions/` (otherwise: no)
- [ ] Commits signed off (`git commit -s`)
- [ ] Nothing private: no company names, internal hosts, real repo names, tokens, machine paths
