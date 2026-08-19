#!/bin/bash
# Pushes a notification (ntfy.sh phone push + macOS desktop banner) for Notification/Stop hook events.
# Usage: ntfy-notify.sh <event-label>, with the hook's stdin JSON piped in.
# Topic lives in ~/.claude/ntfy-topic (untracked, mode 600) — not baked into this script.

TOPIC=$(cat "$HOME/.claude/ntfy-topic" 2>/dev/null)
[ -z "$TOPIC" ] && exit 0
EVENT_LABEL="$1"

INPUT="$(cat)"
MSG="$(echo "$INPUT" | jq -r '.message // empty')"
if [ -z "$MSG" ]; then
  MSG="Claude Code: $EVENT_LABEL"
fi

curl -s -H "Title: Claude Code" -H "Priority: high" -H "Tags: robot" -d "$MSG" "https://ntfy.sh/$TOPIC" >/dev/null 2>&1
osascript -e "display notification \"$MSG\" with title \"Claude Code\" sound name \"Glass\"" >/dev/null 2>&1

exit 0
