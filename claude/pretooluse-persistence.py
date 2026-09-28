#!/usr/bin/env python3
"""PreToolUse hook — keep conversation history out of durable project state.

This gate is deliberately separate from rulings. Rulings preserve authority the
user explicitly records. This hook prevents an agent from manufacturing authority
by writing attributed preferences, arguments, or session history into a project.

Recognized memory carriers are default-deny. Conceptual or procedural knowledge
must first enter the inactive candidate store, then pass exact, single-use
approval through ``hygiene memory``. A clean-looking format is not authority.

Handoffs are separate: an explicit handoff may preserve unfinished intent, but
never locations, project identity, or conversational history.

Config: HYGIENE_RULINGS may identify the rulings file, which this hook never owns.
"""

import json
import os
import re
import sys


RULINGS = os.path.abspath(os.path.expanduser(os.environ.get(
    "HYGIENE_RULINGS", "~/.claude/hygiene/rulings.txt"
)))

PROSE_EXT = re.compile(r"\.(?:md|mdx|markdown|rst|txt)$", re.I)
EXEMPT_PATH = re.compile(
    r"(?:^|/)(?:test|tests|spec|specs|fixtures|content|contents|locales|locale|"
    r"i18n|lang|messages|translations|legal)(?:/|$)|"
    r"\.(?:test|spec)\.[^/]+$",
    re.I,
)
MEMORY_PATH = re.compile(
    r"(?:^|/)(?:CLAUDE|AGENTS|CONTEXT|HANDOFF|MEMORY|MEMORIES|DECISIONS|LESSONS)"
    r"\.(?:md|txt)$|"
    r"(?:^|/)(?:\.claude|\.codex|\.agents)/(?:projects/[^/]+/)?"
    r"(?:memory|memories|rules|instructions)(?:/|$)",
    re.I,
)
HANDOFF_PATH = re.compile(r"(?:^|/)(?:CONTEXT|HANDOFF)\.md$", re.I)
CONTROL_PATH = re.compile(
    r"(?:^|/)(?:\.claude/settings\.json|\.claude/hygiene/(?:memory-control(?:/|$)|"
    r"pretooluse-[^/]+|stop-rulings\.py|rulings\.txt))",
    re.I,
)

# These patterns describe a conversation, a participant's stance, or a claim of
# user authority. They intentionally do not match impersonal facts or procedures.
RESIDUE = re.compile(
    r"\b(?:the )?(?:user|owner|client)\s+"
    r"(?:wanted|wants|asked|said|told|preferred|rejected|refused|corrected|"
    r"decided|agreed|approved|insisted|objected|overruled|changed (?:their|his|her) mind)\b|"
    r"\b(?:i|we|the agent|the assistant|claude)\s+"
    r"(?:argued|refused|pushed back|suggested|proposed|convinced|disagreed|"
    r"eventually agreed|finally agreed)\b|"
    r"\bwe\s+(?:eventually |finally )?(?:agreed|decided|settled|concluded)\b|"
    r"\b(?:after|during|in)\s+(?:the |this |our )?"
    r"(?:argument|discussion|conversation|session|debate)\b|"
    r"\b(?:user|owner)(?:'s|’s)\s+"
    r"(?:preference|decision|ruling|correction|request|instruction)\b|"
    r"\b(?:do not reopen|don't reopen|never reopen|settled for good|"
    r"for the (?:second|third|fourth|fifth) time)\b",
    re.I,
)

LOCATION = re.compile(
    r"(?:/Users/|/Volumes/|~/|[A-Za-z]:\\)|https?://|"
    r"\[[^\]]+\]\([^)]+\)|"
    r"\b[^\s`]+\.(?:md|py|sh|ts|tsx|js|jsx|json|yml|yaml)(?::\d+)?\b",
    re.I,
)

WRITE_TOOL = re.compile(r"write|edit|patch|notebook", re.I)
SHELL_WRITE = re.compile(
    r"(?:^|[;&|]\s*)(?:echo|printf|cat|sed|perl|python\w*)\b[^\n]*(?:>>?|\btee\b)|"
    r"(?:^|[;&|]\s*)(?:cp|mv|install|touch)\b",
    re.I,
)
BROKER_ACTION = re.compile(
    r"(?:^|\s)(?:[^\s;|]*/)?(?:hygiene\s+memory|memory(?:-control)?(?:\.py)?)\s+"
    r"(approve|promote)\s+([0-9a-f]{12})\b",
    re.I,
)


def text_of(message):
    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            block.get("text", "") for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        )
    return ""


def _last_text(path, role):
    try:
        with open(path, encoding="utf-8") as fh:
            records = [json.loads(line) for line in fh if line.strip()]
    except (OSError, ValueError):
        return ""
    for record in reversed(records):
        message = record.get("message") if isinstance(record, dict) else None
        if not isinstance(message, dict) or message.get("role") != role:
            continue
        body = text_of(message)
        if body and "tool_result" not in body:
            return body
    return ""


def last_user_text(path):
    return _last_text(path, "user")


def last_assistant_text(path):
    return _last_text(path, "assistant")


def strings(value, depth=6, include_paths=True):
    out = []

    def walk(item, remaining):
        if remaining < 0 or len(out) >= 500:
            return
        if isinstance(item, str):
            out.append(item)
        elif isinstance(item, dict):
            for key, child in item.items():
                is_path = key == "path" or key.endswith("_path")
                if key != "old_string" and (include_paths or not is_path):
                    walk(child, remaining - 1)
        elif isinstance(item, list):
            for child in item:
                walk(child, remaining - 1)

    walk(value, depth)
    return out


