#!/usr/bin/env python3
"""Claude Code PreToolUse hook → ADLC guard.

Wired by install.sh into <repo>/.claude/settings.local.json for the tools
Bash|Edit|MultiEdit|Write|NotebookEdit. Reads Claude Code's hook JSON on stdin and asks the neutral
guard (core/guard/guard.py). Exit 2 blocks the tool call; the reason on stderr is shown to Claude.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "core" / "guard"))
import guard  # noqa: E402

data = json.load(sys.stdin)
tool = data.get("tool_name", "")
inp = data.get("tool_input", {}) or {}
cwd = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

try:
    if tool == "Bash":
        # agent_type is present for subagent calls: it is how the release-gate role is recognised.
        guard.check_bash(inp.get("command", ""), cwd, data.get("agent_type"))
    elif tool in ("Edit", "MultiEdit", "Write", "NotebookEdit"):
        path = inp.get("file_path") or inp.get("notebook_path") or ""
        if tool == "Write":
            guard.check_edit(path, cwd, content=inp.get("content", ""))
        else:
            edits = [(e.get("old_string", ""), e.get("new_string", "")) for e in (inp.get("edits") or [inp])]
            guard.check_edit(path, cwd, edits=edits)
except guard.Blocked as e:
    print(f"BLOCKED by the ADLC guard: {e}", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
