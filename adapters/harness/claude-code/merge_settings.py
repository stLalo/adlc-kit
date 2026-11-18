#!/usr/bin/env python3
"""merge_settings.py <settings.json path> <kit path>
Idempotently adds the ADLC_KIT env var and the kit's PreToolUse guard and SessionStart hooks to a
Claude Code settings file, keeping everything already there (permissions, models, other hooks)."""
import json
import os
import sys

path, kit = sys.argv[1], os.path.abspath(sys.argv[2])
data = {}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

data.setdefault("env", {})["ADLC_KIT"] = kit
hooks = data.setdefault("hooks", {})


def ensure(event, matcher, command):
    groups = hooks.setdefault(event, [])
    for g in groups:
        for h in g.get("hooks", []):
            if h.get("command") == command:
                return
    groups.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})


ensure("PreToolUse", "Bash|Edit|MultiEdit|Write|NotebookEdit",
       f'python3 "{kit}/adapters/harness/claude-code/pretooluse.py"')
ensure("SessionStart", "startup|resume|compact", f'bash "{kit}/core/scripts/session-context.sh"')

os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(f"  merged kit hooks into {path}")
