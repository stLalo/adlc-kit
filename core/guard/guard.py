#!/usr/bin/env python3
"""ADLC guard: decides whether an agent's shell command or file edit may run.

It is agent-neutral. A harness adapter (adapters/harness/*) translates its own hook format and calls
check_bash / check_edit / check_pre_push, or pipes JSON to this file:

  echo '{"kind":"bash","command":"git push origin main","cwd":"/repo"}'      | guard.py
  echo '{"kind":"edit","path":"docs/sessions/x/STATE.md","cwd":"/repo",
         "edits":[{"old":"...","new":"..."}]}'                               | guard.py
  guard.py pre-push <cwd> < (git's pre-push stdin)

Exit 0 = allowed. Exit 2 = blocked, with the reason on stderr.

Blocks:
  shell : direct merges, tags, pushes to protected branches, status posts and deploys; the release
          decision outside the release-gate role; running or copying the identity and secrets adapters;
          writes to the kit, to .adlc/config.env or to session logs
  files : edits to the kit and to protected repo files, edits to closed sessions, and anything but an
          append to STATE.md / DECISIONS.md

Best effort: it sees the top-level command only. It stops mistakes and shortcuts, not a determined
bypass (code written to a file and run later is invisible to it). The hard gates are on the server
(branch protection plus a required CI check) and in agent-merge.sh. See docs/security-model.md.
"""
import glob
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parents[2]
KIT_REAL = os.path.realpath(KIT)


class Blocked(Exception):
    pass


def block(msg):
    raise Blocked(msg)


# ---------- settings, read as data (never executed) ----------
def _data(path, key, default=""):
    try:
        m = re.search(r'^%s="([^"]*)"' % re.escape(key), Path(path).read_text(encoding="utf-8"), re.M)
        return m.group(1) if m else default
    except OSError:
        return default


def kit_setting(key, default=""):
    return _data(KIT / ".adlc" / "kit.env", key, default)


def repo_root(cwd):
    try:
        out = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True,
                             text=True, timeout=5)
        return out.stdout.strip() or None
    except Exception:
        return None


def protected_branches(cwd):
    names = set(kit_setting("ADLC_PROTECTED_BRANCHES", "main master develop").split())
    root = repo_root(cwd)
    if root:
        names.add(_data(os.path.join(root, ".adlc", "config.env"), "MAIN_BRANCH", "main"))
    return names


def known_repos(cwd):
    repos = []
    try:
        repos = [l.strip() for l in (KIT / ".adlc" / "repos").read_text(encoding="utf-8").splitlines() if l.strip()]
    except OSError:
        pass
    root = repo_root(cwd)
    if root and root not in repos:
        repos.append(root)
    return repos


def deploy_patterns(cwd):
    pats = [p for p in (_data(os.path.join(r, ".adlc", "config.env"), "DEPLOY_BLOCK_PATTERNS") for r in known_repos(cwd)) if p]
    return "|".join(f"(?:{p})" for p in pats) or None


