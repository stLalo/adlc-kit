#!/usr/bin/env bash
# Kit regression tests. Offline, about 30 s: a fake host CLI and local bare remotes stand in for the code
# host. Run: bash tests/run.sh    Exit 0 = all pass.
#   1. guard matrix (shell commands, file edits, pre-push), through the neutral interface and the
#      Claude Code hook
#   2. judge.sh and agent-merge.sh end to end, docs merges, session-save.sh
#   3. install-repo.sh with the Claude Code and git-hook harnesses
#   4. the GitHub App identity adapter (JWT checked with a throwaway key)
#   5. host conformance for the GitHub adapter
set -uo pipefail
T="$(cd "$(dirname "$0")" && pwd)"; SRC="$(cd "$T/.." && pwd)"
fail=0 n=0
ok()  { n=$((n+1)); echo "ok   $*"; }
bad() { n=$((n+1)); fail=$((fail+1)); echo "FAIL $*"; }

# pwd -P: on macOS the temp folder sits behind a symlink, and git reports the resolved path.
W=$(cd "$(mktemp -d)" && pwd -P) || exit 1; trap 'rm -rf "$W"' EXIT
# Never touch real repos or the user's git config: isolated HOME/config, fail fast on setup errors.
export HOME="$W" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset ADLC_KIT ADLC_HOST_TOKEN ADLC_KIT_PUSH GITHUB_TOKEN
# The kit under test is a copy, with its own machine-local settings.
mkdir "$W/kit" && (cd "$SRC" && tar --exclude=./.git --exclude=./.adlc -cf - .) | tar -xf - -C "$W/kit" || exit 1
K="$W/kit"; S="$K/core/scripts"; G="$K/core/guard/guard.py"; CH="$K/adapters/harness/claude-code/pretooluse.py"
mkdir -p "$K/.adlc"
printf 'ADLC_PROTECTED_BRANCHES="main master develop"\nSECRET_BLOCK_PATTERNS="secret-tool .*adlc-bot"\n' > "$K/.adlc/kit.env"
gitc() { git -c user.name=t -c user.email=t@example.invalid "$@"; }

# ---------------------------------------------------------------- 1. guard
R="$W/onmain"
git init -q "$R" && git -C "$R" symbolic-ref HEAD refs/heads/main || exit 1
mkdir -p "$R/.adlc" "$R/docs/sessions/s1" "$R/docs/sessions/s2" "$R/src"
printf 'MAIN_BRANCH="main"\nDEPLOY_BLOCK_PATTERNS="kubectl (apply|rollout)"\n' > "$R/.adlc/config.env"
printf -- '---\nstatus: active\n---\n' > "$R/docs/sessions/s1/SESSION.md"; printf '# State\nA\n' > "$R/docs/sessions/s1/STATE.md"
printf -- '---\nstatus: complete\n---\n' > "$R/docs/sessions/s2/SESSION.md"

