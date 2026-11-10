#!/usr/bin/env bash
# claude-window-guard: stop typing into the wrong Claude Code window.
#
# Installs a shell precommand hook. Before a command runs (or before you
# send a line in interactive mode), it checks whether THIS terminal window
# is the one your OS considers focused. If it isn't, it blocks the command
# and flashes a warning — because you were probably typing into the wrong
# Claude.
#
# Supports: Linux (X11 via xdotool, Wayland via swaymsg/hyprctl best-effort)
#           macOS (osascript)
set -euo pipefail

is_focused() {
  # Return 0 if the current terminal window is the OS-focused window.
  case "$(uname -s)" in
    Darwin)
      local front script
      front=$(osascript -e 'tell application "System Events" to get id of first application process whose frontmost is true' 2>/dev/null || echo "")
      [ "$front" = "$TERM_PROGRAM_PARENT" ] && return 0
      # fallback: compare window titles
      osascript -e 'tell application "System Events" to get name of first window of (first application process whose frontmost is true)' 2>/dev/null \
        | grep -qi "claude" && return 0
      return 1
      ;;
    Linux)
      if command -v xdotool >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        local active
        active=$(xdotool getactivewindow getwindowpid 2>/dev/null || echo "")
        [ -n "$active" ] && [ "$active" = "$$" -o "$active" = "$PPID" ] && return 0
        # compare window class of active window to this terminal's
        local mine active_class
        mine=$(xdotool search --pid "$PPID" getwindowclassname 2>/dev/null | head -1 || echo "")
        active_class=$(xdotool getactivewindow getwindowclassname 2>/dev/null || echo "")
        [ -n "$mine" ] && [ "$mine" = "$active_class" ] && return 0
        return 1
      fi
      # Wayland best-effort: if we can't tell, don't block.
      return 0
      ;;
    *)
      return 0  # unknown OS: never block
      ;;
  esac
}

# Only guard when running inside Claude Code (interactive session).
guard() {
  # Heuristic: this shell is the parent of a running `claude` process.
  if ! pgrep -P "$$" -x claude >/dev/null 2>&1 && \
     ! ps -o comm= -p "$PPID" 2>/dev/null | grep -q '^claude'; then
    return 0
  fi
  if ! is_focused; then
    echo ""
    echo "⚠️  CLAUDE WINDOW GUARD: this terminal is NOT the focused window."
    echo "    You may be about to type into the WRONG Claude session."
    echo "    Click this window first, then re-run your command."
    echo "    (Disable: unset CLAUDE_WINDOW_GUARD)"
    if [ "${CLAUDE_WINDOW_GUARD:-1}" = "1" ]; then
      return 1
    fi
  fi
  return 0
}

# Wire into bash's preexec (via DEBUG trap, the poor man's preexec).
case "${CLAUDE_WINDOW_GUARD:-1}" in
  1) trap 'guard "$_"' DEBUG ;;
esac
