#!/usr/bin/env bash
# Test suite for claude-window-guard. Run: ./test.sh
# Exits non-zero on any failure.
set -uo pipefail
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

HOOK="$(cd "$(dirname "$0")" && pwd)/claude-window-guard.sh"

# 1. Syntax
bash -n "$HOOK" && ok "syntax valid" || bad "syntax invalid"

# 2. Non-Bash tools pass through silently
out=$(echo '{"tool_name":"Read","tool_input":{}}' | bash "$HOOK"; echo "rc=$?")
[ "$out" = "rc=0" ] && ok "non-Bash tool passes" || bad "non-Bash tool: got '$out'"

# 3. Disabled guard passes
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | CLAUDE_WINDOW_GUARD=0 bash "$HOOK"; echo "rc=$?")
[ "$out" = "rc=0" ] && ok "CLAUDE_WINDOW_GUARD=0 passes" || bad "disabled guard blocked: '$out'"

# 4. Block decision is valid JSON with decision=block and a reason
#    (DISPLAY=:99 has no X server -> fail-open path returns empty, so we
#     instead test the block() emitter directly with a stubbed is_focused.)
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash -c '
  source "'"$HOOK"'"; is_focused() { return 1; }
  guard_main
' 2>/dev/null)
decision=$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("decision",""), bool(d.get("reason")))' 2>/dev/null || echo "PARSE_ERROR")
[ "$decision" = "block True" ] && ok "unfocused window -> valid block JSON" || bad "block output: '$decision'"

# 5. Warn mode approves instead of blocking
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | CLAUDE_WINDOW_GUARD=warn bash -c '
  source "'"$HOOK"'"; is_focused() { return 1; }
  guard_main
' 2>/dev/null)
decision=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision",""))' 2>/dev/null || echo "PARSE_ERROR")
[ "$decision" = "approve" ] && ok "warn mode approves" || bad "warn mode: '$out'"

# 6. Malformed stdin doesn't crash the hook
echo 'not json' | bash "$HOOK" >/dev/null 2>&1 && ok "malformed input tolerated" || bad "crashed on malformed input"

# 7. Install/uninstall round-trip against a temp HOME
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cp ~/.claude/settings.json "$TMPHOME/.claude/settings.json" 2>/dev/null || echo '{}' > "$TMPHOME/.claude/settings.json"
HOME="$TMPHOME" bash "$(dirname "$HOOK")/install.sh" >/dev/null 2>&1
python3 -c "
import json,sys
h=json.load(open('$TMPHOME/.claude/settings.json'))
cmds=[hk['command'] for e in h['hooks']['PreToolUse'] for hk in e['hooks']]
assert any('claude-window-guard' in c for c in cmds), cmds
" && ok "install adds hook to settings.json" || bad "install did not add hook"
HOME="$TMPHOME" bash "$(dirname "$HOOK")/install.sh" --uninstall >/dev/null 2>&1
python3 -c "
import json
h=json.load(open('$TMPHOME/.claude/settings.json'))
pre=h.get('hooks',{}).get('PreToolUse',[])
assert not any('claude-window-guard' in hk['command'] for e in pre for hk in e['hooks']), pre
" && ok "uninstall removes hook cleanly" || bad "uninstall left residue"
rm -rf "$TMPHOME"

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" = 0 ]
