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
Install: git clone https://github.com/shapeup-cc/shapeup-cli ~/.shapeup-cli
</hook-output>
EOF
  exit 0
fi

# Check auth status
auth_json=$($SHAPEUP_CMD auth status --json 2>/dev/null || echo '{"data":{"authenticated":false}}')

# Parse without jq dependency
if echo "$auth_json" | grep -q '"authenticated":true' 2>/dev/null; then
  profile=$($SHAPEUP_CMD config show 2>/dev/null | head -3 | tail -1 | sed 's/.*active  //' || echo "default")
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
