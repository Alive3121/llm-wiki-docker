#!/bin/bash
# Append an entry to wiki/log.md
# Usage: ./log-append.sh "描述這次變更的內容"
# Example: ./log-append.sh "新增 harness-engineering-security.md，更新 index.md"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$REPO_ROOT/log.md"
DATE=$(date '+%Y-%m-%d')
MESSAGE="${1:-（未提供變更描述）}"

# Create log file if it doesn't exist
if [ ! -f "$LOG" ]; then
  echo "# Wiki Change Log" > "$LOG"
  echo "" >> "$LOG"
fi

# Append entry (prepend after the header so newest is on top)
# Strategy: insert after line 2 (after "# Wiki Change Log\n")
ENTRY="## $DATE\n\n- $MESSAGE\n"

# Use sed to insert after the first blank line (after header)
sed -i "2a\\
\\
## $DATE\\
\\
- $MESSAGE" "$LOG"

echo "Log appended: $DATE — $MESSAGE"