def _host_rules():
    rules = []
    for f in sorted(glob.glob(str(KIT / "adapters" / "host" / "*_rules.py"))):
        spec = importlib.util.spec_from_file_location(Path(f).stem, f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        rules += list(getattr(mod, "RULES", []))
    return rules


def _repo_protected():
    """Regexes for files in a target repo that only the owner edits."""
    pats = [r"(^|/)\.adlc/config\.env$"]
    for f in glob.glob(str(KIT / "adapters" / "harness" / "*" / "protected_paths.txt")):
        for line in Path(f).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                pats.append(line)
    return [re.compile(p) for p in pats]


# ---------- paths ----------
def resolve(token, cwd):
    """Absolute real path a shell word points at (best effort: $ADLC_KIT, ~ and relative paths)."""
    t = token.strip("'\"`")
    t = t.replace("${ADLC_KIT}", str(KIT)).replace("$ADLC_KIT", str(KIT))
    t = os.path.expanduser(t)
    return os.path.realpath(t if os.path.isabs(t) else os.path.join(cwd, t))


def in_kit(abspath, sub=""):
    base = os.path.join(KIT_REAL, sub) if sub else KIT_REAL
    return abspath == base or abspath.startswith(base.rstrip(os.sep) + os.sep)


def protected_reason(abspath):
    if in_kit(abspath):
        return "the kit is owner-only"
    norm = abspath.replace(os.sep, "/")
    for rx in _repo_protected():
        if rx.search(norm):
            return f"{norm} is owner-only"
    return None


WORD = re.compile(r"[^\s'\"`()=<>,;\\]+")
READERS = {"cat", "less", "more", "head", "tail", "grep", "egrep", "fgrep", "rg", "wc", "ls", "file", "stat",
           "diff", "shellcheck", "nl", "test", "["}
GIT_READ = {"status", "log", "diff", "show", "rev-parse", "ls-files", "ls-tree", "describe", "remote", "branch",
            "fetch", "blame", "cat-file", "shortlog", "tag", "config", "grep"}
WRITE = re.compile(
    r">|\btee\b|\bsed\s+(?:-\w*i\w*|--in-place)|\brm\b|\bchmod\b|\bchown\b|\btruncate\b|\bdd\b|\btouch\b"
    r"|write_text|write_bytes|open\(|\.write\(|shutil\.|os\.(?:remove|rename|replace|unlink)")
KIT_SETTINGS = r"IDENTITY_ADAPTER|SECRETS_ADAPTER|SECRET_CMD|ADLC_PROTECTED_BRANCHES|ADLC_APP_\w+|ADLC_GITHUB_API|ADLC_KIT_PUSH"


def segments(cmd):
    """Split a shell line into simple commands (best effort: ; && || | newlines)."""
    return [s.strip() for s in re.split(r"\|\||&&|[;|\n]", cmd) if s.strip()]


def command_word(seg):
    """First word of a simple command, after leading ( and VAR=value assignments."""
    words = seg.lstrip("( ").split()
    while words and re.match(r"^\w+=", words[0]) and "$(" not in words[0] and "`" not in words[0]:
        words = words[1:]
    return os.path.basename(words[0].strip("'\"")) if words else ""


def current_branch(where):
    try:
        return subprocess.run(["git", "-C", where, "branch", "--show-current"], capture_output=True,
                              text=True, timeout=5).stdout.strip()
    except Exception:
        return ""


def check_push(seg, cwd):
    m = re.search(r"(?:\bgit\b(?:\s+-{1,2}[\w-]+(?:[= ]\S+)?)*\s+push\b|agent-push\.sh['\"]?)(.*)$", seg)
    if not m:
        return
    c = re.search(r"\bgit\s+-C\s+(['\"]?)([^\s'\"]+)\1", seg)
    where = resolve(c.group(2), cwd) if c else cwd
    protected = protected_branches(where)
    names = "/".join(sorted(protected))
    tokens = [x.strip("'\"") for x in m.group(1).split()]
    if any(x in ("--tags", "--follow-tags") or "refs/tags/" in x or re.match(r"\+?v\d+\.\d+", x) for x in tokens):
        block("tags are pushed only by the kit scripts")
    if any(x in ("--all", "--mirror", "--prune") for x in tokens):
        block("never push all branches; push one feature branch")
    if "--no-verify" in tokens:
        block("don't skip the pre-push hook")
    if any(x in ("-f", "--force", "-d", "--delete") or x.startswith(("--force", "--delete")) for x in tokens) \
            or any(x.startswith("+") or x.startswith(":") for x in tokens):
        block("no force pushes and no remote deletes")
    refspecs = [x for x in tokens if not x.startswith("-") and x != "origin"]
    for r in refspecs:
        dst = r.split(":")[-1]
        dst = dst[len("refs/heads/"):] if dst.startswith("refs/heads/") else dst
        if "*" in r:
            block("no wildcard refspecs; push one branch")
        if dst == "HEAD":
            dst = current_branch(where)
        if dst in protected:
            block(f"never push to {names}; open a pull request")
    if not refspecs and current_branch(where) in protected:
        block(f"never push to {names}; open a pull request")


def check_bash(command, cwd, role=None):
    """Raise Blocked if this shell command line must not run. role = the harness's subagent name, if any."""
    flat = " ".join(command.split())

    for pat, why in _host_rules():
        if re.search(pat, flat):
            block(why)
    secret = kit_setting("SECRET_BLOCK_PATTERNS")
    if secret and re.search(secret, flat):
        block("the agent's credentials are read only by the identity adapter")
    if re.search(r"(^|[\s;&|(])(export\s+)?(" + KIT_SETTINGS + r")=(?!(\"\"|''|\s|$))", flat):
        block("kit settings are set only in the kit's .adlc/kit.env")

    # git tag (incl. git -C <repo> tag): listing ok, creating/deleting not
    for m in re.finditer(r"\bgit\b(?:\s+-C\s+\S+)?\s+tag\b([^;&|]*)", flat):
        args = m.group(1).split()
        if args and not args[0].startswith(("-l", "--list", "-n", "--contains", "--points-at",
                                            "--sort", "--merged", "--no-merged")):
            block("tags are created only by the kit scripts")

    pats = deploy_patterns(cwd)
    if pats and re.search(pats, flat):
        block("deploys run only through agent-deploy.sh")

    # The main thread has no role; only the release-gate role may post a release decision.
    if "release-decision.sh" in flat and role != "release-gate":
        block("release-decision.sh is reserved for the release-gate role")

    if re.search(r"(\bsed\s+-i|>(?!>)|\btruncate\b|\brm\b|\bmv\b).*docs/sessions/.*(STATE|DECISIONS)\.md", flat):
        block("STATE.md and DECISIONS.md are append-only; append with your edit tool")

    here = cwd
    for seg in segments(command):
        cd = re.match(r"^\(?\s*cd\s+(\S+)\s*$", seg)
        if cd:
            here = resolve(cd.group(1), here)
            continue
        check_push(seg, here)
        words = [(w.start(), resolve(w.group(0), here)) for w in WORD.finditer(seg)]
        cmdw = command_word(seg)

        # lib.sh loads the agent identity: run the kit scripts instead of sourcing it.
        for m in re.finditer(r"(?:^|[\s;&|('\"])(?:source|\.)\s+['\"]?([^\s'\";)]+)", seg):
            if resolve(m.group(1), here) == os.path.join(KIT_REAL, "core", "scripts", "lib.sh"):
                block("lib.sh loads the agent identity; run the kit scripts instead of sourcing it")

        # Identity and secrets adapters mint or read credentials: reading the file is fine, running
        # or copying it is not.
        for _, p in words:
            if (in_kit(p, "adapters/identity") or in_kit(p, "adapters/secrets")) and p.endswith(".sh"):
                reading = cmdw in READERS or re.match(r"^\(?\s*(bash|sh|zsh)\s+-n\s", seg)
                if not reading or re.search(r">|\$\(|`|\bbase64\b|\btee\b", seg):
                    block("the agent's credentials are minted only inside the kit scripts")

        # git inside the kit: reading is fine, changing it is the owner's job.
        g = re.search(r"\bgit\b((?:\s+-C\s+\S+|\s+-{1,2}[\w-]+(?:=\S+)?)*)\s+([a-z][\w-]*)", seg)
        if g:
            c = re.search(r"-C\s+(\S+)", g.group(1))
            where = resolve(c.group(1), here) if c else here
            if in_kit(os.path.realpath(where)) and g.group(2) not in GIT_READ:
                block("the kit is owner-only (update it yourself, not through the agent)")

        m = re.match(r"^\(?\s*(?:\w+=\S*\s+)*(cp|mv|ln|install|rsync)\b", seg)
        if m and words:
            targets = words[1:] if m.group(1) == "mv" else words[-1:]
            for _, p in targets:
                why = protected_reason(p)
                if why:
                    block(why)
        w = WRITE.search(seg)
        if w:
            for pos, p in words:
                if pos >= w.start():
                    why = protected_reason(p)
                    if why:
                        block(why)


def check_edit(path, cwd, content=None, edits=None):
    """Raise Blocked if this file edit must not happen.
    content = full new text of a whole-file write; edits = [(old, new), ...] for in-place edits."""
    abspath = os.path.abspath(path if os.path.isabs(path) else os.path.join(cwd, path))
    why = protected_reason(os.path.realpath(abspath))
    if why:
        block(why)
    norm = abspath.replace(os.sep, "/")

    m = re.search(r"^(.*?/docs/sessions)/([^/_][^/]*)/", norm)
    if not m:
        return
    session_md = os.path.join(m.group(1), m.group(2), "SESSION.md")
    if os.path.isfile(session_md):
        st = re.search(r"^status:\s*([a-z-]+)", open(session_md, encoding="utf-8").read(), re.M)
        if st and st.group(1) in ("complete", "rolled-over", "abandoned"):
            block(f"session {m.group(2)} is {st.group(1)} and frozen")

    name = os.path.basename(norm)
    if name in ("STATE.md", "DECISIONS.md") and os.path.isfile(abspath):
        current = open(abspath, encoding="utf-8").read()
        if content is not None:
            if not content.startswith(current.rstrip("\n")):
                block(f"{name} is append-only; keep all existing content")
        for old, new in (edits or []):
            if not new.startswith(old):
                block(f"{name} is append-only; the new text must start with the old text")
            if old and not current.rstrip("\n").endswith(old.rstrip("\n")):
                block(f"{name}: append only at the end of the file")


def check_pre_push(cwd, lines, kit_push=False):
    """git pre-push hook: lines of '<local ref> <local sha> <remote ref> <remote sha>'."""
    protected = protected_branches(cwd)
    for line in lines:
        parts = line.split()
        if len(parts) != 4:
            continue
        _, local_sha, remote_ref, remote_sha = parts
        if remote_ref.startswith("refs/tags/") and not kit_push:
            block("tags are pushed only by the kit scripts")
        if remote_ref.startswith("refs/heads/"):
            branch = remote_ref[len("refs/heads/"):]
            if branch in protected:
                block(f"never push to {branch}; open a pull request")
            if set(local_sha) == {"0"} and not kit_push:
                block("no remote branch deletes")
            if set(remote_sha) != {"0"} and set(local_sha) != {"0"} and not branch.startswith("session/"):
                ff = subprocess.run(["git", "-C", cwd, "merge-base", "--is-ancestor", remote_sha, local_sha],
                                    capture_output=True)
                if ff.returncode == 1:
                    block("no force pushes")


def main(argv):
    try:
        if len(argv) >= 2 and argv[1] == "pre-push":
            cwd = argv[2] if len(argv) > 2 else os.getcwd()
            check_pre_push(cwd, sys.stdin.read().splitlines(), kit_push=os.environ.get("ADLC_KIT_PUSH") == "1")
            return 0
        data = json.load(sys.stdin)
        cwd = data.get("cwd") or os.getcwd()
        if data.get("kind") == "bash":
            check_bash(data.get("command", ""), cwd, data.get("role"))
        elif data.get("kind") == "edit":
            edits = [(e.get("old", ""), e.get("new", "")) for e in data.get("edits") or []]
            check_edit(data.get("path", ""), cwd, data.get("content"), edits)
        return 0
    except Blocked as e:
        print(f"BLOCKED by the ADLC guard: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