neutral() { python3 -c 'import json,sys
d={"kind":"bash","command":sys.argv[1],"cwd":sys.argv[3]}
if sys.argv[2]: d["role"]=sys.argv[2]
print(json.dumps(d))' "$1" "$2" "$R" | python3 "$G" 2>/dev/null; echo $?; }
claude() { python3 -c 'import json,sys
d={"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[3]}
if sys.argv[2]: d["agent_type"]=sys.argv[2]
print(json.dumps(d))' "$1" "$2" "$R" | python3 "$CH" 2>/dev/null; echo $?; }
while IFS=$'\t' read -r exp cmd role; do
  [[ -z "$exp" || "$exp" == \#* ]] && continue
  a=$(neutral "$cmd" "${role:-}"); b=$(claude "$cmd" "${role:-}")
  [ "$a" = "$exp" ] && [ "$b" = "$exp" ] && ok "guard $exp: $cmd" || bad "guard expected $exp got $a (neutral) $b (claude hook): $cmd"
done < "$T/guard_cases.tsv"
for cmd in "git push" "git push origin HEAD"; do
  [ "$(neutral "$cmd" "")" = 2 ] && ok "guard 2 on main: $cmd" || bad "guard on main: $cmd"
done

edit() {   # edit <expected> <label> <json>
  local got; got=$(printf '%s' "$3" | python3 "$G" 2>/dev/null; echo $?)
  [ "$got" = "$1" ] && ok "guard edit $1: $2" || bad "guard edit expected $1 got $got: $2"
}
j() { python3 -c 'import json,sys; d=json.loads(sys.argv[2]); d.update(kind="edit", path=sys.argv[1], cwd=sys.argv[3]); print(json.dumps(d))' "$1" "$2" "$R"; }
edit 2 "a kit script"                 "$(j "$K/core/scripts/lib.sh" '{"content":"x"}')"
edit 2 "the kit's kit.env"            "$(j "$K/.adlc/kit.env" '{"content":"x"}')"
edit 2 ".adlc/config.env"             "$(j ".adlc/config.env" '{"content":"x"}')"
edit 2 "harness settings"             "$(j ".claude/settings.local.json" '{"content":"{}"}')"
edit 2 "the release-gate subagent"    "$(j ".claude/agents/release-gate.md" '{"content":"x"}')"
edit 0 "ordinary source file"         "$(j "src/app.py" '{"content":"x"}')"
edit 2 "file in a closed session"     "$(j "docs/sessions/s2/NOTES.md" '{"content":"x"}')"
edit 0 "STATE.md whole-file append"   "$(j "docs/sessions/s1/STATE.md" '{"content":"# State\nA\nB\n"}')"
edit 2 "STATE.md rewrite"             "$(j "docs/sessions/s1/STATE.md" '{"content":"B\n"}')"
edit 0 "STATE.md append at the end"   "$(j "docs/sessions/s1/STATE.md" '{"edits":[{"old":"A","new":"A\nB"}]}')"
edit 2 "STATE.md edit in the middle"  "$(j "docs/sessions/s1/STATE.md" '{"edits":[{"old":"# State","new":"# State\nX"}]}')"
edit 2 "STATE.md deletion"            "$(j "docs/sessions/s1/STATE.md" '{"edits":[{"old":"A","new":""}]}')"
hook() {   # hook <expected> <label> <claude hook json>
  local got; got=$(printf '%s' "$3" | python3 "$CH" 2>/dev/null; echo $?)
  [ "$got" = "$1" ] && ok "claude hook $1: $2" || bad "claude hook expected $1 got $got: $2"
}
hook 2 "Write to .adlc/config.env" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$R/.adlc/config.env\",\"content\":\"x\"},\"cwd\":\"$R\"}"
hook 2 "Edit that rewrites STATE.md" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$R/docs/sessions/s1/STATE.md\",\"old_string\":\"A\",\"new_string\":\"Z\"},\"cwd\":\"$R\"}"
hook 0 "Edit that appends to STATE.md" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$R/docs/sessions/s1/STATE.md\",\"old_string\":\"A\",\"new_string\":\"A\\nB\"},\"cwd\":\"$R\"}"
hook 0 "Read is not checked" "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$K/core/scripts/lib.sh\"},\"cwd\":\"$R\"}"

z=0000000000000000000000000000000000000000; x=1111111111111111111111111111111111111111
pp() { local got; got=$(printf '%s\n' "$3" | env ${4:+ADLC_KIT_PUSH=1} python3 "$G" pre-push "$R" 2>/dev/null; echo $?)
       [ "$got" = "$1" ] && ok "pre-push $1: $2" || bad "pre-push expected $1 got $got: $2"; }
pp 2 "push to main"                 "refs/heads/feat/x $x refs/heads/main $z"
pp 0 "new feature branch"           "refs/heads/feat/x $x refs/heads/feat/x $z"
pp 2 "tag push by hand"             "refs/tags/v1 $x refs/tags/v1 $z"
pp 0 "tag push by a kit script"     "refs/tags/v1 $x refs/tags/v1 $z" kit
pp 2 "branch delete"                "(delete) $z refs/heads/feat/x $x"

# ---------------------------------------------------------------- 2. judge, merge, docs merge, session-save
mkdir -p "$W/bin"; cp "$T/fake-gh" "$W/bin/gh"; chmod +x "$W/bin/gh"
export PATH="$W/bin:$PATH" FAKE_GH_STATE="$W/state.json" FAKE_REMOTE="$W/remote.git" GH_TOKEN=must-not-reach-tests
printf '#!/usr/bin/env bash\n[ -z "${GH_TOKEN:-}" ] || { echo "judge saw a host token" >&2; exit 9; }\ngrep -q "adlc-intent-" "$1" || exit 8\ncp "$FAKE_VERDICT" "$3"\n' > "$K/adapters/judge/fake.sh"
chmod +x "$K/adapters/judge/fake.sh"
git init -q --bare "$W/remote.git" && git -C "$W/remote.git" symbolic-ref HEAD refs/heads/main || exit 1
git clone -q "$W/remote.git" "$W/repo" 2>/dev/null || exit 1
cd "$W/repo" || exit 1
[ "$(git rev-parse --show-toplevel)" = "$W/repo" ] && [ "$(git remote get-url origin)" = "$W/remote.git" ] \
  || { echo "refusing: not inside the temp test repo" >&2; exit 1; }
git config user.name t; git config user.email t@example.invalid
mkdir -p .adlc openspec/changes/c1
printf 'MAIN_BRANCH="main"\nHOST_ADAPTER="github"\nSPEC_ADAPTER="openspec"\nJUDGE_ADAPTER="fake"\nMERGE_METHOD="merge"\nTEST_CMD='"'"'test -z "${GH_TOKEN:-}" && test -f feature.txt'"'"'\n' > .adlc/config.env
printf -- '---\nmerge: auto\ntag: rc\nrelease: 0.1.0\n---\n' > openspec/changes/c1/intent.md
git add -A; git commit -qm init; git push -q origin HEAD:main
git switch -qc feat/c1; echo f > feature.txt; git add -A; git commit -qm feat; git push -q origin feat/c1; H=$(git rev-parse HEAD)
# state <head> <branch> <judge status or -> <change> [extra json merged into PR 7]
state() { python3 -c 'import json,sys
head, branch, judge, change, extra = sys.argv[1:6]
pr = {"state":"OPEN","head":head,"branch":branch,"base":"main","body":"adlc-change: "+change,"comments":[],"labels":[],"reviews":[]}
pr.update(json.loads(extra or "{}"))
st = {head: {"adlc/final-check": ["success",""]}}
if judge != "-": st[head]["adlc/judge"] = [judge, ""]
json.dump({"prs":{"7":pr},"statuses":st,"admins":["alice"]}, open(sys.argv[6],"w"))' "$1" "$2" "$3" "$4" "${5:-}" "$FAKE_GH_STATE"; }
get() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = d.get(k, "") if isinstance(d, dict) else ""
print(d if isinstance(d, str) else json.dumps(d))' "$FAKE_GH_STATE" "$1"; }
expect() { local what=$1 want=$2 msg=$3 out; shift 3; out=$("$@" 2>&1); grep -q -- "$want" <<<"$out" && ok "$what: $msg" || bad "$what: $msg — got: $(tail -1 <<<"$out")"; }
code() { local what=$1 want=$2 msg=$3 rc; shift 3; "$@" >/dev/null 2>&1; rc=$?; [ "$rc" = "$want" ] && ok "$what: $msg" || bad "$what: $msg — exit $rc, wanted $want"; }

export FAKE_VERDICT="$W/verdict.json"
echo '{"verdict":"approve","summary":"fine","criteria":[{"criterion":"c | 1","met":true,"evidence":"t.py:1"}],"findings":[]}' > "$FAKE_VERDICT"
state "$H" feat/c1 - c1; code judge 0 "approve exits 0" "$S/judge.sh" 7
[ "$(get "statuses.$H.adlc/judge" | cut -c1-12)" = '["success", ' ] && ok "judge: posts adlc/judge success" || bad "judge: status is $(get "statuses.$H.adlc/judge")"
get prs.7.comments | grep -q "adlc-judge sha=$H round=1" && ok "judge: comments with the sha and round" || bad "judge: comment missing"
echo '{"verdict":"request-changes","summary":"no","criteria":[],"findings":[{"severity":"high","category":"tests","file":"a.py","detail":"d","fix":"f"}]}' > "$FAKE_VERDICT"
state "$H" feat/c1 - c1; code judge 2 "request-changes exits 2" "$S/judge.sh" 7
[ "$(get "statuses.$H.adlc/judge" | cut -c1-12)" = '["failure", ' ] && ok "judge: posts adlc/judge failure" || bad "judge: status is $(get "statuses.$H.adlc/judge")"
state "$H" feat/c1 - c1 '{"comments":["<!-- adlc-judge r1 -->\nx","<!-- adlc-judge r2 -->","<!-- adlc-judge r3 -->"]}'
code judge 3 "max rounds exits 3" "$S/judge.sh" 7
get prs.7.labels | grep -q needs-human && ok "judge: max rounds adds needs-human" || bad "judge: needs-human label missing"
echo '{"verdict":"maybe"}' > "$FAKE_VERDICT"
state "$H" feat/c1 - c1; expect judge "judge failed" "a malformed verdict fails the judge" "$S/judge.sh" 7
[ "$(get "statuses.$H.adlc/judge" | cut -c1-12)" = '["failure", ' ] && ok "judge: malformed verdict posts failure" || bad "judge: status is $(get "statuses.$H.adlc/judge")"

state "$H" feat/c1 failure c1;    expect merge "adlc/judge is 'failure'" "judge failure refused" "$S/agent-merge.sh" 7
state "$H" feat/other success c1; expect merge "is not feat/c1" "branch/change mismatch refused" "$S/agent-merge.sh" 7
state "$H" feat/c1 success c1; echo x > stray.py; expect merge "working tree not clean" "dirty tree refused" "$S/agent-merge.sh" 7; rm stray.py
state "$H" feat/c1 success c1 '{"cross":"true"}'; expect merge "comes from a fork" "fork PR refused" "$S/agent-merge.sh" 7
# Repo-controlled commands must not rewire git (where the token-bearing push goes, which hooks run).
expect untrusted "changed this repo's git config or hooks" "a command that edits git config stops the kit" bash -c "source '$S/lib.sh'; run_untrusted 'git config adlc.test 1'"
git config --unset adlc.test
expect untrusted "changed this repo's git config or hooks" "a command that plants a hook stops the kit" bash -c "source '$S/lib.sh'; run_untrusted 'echo x > .git/hooks/post-checkout'"
rm -f .git/hooks/post-checkout
code untrusted 3 "exit code of the command is kept" bash -c "source '$S/lib.sh'; run_untrusted 'exit 3'"
state "$H" feat/c1 success c1 '{"mergeable":"CONFLICTING"}'; expect merge "is not mergeable" "conflicting PR refused" "$S/agent-merge.sh" 7
# The host answers UNKNOWN twice (still computing) before MERGEABLE: the adapter waits instead of refusing.
state "$H" feat/c1 success c1 '{"mergeable":["UNKNOWN","UNKNOWN","MERGEABLE"]}'
ADLC_HOST_WAIT=0 expect merge "tagged v0.1.0-rc.1" "happy path merges and tags (waits out UNKNOWN)" "$S/agent-merge.sh" 7
[ "$(git -C "$W/remote.git" tag)" = "v0.1.0-rc.1" ] && ok "merge: tag on remote" || bad "merge: tag on remote"
git -C "$W/remote.git" log -1 --format=%s main | grep -q "Merge PR #7" && ok "merge: merge commit on main" || bad "merge: merge commit"
git -C "$W/remote.git" rev-parse -q --verify refs/heads/feat/c1 >/dev/null && bad "merge: feature branch still on remote" || ok "merge: feature branch deleted"
expect merge "already tagged v0.1.0-rc.1" "rerun reuses merge and tag" "$S/agent-merge.sh" 7
[ "$(git -C "$W/remote.git" tag | wc -l | tr -d ' ')" = 1 ] && ok "merge: rerun made no second tag" || bad "merge: second tag"
# policy comes from main, not the PR
D="$W/main-clone"; git clone -q -b main "$W/remote.git" "$D" || exit 1; mkdir -p "$D/openspec/changes/c2"
printf -- '---\nmerge: human\n---\n' > "$D/openspec/changes/c2/intent.md"
git -C "$D" add -A; gitc -C "$D" commit -qm c2; git -C "$D" push -q origin HEAD:main
git fetch -q origin main; git switch -qc feat/c2 FETCH_HEAD
printf -- '---\nmerge: auto\n---\n' > openspec/changes/c2/intent.md; echo f > feature.txt; git add -A; git commit -qm self-grant
git push -q origin feat/c2
state "$(git rev-parse HEAD)" feat/c2 success c2; expect merge "intent says merge: human" "PR cannot self-grant merge: auto" "$S/agent-merge.sh" 7
echo 'MAIN_BRANCH="feat/c2"' > .adlc/config.env
expect merge "not in ADLC_PROTECTED_BRANCHES" "a branch cannot name itself the main branch" "$S/agent-merge.sh" 7
git checkout -q .adlc/config.env; echo '# x' >> .adlc/config.env
expect merge "config.env is changed on this branch" "a branch cannot change the config" "$S/agent-merge.sh" 7
git checkout -q .adlc/config.env
git rm -q feature.txt; git commit -qm break; git push -q origin feat/c2
printf -- '---\nmerge: auto\n---\n' > "$D/openspec/changes/c2/intent.md"; gitc -C "$D" commit -qam auto; git -C "$D" push -q origin HEAD:main
state "$(git rev-parse HEAD)" feat/c2 success c2; expect merge "tests failed" "failing tests refused" "$S/agent-merge.sh" 7

# docs merges
git fetch -q origin main; git switch -qc define/c4 FETCH_HEAD
mkdir -p openspec/changes/c4 docs; printf -- '---\nmerge: auto\n---\n' > openspec/changes/c4/intent.md; echo d > docs/x.md
git add -A; git commit -qm "docs(intent): c4"; git push -q origin define/c4; H4=$(git rev-parse HEAD)
state "$H4" define/c4 - c4; expect docs "needs an approving review from a repo admin" "new intent needs the owner's review" "$S/agent-merge.sh" 7 --docs
state "$H4" define/c4 - c4 "{\"reviews\":[[\"bob\",\"APPROVED\",\"$H4\"]]}"; expect docs "needs an approving review" "a non-admin approval is not enough" "$S/agent-merge.sh" 7 --docs
state "$H4" define/c4 - c4 "{\"reviews\":[[\"alice\",\"APPROVED\",\"$H\"]]}"; expect docs "needs an approving review" "an approval of an older commit is not enough" "$S/agent-merge.sh" 7 --docs
state "$H4" define/c4 - c4 "{\"reviews\":[[\"alice\",\"APPROVED\",\"$H4\"]]}"; expect docs "docs PR 7 merged" "admin-approved intent merges" "$S/agent-merge.sh" 7 --docs
git fetch -q origin main; git switch -qc chore/arch FETCH_HEAD
mkdir -p openspec/changes/archive; git mv openspec/changes/c4 openspec/changes/archive/2026-01-02-c4; git commit -qm archive; git push -q origin chore/arch
state "$(git rev-parse HEAD)" chore/arch - c4; expect docs "docs PR 7 merged" "archiving a change needs no new approval" "$S/agent-merge.sh" 7 --docs
git fetch -q origin main; git switch -qc chore/sneak FETCH_HEAD
echo d2 > docs/y.md; echo code > app.py; git add -A; git commit -qm sneak; git push -q origin chore/sneak
state "$(git rev-parse HEAD)" chore/sneak - c4; expect docs "docs merge refused" "docs merge with a code file refused" "$S/agent-merge.sh" 7 --docs

# human judge + plain spec adapter (config change lands on main first)
git -C "$D" pull -q origin main
sed -i.bak -e 's/JUDGE_ADAPTER="fake"/JUDGE_ADAPTER="human"/' -e 's/SPEC_ADAPTER="openspec"/SPEC_ADAPTER="plain"/' "$D/.adlc/config.env"; rm -f "$D/.adlc/config.env.bak"
mkdir -p "$D/docs/changes/c5"; printf -- '---\nmerge: auto\ntag: none\n---\n' > "$D/docs/changes/c5/intent.md"
git -C "$D" add -A; gitc -C "$D" commit -qm "human judge, plain specs"; git -C "$D" push -q origin HEAD:main
git fetch -q origin main; git switch -qc feat/c5 FETCH_HEAD; echo f5 > f5.txt; git add -A; git commit -qm c5; git push -q origin feat/c5; H5=$(git rev-parse HEAD)
state "$H5" feat/c5 - c5; code "human judge" 2 "no review yet exits 2" "$S/judge.sh" 7
[ "$(get "statuses.$H5.adlc/judge" | cut -c1-12)" = '["pending", ' ] && ok "human judge: status pending" || bad "human judge: status is $(get "statuses.$H5.adlc/judge")"
state "$H5" feat/c5 - c5 "{\"reviews\":[[\"alice\",\"APPROVED\",\"$H5\"]]}"; code "human judge" 0 "admin approval exits 0" "$S/judge.sh" 7
state "$H5" feat/c5 success c5; expect "plain specs" "merged PR 7" "merge reads intent from docs/changes" "$S/agent-merge.sh" 7

# session-save
git fetch -q origin main; git switch -qc feat/c6 FETCH_HEAD; mkdir -p docs/sessions/s9; echo "# State" > docs/sessions/s9/STATE.md
expect session-save "saved docs/sessions/s9" "saves logs to a side branch" "$S/session-save.sh" s9
git -C "$W/remote.git" rev-parse -q --verify refs/heads/session/s9 >/dev/null && ok "session-save: branch on remote" || bad "session-save: branch missing"
[ -z "$(git log --oneline origin/main..HEAD)" ] && ok "session-save: current branch untouched" || bad "session-save: moved the branch"
rm -rf docs/sessions/s9; expect session-save "restored docs/sessions/s9" "restores them" "$S/session-save.sh" --restore s9
[ -f docs/sessions/s9/STATE.md ] && ok "session-save: files are back" || bad "session-save: restore"
touch docs/sessions/s9/x.bin; expect session-save "only markdown belongs" "refuses non-markdown files" "$S/session-save.sh" s9; rm docs/sessions/s9/x.bin
expect session-save "deleted origin/session/s9" "drops the side branch" "$S/session-save.sh" --drop s9
expect host.sh "not available through host.sh" "agents cannot post statuses through host.sh" "$S/host.sh" status_post abc adlc/judge success x

# ---------------------------------------------------------------- 3. install-repo
git init -q --bare "$W/app.git" && git -C "$W/app.git" symbolic-ref HEAD refs/heads/main
git clone -q "$W/app.git" "$W/app" 2>/dev/null; cd "$W/app" || exit 1
git config user.name t; git config user.email t@example.invalid
echo "# app" > README.md; echo "# Agents" > AGENTS.md; git add -A; git commit -qm init; git push -q origin HEAD:main
export FAKE_GH_STATE="$W/app-state.json" FAKE_REMOTE="$W/app.git"
out=$("$S/install-repo.sh" "$W/app" --harness claude-code,codex --spec plain --judge human 2>&1) && ok "install: runs" || bad "install: failed: $(tail -2 <<<"$out")"
"$S/install-repo.sh" "$W/app" --harness claude-code,codex --spec plain --judge human >/dev/null 2>&1 && ok "install: rerun is safe" || bad "install: rerun failed"
grep -q '^SPEC_ADAPTER="plain"' .adlc/config.env && grep -q '^JUDGE_ADAPTER="human"' .adlc/config.env && grep -q '^HOST_ADAPTER="github"' .adlc/config.env \
  && ok "install: config names the chosen adapters" || bad "install: config adapters"
[ "$(grep -c 'adlc-kit:begin' AGENTS.md)" = 1 ] && grep -q "^# Agents" AGENTS.md && ok "install: AGENTS.md block written once, existing text kept" || bad "install: AGENTS.md"
[ -f .claude/commands/ship.md ] && grep -q "^description:" .claude/commands/ship.md && grep -q "agent-merge.sh" .claude/commands/ship.md && ok "install: Claude commands generated" || bad "install: commands"
[ -f .claude/agents/release-gate.md ] && grep -q "^name: release-gate" .claude/agents/release-gate.md && ok "install: Claude subagents generated" || bad "install: agents"
python3 -c 'import json,sys; d=json.load(open(".claude/settings.local.json")); assert d["env"]["ADLC_KIT"]==sys.argv[1]; assert "pretooluse.py" in d["hooks"]["PreToolUse"][0]["hooks"][0]["command"]; assert len(d["hooks"]["PreToolUse"])==1' "$K" 2>/dev/null \
  && ok "install: Claude settings wired once" || bad "install: settings"
grep -qxF "$W/app" "$K/.adlc/repos" && [ "$(cat .adlc/kit-path)" = "$K" ] && ok "install: repo and kit know each other" || bad "install: pointers"
git check-ignore -q .adlc/kit-path && git check-ignore -q .claude/settings.local.json && ok "install: machine-local files are git-ignored" || bad "install: gitignore"
[ -z "$(find . -type l)" ] && ok "install: no symlinks created" || bad "install: symlinks"
"$S/kit-info.sh" add-x 2>/dev/null | grep -q "change_dir: *docs/changes/add-x" && ok "kit-info: reports the plain spec folders" || bad "kit-info"
bash "$S/session-context.sh" | grep -q "No open sessions" && ok "session-context: runs" || bad "session-context"
git add -A; git commit -qm "chore: enable adlc"
git push -q origin main >/dev/null 2>&1 && bad "pre-push hook: push to main went through" || ok "pre-push hook: blocks a push to main"
git switch -qc feat/y; git push -q origin feat/y >/dev/null 2>&1 && ok "pre-push hook: allows a feature branch" || bad "pre-push hook: blocked a feature branch"

# ---------------------------------------------------------------- 4. GitHub App identity (offline)
openssl genrsa -out "$W/app-key.pem" 2048 >/dev/null 2>&1 && openssl rsa -in "$W/app-key.pem" -pubout -out "$W/app-pub.pem" >/dev/null 2>&1
mkdir -p "$W/curlbin"; cat > "$W/curlbin/curl" <<'CURL'
#!/usr/bin/env python3
import base64, os, subprocess, sys, tempfile
cfg = sys.stdin.read(); url = sys.argv[-1]
jwt = cfg.split("Bearer ", 1)[1].split('"')[0]
h, p, s = jwt.split(".")
pad = lambda x: x + "=" * (-len(x) % 4)
sig = tempfile.NamedTemporaryFile(delete=False); sig.write(base64.urlsafe_b64decode(pad(s))); sig.close()
ok = subprocess.run(["openssl", "dgst", "-sha256", "-verify", os.environ["FAKE_PUB"], "-signature", sig.name],
                    input=f"{h}.{p}".encode(), capture_output=True).returncode == 0
if not ok or "/app/installations/42/access_tokens" not in url or b'"iss":"client-abc"' not in base64.urlsafe_b64decode(pad(p)):
    sys.exit(22)
print('{"token":"tok-123"}')
CURL
chmod +x "$W/curlbin/curl"
printf 'SECRETS_ADAPTER="env"\nADLC_APP_CLIENT_ID_REF="T_CLIENT"\nADLC_APP_INSTALLATION_ID_REF="T_INST"\nADLC_APP_PRIVATE_KEY_REF="file:%s"\n' "$W/app-key.pem" >> "$K/.adlc/kit.env"
tok=$(PATH="$W/curlbin:$PATH" FAKE_PUB="$W/app-pub.pem" T_CLIENT=client-abc T_INST=42 "$K/adapters/identity/github-app.sh" 2>/dev/null)
[ "$tok" = "tok-123" ] && ok "github-app identity: signs a valid JWT and returns the token" || bad "github-app identity: got '$tok'"
(PATH="$W/curlbin:$PATH" FAKE_PUB="$W/app-pub.pem" T_INST=42 "$K/adapters/identity/github-app.sh" >/dev/null 2>&1); [ $? = 3 ] && ok "github-app identity: a missing secret exits 3, never 1" || bad "github-app identity: missing secret exit code"
"$K/adapters/identity/own-login.sh"; [ $? = 1 ] && ok "own-login identity: exits 1 (use the user's login)" || bad "own-login identity"
out=$(X=1 "$K/adapters/secrets/command.sh" A=ref -- env 2>&1); [ $? = 3 ] && ok "command secrets: no SECRET_CMD exits 3" || bad "command secrets"
[ "$(SECRET_CMD="printf value-of:%s" "$K/adapters/secrets/command.sh" A=ref1 -- bash -c 'echo $A')" = "value-of:ref1" ] && ok "command secrets: passes the value as an env var" || bad "command secrets: value"

# ---------------------------------------------------------------- 5. host conformance (GitHub adapter, fake CLI)
git init -q --bare "$W/conf.git" && git -C "$W/conf.git" symbolic-ref HEAD refs/heads/main
git clone -q "$W/conf.git" "$W/conf" 2>/dev/null; (cd "$W/conf" && echo c > README.md && git add -A && gitc commit -qm init && git push -q origin HEAD:main)
export FAKE_GH_STATE="$W/conf-state.json" FAKE_REMOTE="$W/conf.git"
if out=$(CONFORMANCE_REPO="$W/conf" CONFORMANCE_WAIT=0 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid bash "$K/tests/host-conformance.sh" github 2>&1); then
  ok "host conformance: $(tail -1 <<<"$out")"
else
  bad "host conformance: $(tail -1 <<<"$out")"; grep '^FAIL' <<<"$out"
fi

echo "---- $((n-fail))/$n passed"
[ "$fail" = 0 ]
