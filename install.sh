#!/usr/bin/env bash
# Install claude-window-guard as a Claude Code PreToolUse hook.
# Idempotent. --uninstall removes it.
set -uo pipefail

UNINSTALL=0
[ "${1:-}" = "--uninstall" ] && UNINSTALL=1

SETTINGS_DIR="${HOME}/.claude"
SETTINGS="${SETTINGS_DIR}/settings.json"
HOOK_NAME="claude-window-guard"
SRC="$(cd "$(dirname "$0")" && pwd)/claude-window-guard.sh"
DEST_DIR="${HOME}/.local/lib/claude-window-guard"
DEST="${DEST_DIR}/claude-window-guard.sh"

mkdir -p "$SETTINGS_DIR" "$DEST_DIR"

# Always ship a fresh copy so the hook survives the repo moving.
cp "$SRC" "$DEST"
chmod +x "$DEST"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 required to edit settings.json safely"; exit 1
fi

python3 - "$SETTINGS" "$DEST" "$UNINSTALL" <<'PYEOF'
import json, sys, os
settings_path, dest, uninstall = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.get("hooks", {})
pre = hooks.get("PreToolUse", [])

def entry(cmd):
    return {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": cmd, "_name": "claude-window-guard"}]
    }

if uninstall:
    before = len(pre)
    pre = [e for e in pre
           if not any(h.get("_name") == "claude-window-guard" or "claude-window-guard" in h.get("command", "")
                      for h in e.get("hooks", []))]
    changed = before != len(pre)
    if pre:
        hooks["PreToolUse"] = pre
    else:
        hooks.pop("PreToolUse", None)
    settings["hooks"] = hooks
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
    print("Uninstalled." if changed else "Not installed.")
    sys.exit(0)

cmd = f'CLAUDE_WINDOW_GUARD="${{CLAUDE_WINDOW_GUARD:-1}}" "{dest}"'
if any("claude-window-guard" in h.get("command", "") for e in pre for h in e.get("hooks", [])):
    # update command in place
    for e in pre:
        for h in e.get("hooks", []):
            if "claude-window-guard" in h.get("command", ""):
                h["command"] = cmd
                h["_name"] = "claude-window-guard"
    print("Updated existing hook.")
else:
    pre.append(entry(cmd))
    print("Installed hook.")
hooks["PreToolUse"] = pre
settings["hooks"] = hooks
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF

if [ "$UNINSTALL" = "1" ]; then
  rm -f "$DEST"
  echo "Done. Restart Claude Code sessions to pick it up."
else
  echo "Done. Restart Claude Code sessions to pick it up."
fi
