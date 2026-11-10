# claude-window-guard

Stop typing into the wrong Claude Code window.

If you run multiple Claude Code sessions side by side, you *will* eventually
type a command meant for window A into window B. Sometimes that's harmless.
Sometimes you just told Claude to `rm -rf` in the wrong repo.

This is a tiny shell guard that detects the mistake before it happens: it
checks whether the terminal you're typing into is actually the window your
OS has focused. If it isn't, it blocks the command and flashes a warning.

## How it works

- Installs a `DEBUG`-trap preexec hook in your shell (bash).
- When a command fires inside a shell that is (or is a parent of) a running
  `claude` process, it asks the OS which window is focused:
  - macOS: `osascript` (System Events)
  - Linux/X11: `xdotool`
  - Wayland: best-effort, never blocks when it can't tell.
- If the focused window isn't your terminal, the command is blocked with a
  loud warning. Click the right window, run it again.

## Install

```bash
git clone https://github.com/mitosis-jared/claude-window-guard
cd claude-window-guard
./install.sh
```

Then restart your shell or `source ~/.bashrc`.

## Usage

It's automatic. When it saves you, you'll see:

```
⚠️  CLAUDE WINDOW GUARD: this terminal is NOT the focused window.
    You may be about to type into the WRONG Claude session.
    Click this window first, then re-run your command.
```

### Options

- `CLAUDE_WINDOW_GUARD=0` — disable for one command / one session.
- `CLAUDE_WINDOW_GUARD=warn` — warn but don't block.

## Requirements

- bash
- macOS: none beyond the OS. Linux/X11: `xdotool`.

## Uninstall

Remove the claude-window-guard block from `~/.bashrc` (or run
`./install.sh --uninstall`).

## License

MIT