def paths(value, depth=6):
    out = []

    def walk(item, remaining):
        if remaining < 0 or len(out) >= 100:
            return
        if isinstance(item, dict):
            for key, child in item.items():
                if isinstance(child, str) and (key == "path" or key.endswith("_path")):
                    out.append(child)
                else:
                    walk(child, remaining - 1)
        elif isinstance(item, list):
            for child in item:
                walk(child, remaining - 1)

    walk(value, depth)
    return out


def explicitly_requested_handoff(user):
    return bool(re.search(r"\b(?:handoff|wrap up|next session)\b", user, re.I))


EXPLICIT_MEMORY_REQUEST = re.compile(
    r"\b(?:add|write|save|put|record|update)\b[^.\n:]{0,60}"
    r"\b(?:to|in|into|onto)\b[^.\n:]{0,30}"
    r"(?:CLAUDE\.md|AGENTS\.md|CONTEXT\.md|HANDOFF\.md|global claude|"
    r"\.claude/(?:memory|instructions)|memory|instructions?)\b",
    re.I,
)
AFFIRMATIVE = re.compile(
    r"\b(?:yes|approved?|go ahead|confirmed?|do it|sounds good|correct|proceed)\b",
    re.I,
)


def normalize(text):
    return re.sub(r"\s+", " ", text or "").strip().lower()


def content_shown(incoming, assistant):
    inc, asst = normalize(incoming), normalize(assistant)
    if len(inc) < 12 or not asst:
        return False
    if inc in asst:
        return True
    first_line = normalize((incoming or "").strip().splitlines()[0]) if incoming.strip() else ""
    return bool(first_line) and len(first_line) >= 12 and first_line in asst


def explicitly_authorized_memory_write(user, assistant, incoming):
    """Two paths only: the user named the write themselves, or the user
    approved the exact content after it was shown to them in chat. A bare
    'yes' with nothing matching in the prior assistant turn does not count —
    that is the manufactured-authority case this hook exists to stop."""
    if EXPLICIT_MEMORY_REQUEST.search(user):
        return True
    return bool(AFFIRMATIVE.search(user)) and content_shown(incoming, assistant)


def explicitly_approved_broker(user, action, candidate_id):
    verb = r"(?:approve|promote|publish|make durable|yes)"
    return bool(re.search(
        rf"\b{verb}\b.{{0,80}}\b{re.escape(candidate_id)}\b|"
        rf"\b{re.escape(candidate_id)}\b.{{0,80}}\b{verb}\b",
        user,
        re.I | re.S,
    )) and action.lower() in ("approve", "promote")


def block(reason, detail):
    print(
        f"Blocked: {reason}.\n\n{detail}\n\n"
        "Submit durable knowledge as an inactive `hygiene memory propose` "
        "candidate. Promotion needs the user's exact, candidate-specific "
        "approval. Personal policy belongs only in an explicitly confirmed ruling.",
        file=sys.stderr,
    )
    sys.exit(2)


def main():
    try:
        payload = json.load(sys.stdin)
    except (OSError, ValueError):
        sys.exit(0)
    if not isinstance(payload, dict):
        sys.exit(0)

    tool = str(payload.get("tool_name", ""))
    tool_input = payload.get("tool_input", {})
    values = strings(tool_input)
    command = "\n".join(values) if tool.lower() == "bash" else ""
    user = last_user_text(str(payload.get("transcript_path", "")))
    broker = BROKER_ACTION.search(command)
    if broker and not explicitly_approved_broker(user, broker.group(1), broker.group(2)):
        block(
            "durable-memory approval was attempted without candidate-specific consent",
            f"Ask the user to approve candidate {broker.group(2)} explicitly.",
        )
    if not WRITE_TOOL.search(tool) and not (command and SHELL_WRITE.search(command)):
        sys.exit(0)

    target_paths = paths(tool_input)
    incoming = command if command else "\n".join(strings(tool_input, include_paths=False))
    if not incoming:
        sys.exit(0)

    if any(os.path.abspath(os.path.expanduser(path)) == RULINGS for path in target_paths):
        sys.exit(0)

    target_blob = "\n".join(target_paths) or command
    if CONTROL_PATH.search(target_blob):
        block(
            "a protected persistence-control path was targeted directly",
            "Use the memory broker or installer; do not edit its records, hooks, or wiring.",
        )
    exempt = bool(target_paths) and all(EXEMPT_PATH.search(path) for path in target_paths)
    memory = bool(MEMORY_PATH.search(target_blob))
    prose = memory or bool(PROSE_EXT.search(target_blob))
    if not prose or exempt:
        sys.exit(0)

    if RESIDUE.search(incoming):
        block(
            "this write would persist conversation history or attributed intent",
            "Remove who wanted, proposed, rejected, corrected, or agreed to anything.",
        )

    handoff = bool(HANDOFF_PATH.search(target_blob))
    if handoff and not explicitly_requested_handoff(user):
        block(
            "an unsolicited handoff write was attempted",
            "A handoff is written only when the user explicitly asks for one.",
        )

    if handoff and LOCATION.search(incoming):
        block(
            "the handoff would persist location or project identity",
            "A handoff preserves unfinished intent only; omit names, paths, files, "
            "links, branches, and external identifiers.",
        )

    if memory and not handoff:
        assistant = last_assistant_text(str(payload.get("transcript_path", "")))
        if not explicitly_authorized_memory_write(user, assistant, incoming):
            block(
                "a direct durable-memory or instruction write was attempted "
                "without the user naming it or approving the shown content",
                "Either have the user name the write directly, or show the exact "
                "content in chat first and get an explicit approval of it. "
                "Structured prose alone does not bypass this.",
            )

    sys.exit(0)


if __name__ == "__main__":
    main()
