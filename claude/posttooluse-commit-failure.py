#!/usr/bin/env python3
"""PostToolUseFailure hook — reinforce Hygiene's failed-commit protocol."""

import json
import re
import sys


GIT_COMMIT = re.compile(
    r"(?:^|[;&|]\s*)(?:[^\s;&|]*/)?git(?:\s+-C\s+(?:'[^']*'|\"[^\"]*\"|\S+))?"
    r"\s+commit\b",
    re.I,
)

CONTEXT = (
    "If the failed commit output names Hygiene, treat its category and reported "
    "lines as diagnostic evidence. Relocating, rewording, unstaging, exempting, "
    "or bypassing the same material does not resolve the finding. Run the "
    "project's .githooks/scan read-only scanner before attempting another commit; "
    "on an older install, use ~/.claude/hygiene/bin/scan instead. "
    "If the finding is real, preserve behavior in a test, check, type, or code and "
    "remove the narrative rule or history. If it still appears to be a "
    "false positive, stop and ask the user with the exact category, path, line, "
    "and proposed disposition. Never use HYGIENE_SKIP on the user's behalf."
)


def main():
    try:
        payload = json.load(sys.stdin)
    except (OSError, ValueError):
        return
    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return
    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(command, str) or not GIT_COMMIT.search(command):
        return
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUseFailure",
            "additionalContext": CONTEXT,
        }
    }))


if __name__ == "__main__":
    main()
