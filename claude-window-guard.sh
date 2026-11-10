#!/usr/bin/env bash
# claude-window-guard — PreToolUse hook for Claude Code.
#
# Blocks Claude Code Bash tool calls when the terminal window running this
# Claude session is NOT the OS-focused window. That's the "typed into the
# wrong Claude window" mistake, caught before the command executes.
#
# Claude Code invokes this with JSON on stdin:
#   {"session_id": "...", "tool_name": "Bash", "tool_input": {"command": "..."}, ...}
#
# Exit 0 + JSON {"decision":"block","reason":"..."} -> block the tool call.
# Exit 0 with no output (or {"decision":"approve"}) -> allow.
#
# Focus detection:
#   macOS:   osascript — is the frontmost app the terminal that owns this hook?
#   X11:     xdotool — compare the active window's PID against our process tree
#   Wayland: can't reliably tell -> never block (fail open)
#
# Opt out: set CLAUDE_WINDOW_GUARD=0 in the environment Claude runs in.

set -uo pipefail

# Only guard Bash tool calls (BashOutput etc. pass through).
input=$(cat)
tool_name=$(printf '%s' "$input" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
[ "$tool_name" = "Bash" ] || exit 0

[ "${CLAUDE_WINDOW_GUARD:-1}" = "0" ] && exit 0

block() {
  printf '{"decision":"block","reason":"%s"}' "$1"
  exit 0
}

warn_only() {
  [ "${CLAUDE_WINDOW_GUARD:-1}" = "warn" ]
}

# --- Focus check -----------------------------------------------------------

focused_pid_of_active_window() {
  case "$(uname -s)" in
    Linux)
      command -v xdotool >/dev/null 2>&1 || { echo "unknown"; return; }
      [ -n "${DISPLAY:-}" ] || { echo "unknown"; return; }
      xdotool getactivewindow getwindowpid 2>/dev/null || echo "unknown"
      ;;
    Darwin)
      echo "unknown"  # handled separately below
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Walk up from this hook process to the root; if the active window's PID is
# anywhere in our ancestry, this hook was launched by the focused terminal.
is_focused() {
  case "$(uname -s)" in
    Darwin)
      # Frontmost app name should match our terminal's app.
      local front term
      front=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || echo "")
      term=$(osascript -e 'tell application "System Events" to get name of first application process whose unix id is '"$PPID" 2>/dev/null || echo "")
      # Fallback chain: compare frontmost app to the app that spawned us.
      [ -n "$front" ] && [ -n "$term" ] && [ "$front" = "$term" ] && return 0
      # Terminal.app / iTerm2 / VS Code / Ghostty all match by name fragment.
      case "$front" in
        *Terminal*|*iTerm*|*Code*|*Ghostty*|*kitty*|*Alacritty*|*Warp*|*WezTerm*)
          # frontmost IS a terminal; can't cheaply tell WHICH window, so
          # compare window titles for the session hint if provided.
          return 0
          ;;
      esac
      return 1
      ;;
    Linux)
      local active
      active=$(focused_pid_of_active_window)
      [ "$active" = "unknown" ] && return 0   # fail open when we can't tell
      local p=$$
      while [ "$p" -gt 1 ]; do
        [ "$p" = "$active" ] && return 0
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        [ -z "$p" ] && break
      done
      return 1
      ;;
  esac
}

if ! is_focused; then
  MSG="Window guard: this Claude session's terminal is NOT the focused window. You may be about to run a command meant for a DIFFERENT Claude window. Click this terminal first, then retry. (Disable with CLAUDE_WINDOW_GUARD=0.)"
  if warn_only; then
    printf '{"decision":"approve"}'
    exit 0
  fi
  block "$MSG"
fi

exit 0
