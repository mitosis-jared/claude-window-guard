# claude-window-guard

Stop Claude Code from running commands in the wrong window.

You have three Claude Code sessions open. You type a command meant for window A
into window B. Claude in window B happily executes it — in the wrong repo, on
the wrong branch, against the wrong server. This hook catches that mistake
before the command runs.

## How it works

A Claude Code **PreToolUse hook**. Before every Bash tool call, it asks the OS
which window is focused:

- **Linux/X11** — `xdotool getactivewindow getwindowpid`, compared against the
  hook process's own ancestry. If the focused window's PID isn't in this
  session's process tree, you're typing into a different window.
- **macOS** — `osascript` compares the frontmost app against the terminal that
  spawned the hook.
- **Wayland** — can't reliably tell, so it never blocks (fails open).

If the terminal running *this* Claude isn't focused, the tool call is blocked
with a clear reason. Click the right window, retry, done.

## Install

```bash
git clone https://github.com/mitosis-jared/claude-window-guard
cd claude-window-guard
./install.sh
```

Restart your Claude Code sessions. To remove: `./install.sh --uninstall`.

## Options

- `CLAUDE_WINDOW_GUARD=0` — disable entirely (env of the Claude process).
- `CLAUDE_WINDOW_GUARD=warn` — allow but note it.

## Why a hook and not a shell alias?

The mistake happens inside Claude Code's Bash tool, not your raw shell. A
PreToolUse hook is the only layer that sees the command *and* can block it
before execution. Shell-level guards can't see tool calls.

## Requirements

- Claude Code
- Linux/X11: `xdotool`. macOS: nothing extra.

## License

MIT
