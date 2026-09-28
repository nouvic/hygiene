#!/usr/bin/env python3
"""Optional Stop hook — retries replies that trip a speech ruling.

This hook is deliberately not installed by default. Claude Code defines a
blocked Stop event as "continue the conversation", which generates another
model response. Some interfaces keep the original visible, so one violation
can appear as two answers and consume the tokens for both. Install it only via
``install-claude --response-retries`` when that tradeoff is acceptable.

A ruling is a decision only the user can revoke: what the agent may never
propose, and what it may never raise unprompted. Rulings are NOT loaded into
the model's context. They are read here, after the fact, and checked against
what the agent actually said. That is the whole point — a constraint the model
never reads is a constraint it cannot weigh, argue with, or find an exception to.

It also means the file costs nothing. It can grow to a thousand lines and no
context window ever sees it.

Exemption: if the user's own last message raised the subject, the agent is
answering a question, not re-opening a settled one. Rulings block unprompted
mentions only.

Config: ~/.claude/hygiene/rulings.txt   (override with HYGIENE_RULINGS)
Format: one per line —  <ruling text> :: <regex>

Lines prefixed `never:` or `ask:` are action rulings; they belong to the
PreToolUse hook (pretooluse-rulings.py) and are skipped here, so a reply that
merely describes one does not trip this hook.
"""

import json
import os
import re
import sys

RULINGS = os.environ.get(
    "HYGIENE_RULINGS",
    os.path.expanduser("~/.claude/hygiene/rulings.txt"),
)


def load_rulings(path):
    out = []
    try:
        with open(path, encoding="utf-8") as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#") or "::" not in line:
                    continue
                if line.lower().startswith(("never:", "ask:")):
                    continue  # action rulings; the PreToolUse hook owns them
                text, _, pattern = line.partition("::")
                text, pattern = text.strip(), pattern.strip()
                if not (text and pattern):
                    continue
                try:
                    out.append((text, re.compile(pattern, re.I)))
                except re.error:
                    pass  # a malformed ruling must never break the session
    except OSError:
        pass
    return out


def text_of(message):
    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            b.get("text", "") for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return ""


def last_turns(transcript_path):
    """Return (last assistant text, last user text)."""
    assistant, user = "", ""
    try:
        with open(transcript_path, encoding="utf-8") as fh:
            records = [json.loads(l) for l in fh if l.strip()]
    except (OSError, ValueError):
        return assistant, user

    for rec in reversed(records):
        if not isinstance(rec, dict):
            continue
        msg = rec.get("message")
        if not isinstance(msg, dict):
            continue
        role = msg.get("role")
        if role == "assistant" and not assistant:
            assistant = text_of(msg)
        elif role == "user" and not user:
            # skip tool results, which are not the human speaking
            body = text_of(msg)
            if body and "tool_result" not in body:
                user = body
        if assistant and user:
            break
    return assistant, user


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        sys.exit(0)

    # Never retry twice in a row; a hook that can loop is worse than no hook.
    if payload.get("stop_hook_active"):
        sys.exit(0)

    rulings = load_rulings(RULINGS)
    if not rulings:
        sys.exit(0)

    assistant, user = last_turns(payload.get("transcript_path", ""))
    if not assistant:
        sys.exit(0)

    hits = [
        text for text, pattern in rulings
        if pattern.search(assistant) and not pattern.search(user)
    ]
    if not hits:
        sys.exit(0)

    print(
        "This response raises something the user has settled permanently:\n\n"
        + "\n".join("  - " + h for h in hits)
        + "\n\nThey did not bring it up. Remove it — including as a supporting\n"
          "argument or justification — and answer what was actually asked.",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
