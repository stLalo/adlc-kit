#!/usr/bin/env bash
# judge.sh <pr-number>
# Runs the judge (an independent reviewer, read-only) on the PR's exact head commit, posts a PR comment
# with findings and the commit status `adlc/judge`. Exit 0 = approve, 2 = request-changes,
# 3 = max rounds reached (needs the owner).
#
# Which judge runs is JUDGE_ADAPTER in .adlc/config.env: an executable in adapters/judge/ (see
# adapters/judge/CONTRACT.md), or `human`, where an approving review from a repo admin is the verdict.
source "$(dirname "$0")/lib.sh"
load_config

pr="${1:?usage: judge.sh <pr-number>}"
sha=$(pr_sha "$pr")
change=$(pr_change "$pr")
intent=$(intent_path "$change")
require_clean_head "$sha"

if [ "$JUDGE_ADAPTER" = human ]; then
  ok=""
  for u in $(host_pr_approvers_at "$pr" "$sha"); do host_user_is_admin "$u" && ok=$u && break; done
  if [ -z "$ok" ]; then
    post_status "$sha" adlc/judge pending "waiting for an approving review from a repo admin"
    notify "PR $pr is waiting for a human review (JUDGE_ADAPTER=human)"
    exit 2
  fi
  post_status "$sha" adlc/judge success "human review: approved by $ok"
  exit 0
fi

judge="$KIT/adapters/judge/$JUDGE_ADAPTER.sh"
[ -x "$judge" ] || die "no judge adapter '$JUDGE_ADAPTER' in $KIT/adapters/judge/"

marker="<!-- adlc-judge"
rounds=$(host_pr_comments "$pr" | grep -c "^$marker" || true)
if [ "$rounds" -ge "$MAX_JUDGE_ROUNDS" ]; then
  post_status "$sha" adlc/judge failure "max $MAX_JUDGE_ROUNDS judge rounds reached; needs the owner"
  host_pr_label_add "$pr" needs-human >/dev/null 2>&1 || true
  notify "PR $pr hit max judge rounds"
  exit 3
fi
round=$((rounds + 1))

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
host_pr_diff "$pr" > "$work/diff.patch"
post_status "$sha" adlc/judge pending "round $round running"

cat > "$work/prompt.md" <<EOF
You are an independent senior code reviewer acting as a judge. You did not write this code.
Review pull request $pr at commit $sha. Be strict and specific; do not praise.
Do not change any file.

Read, in this order:
1. Intent: $intent
2. Spec and plan: the folder for change "$change" under $SPEC_CHANGES_DIR/ (it may already be archived
   in a dated folder there)${SPEC_SPECS_DIR:+, and the current specs in $SPEC_SPECS_DIR/}
3. The diff: $work/diff.patch  (then open any touched file you need for context)

Judge:
- Each acceptance criterion in the spec: met or not, with evidence (file:line or test name).
- Correctness bugs, missing edge cases, error handling.
- Security: injection, authz/authn, secrets, unsafe deserialization, dependency risk.
- Tests: do they prove the criteria, or only exercise code? Were tests weakened?
- Spec drift: changes the spec did not ask for.

Verdict "approve" only if every criterion is met and there is no critical or high finding.
Otherwise "request-changes", with a concrete fix for each finding.

Answer with one JSON object that matches the schema you were given: verdict, summary, criteria, findings.
EOF

# The judge gets no agent token. Its verdict is checked here, whatever the adapter enforces.
run_judge() {
  local v unset_args=(-u ADLC_HOST_TOKEN)
  for v in ${HOST_TOKEN_VARS:-}; do unset_args+=(-u "$v"); done
  rm -f "$work/verdict.json"
  env "${unset_args[@]}" "$judge" "$work/prompt.md" "$SCRIPT_DIR/judge-schema.json" "$work/verdict.json" "$1" \
    > "$work/judge.log" 2>&1 || return 1
  python3 - "$work/verdict.json" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))
assert v["verdict"] in ("approve", "request-changes"), "verdict"
assert isinstance(v["summary"], str), "summary"
for c in v["criteria"]:
    assert isinstance(c["criterion"], str) and isinstance(c["met"], bool) and isinstance(c["evidence"], str)
for f in v["findings"]:
    assert f["severity"] in ("critical", "high", "medium", "low")
    for k in ("category", "file", "detail", "fix"):
        assert isinstance(f[k], str), k
PY
}
judge_failed() {
  agent_identity fresh
  post_status "$sha" adlc/judge failure "judge '$JUDGE_ADAPTER' failed to produce a verdict"
  tail -20 "$work/judge.log" >&2 || true
  die "judge failed: see output"
}
model="$JUDGE_MODEL"
if ! run_judge "$model"; then
  [ -n "$JUDGE_FALLBACK_MODEL" ] || judge_failed
  model="$JUDGE_FALLBACK_MODEL"; info "primary judge failed; trying $model"
  run_judge "$model" || judge_failed
fi

agent_identity fresh       # the judge may outlast a short-lived token
python3 - "$work/verdict.json" "$work/comment.md" "$sha" "$round" "$JUDGE_ADAPTER${model:+ $model}" <<'PY'
import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))
sha, rnd, who = sys.argv[3], sys.argv[4], sys.argv[5]
cell = lambda s: str(s).replace("|", "\\|").replace("\n", " ")
out = [f"<!-- adlc-judge sha={sha} round={rnd} -->",
       f"### Judge · round {rnd} · `{sha[:7]}` · {who}",
       f"**Verdict: {v['verdict']}** — {v['summary']}", "",
       "| Criterion | Met | Evidence |", "|---|---|---|"]
for c in v["criteria"]:
    out.append(f"| {cell(c['criterion'])} | {'✅' if c['met'] else '❌'} | {cell(c['evidence'])} |")
if v["findings"]:
    out += ["", "| Severity | Category | File | Finding | Fix |", "|---|---|---|---|---|"]
    for f in v["findings"]:
        out.append(f"| {f['severity']} | {cell(f['category'])} | `{cell(f['file'])}` | {cell(f['detail'])} | {cell(f['fix'])} |")
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out) + "\n")
PY
verdict=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["verdict"])' "$work/verdict.json")
host_pr_comment "$pr" "$work/comment.md" >/dev/null

if [ "$verdict" = "approve" ]; then
  post_status "$sha" adlc/judge success "approved round $round ($JUDGE_ADAPTER${model:+ $model})"
  exit 0
fi
post_status "$sha" adlc/judge failure "changes requested round $round ($JUDGE_ADAPTER${model:+ $model})"
cat "$work/comment.md"
exit 2
