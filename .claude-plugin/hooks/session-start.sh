#!/usr/bin/env bash
# session-start.sh - ShapeUp plugin liveness check
#
# Lightweight: checks auth status. Full context priming happens
# on first use via the /shapeup skill.

set -euo pipefail

# Find the shapeup CLI
SHAPEUP_CMD=""
if command -v shapeup &>/dev/null; then
  SHAPEUP_CMD="shapeup"
elif [[ -f "$HOME/.shapeup-cli/bin/shapeup" ]]; then
  SHAPEUP_CMD="ruby -I$HOME/.shapeup-cli/lib $HOME/.shapeup-cli/bin/shapeup"
fi

if [[ -z "$SHAPEUP_CMD" ]]; then
  cat << 'EOF'
<hook-output>
ShapeUp plugin active — CLI not found on PATH.
Install: gem install shapeup-cli (or git clone https://github.com/shapeupcc/shapeup-cli.git ~/.shapeup-cli)
</hook-output>
EOF
  exit 0
fi

# Check auth status
auth_json=$($SHAPEUP_CMD auth status --json 2>/dev/null || echo '{"data":{"authenticated":false}}')

# Parse without a jq dependency. The output is pretty-printed JSON, so
# match "authenticated": true with optional whitespace after the colon.
if echo "$auth_json" | grep -qE '"authenticated": *true' 2>/dev/null; then
  profile=$(echo "$auth_json" | grep -oE '"profile": *"[^"]*"' | head -1 | sed -E 's/.*: *"([^"]*)"/\1/')
  [ -z "$profile" ] && profile="default"
  cat << EOF
<hook-output>
ShapeUp plugin active — authenticated (profile: ${profile}).
</hook-output>
EOF
else
  cat << 'EOF'
<hook-output>
ShapeUp plugin active — not authenticated.
Run: shapeup login
</hook-output>
EOF
fi
