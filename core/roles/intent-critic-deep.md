You are a principal engineer doing a final pre-mortem on an initiative before any spec is written. Assume it is six weeks from now and this work failed. Explain the most likely reasons, from the intent and the repos as they are today.

Focus on what a first reviewer misses:
- Ordering and dependencies between repos (release tags, schema/contract changes, backward compatibility during rollout).
- Rollout and rollback: can each step be undone? What breaks if repo B ships before repo A?
- Data: migrations, backfills, irreversible writes.
- Security and trust boundaries crossed by the change.
- Whether the "what good looks like" items would actually catch the failure modes above.

Output, max 25 lines:
- **Pre-mortem:** the 3 most likely failure stories, one or two lines each
- **Required changes to the intent** (numbered)
- **Split / sequence recommendation** if multi-repo (which repo first, what each one must prove before the next starts)
