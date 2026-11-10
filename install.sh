#!/usr/bin/env bash
# Install claude-window-guard into ~/.bashrc
set -euo pipefail

UNINSTALL=0
[ "${1:-}" = "--uninstall" ] && UNINSTALL=1

MARKER_START="# >>> claude-window-guard >>>"
MARKER_END="# <<< claude-window-guard <<<"
RC="${HOME}/.bashrc"
SRC="$(cd "$(dirname "$0")" && pwd)/claude-window-guard.sh"

remove_block() {
  if [ -f "$RC" ] && grep -q "$MARKER_START" "$RC"; then
    sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$RC"
    echo "Removed claude-window-guard from $RC (backup: $RC.bak)"
  fi
}

if [ "$UNINSTALL" = "1" ]; then
  remove_block
  exit 0
fi

remove_block

cat >> "$RC" <<EOF
$MARKER_START
# Guard against typing into the wrong Claude Code window
export CLAUDE_WINDOW_GUARD="\${CLAUDE_WINDOW_GUARD:-1}"
[ -f "$SRC" ] && . "$SRC"
$MARKER_END
EOF

echo "Installed. Restart your shell or run: source ~/.bashrc"
