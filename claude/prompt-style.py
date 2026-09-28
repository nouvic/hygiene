#!/usr/bin/env python3
"""Supply opted-in writing preferences before generation, without response retries."""

import json
import os
import sys


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    if not isinstance(payload, dict):
        return
    guidance = []
    if os.environ.get("HYGIENE_CONCISE") == "1":
        guidance.append(
            "Keep progress updates to one sentence. Default final replies to at most "
            "120 words covering the result, relevant verification, and any unresolved "
            "issue. Give longer explanations only when explicitly requested or needed "
            "to deliver the requested artifact. Avoid lectures, repeated summaries, "
            "unsolicited advice, and restating the task."
        )
    if os.environ.get("HYGIENE_NO_DASHES") == "1":
        guidance.append(
            "Use commas, periods, colons, or plain hyphens instead of em or en dashes "
            "in authored prose and project copy. Preserve exact quoted material and "
            "existing data when the task requires it."
        )
    if guidance:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": " ".join(guidance),
        }}))


if __name__ == "__main__":
    main()
