#!/usr/bin/env python3
"""PreToolUse hook — action rulings the user has made permanent.

The optional Stop hook can retry what the agent says; this covers what it does.
Same file, same authority: a ruling is a decision only the user can revoke, and it is
never loaded into any context window. Lines prefixed `never:` deny an action
outright; lines prefixed `ask:` deny taking it unrequested — the agent must
put the choice to the user first. Unprefixed lines are speech checks and are
skipped here, as the prefixed ones are skipped by the optional Stop hook.

The action is rendered as one text blob — the tool name, then every string
reachable in the tool's input — and each ruling's regex is matched against the
whole thing, case-insensitively. Which part a ruling keys on (tool, path,
command, content) is the regex author's choice, not this file's. The tool
ships no rules: with an empty rulings file this hook is inert.

Exemption: if the user's own last message matches the same regex, the user
raised the subject and the ruling stands down. Rulings restrain the agent
acting on its own initiative; they are not a permission system.

`bin/rulings` imports this file at intake and replays a proposed regex over
recent transcripts (`backtest`) with the exact rendering enforced here, so
intake evidence and enforcement cannot drift apart.

Config: ~/.claude/hygiene/rulings.txt   (override with HYGIENE_RULINGS)
Corpus: ~/.claude/projects              (override with HYGIENE_PROJECTS_DIR)
"""

import glob
import json
import os
import re
import signal
import sys
import time

RULINGS = os.environ.get(
    "HYGIENE_RULINGS",
    os.path.expanduser("~/.claude/hygiene/rulings.txt"),
)
PROJECTS = os.environ.get(
    "HYGIENE_PROJECTS_DIR",
    os.path.expanduser("~/.claude/projects"),
)

MODES = (("never:", "never"), ("ask:", "ask"))


def load_action_rulings(path):
    out = []
    try:
        with open(path, encoding="utf-8") as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                mode = None
                for prefix, name in MODES:
                    if line.lower().startswith(prefix):
                        mode, line = name, line[len(prefix):]
                        break
                if mode is None or "::" not in line:
                    continue  # speech checks are not action rulings
                text, _, pattern = line.partition("::")
                text, pattern = text.strip(), pattern.strip()
                if not (text and pattern):
                    continue
                try:
                    out.append((mode, text, re.compile(pattern, re.I)))
                except re.error:
                    pass  # a malformed ruling must never break the session
    except OSError:
        pass
    return out


def strings_of(value, depth=6):
    """Every string reachable in a tool_input, dict keys included."""
    out = []

    def walk(v, d):
        if d < 0 or len(out) >= 500:
            return
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, dict):
            for k, item in v.items():
                if isinstance(k, str):
                    out.append(k)
                walk(item, d - 1)
        elif isinstance(v, (list, tuple)):
            for item in v:
                walk(item, d - 1)

    walk(value, depth)
    return out


def render(tool_name, tool_input):
    return "\n".join([str(tool_name)] + strings_of(tool_input))


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


def last_user_text(transcript_path):
    try:
        with open(transcript_path, encoding="utf-8") as fh:
            records = [json.loads(l) for l in fh if l.strip()]
    except (OSError, ValueError):
        return ""
    for rec in reversed(records):
        if not isinstance(rec, dict):
            continue
        msg = rec.get("message")
        if not isinstance(msg, dict) or msg.get("role") != "user":
            continue
        # skip tool results, which are not the human speaking
        body = text_of(msg)
        if body and "tool_result" not in body:
            return body
    return ""


def backtest(pattern, limit_files=20, limit_actions=5000):
    """(count, examples) of recent recorded tool calls the pattern matches.

    The corpus is the user's own transcripts, so "ordinary work" is defined by
    what they actually did, not by anything this tool ships. Any unreadable
    file or record is skipped; an absent corpus simply reports zero.
    """
    try:
        rx = re.compile(pattern, re.I)
    except re.error:
        return 0, []
    files = (glob.glob(os.path.join(PROJECTS, "*", "*.jsonl"))
             + glob.glob(os.path.join(PROJECTS, "*.jsonl")))
    try:
        files.sort(key=os.path.getmtime, reverse=True)
    except OSError:
        pass
    count, examples, seen = 0, [], 0
    for path in files[:limit_files]:
        try:
            fh = open(path, encoding="utf-8")
        except OSError:
            continue
        with fh:
            for line in fh:
                if seen >= limit_actions:
                    return count, examples
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                msg = rec.get("message") if isinstance(rec, dict) else None
                if not isinstance(msg, dict):
                    continue
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                for block in content:
                    if not (isinstance(block, dict)
                            and block.get("type") == "tool_use"):
                        continue
                    seen += 1
                    blob = render(block.get("name", ""), block.get("input", {}))
                    if rx.search(blob):
                        count += 1
                        if len(examples) < 3:
                            lines = blob.split("\n")
                            sample = next(
                                (l for l in lines[1:] if rx.search(l)), "")
                            examples.append(
                                (lines[0] + "  " + sample).strip()[:120])
    return count, examples


def log_hit(mode, tool, text):
    # The log feeds `rulings stats`; it is advisory, so a failed write is
    # ignored rather than allowed to disturb the block itself. Fields are
    # collapsed to one line so payload-controlled text cannot forge entries.
    try:
        path = os.path.join(os.path.dirname(RULINGS) or ".", "hits.log")
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        tool = " ".join(str(tool).split())[:120]
        text = " ".join(str(text).split())[:300]
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(f"{stamp} {mode} {tool} :: {text}\n")
    except OSError:
        pass


def main():
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        sys.exit(0)
    if not isinstance(payload, dict):
        sys.exit(0)

    # A catastrophic-backtracking regex must fail open, not wedge the session:
    # matching gets a hard deadline, and anything past it counts as a miss.
    try:
        signal.signal(signal.SIGALRM, lambda s, f: sys.exit(0))
        signal.alarm(5)
    except (ValueError, OSError):
        pass

    rulings = load_action_rulings(RULINGS)
    if not rulings:
        sys.exit(0)

    tool = payload.get("tool_name", "")
    blob = render(tool, payload.get("tool_input", {}))
    asked = last_user_text(payload.get("transcript_path", ""))

    hits = [
        (mode, text) for mode, text, rx in rulings
        if rx.search(blob) and not (asked and rx.search(asked))
    ]
    try:
        signal.alarm(0)
    except (ValueError, OSError):
        pass
    if not hits:
        sys.exit(0)

    for mode, text in hits:
        log_hit(mode, tool, text)

    never_hits = [t for m, t in hits if m == "never"]
    ask_hits = [t for m, t in hits if m == "ask"]
    parts = []
    if never_hits:
        parts.append(
            "This action is covered by a ruling the user recorded:\n\n"
            + "\n".join("  - " + t for t in never_hits)
            + "\n\nThe action must not be taken, and the same result must not"
              " be reached through another tool. Put it to the user."
        )
    if ask_hits:
        parts.append(
            "This action is covered by a ruling the user recorded:\n\n"
            + "\n".join("  - " + t for t in ask_hits)
            + "\n\nThe user did not ask for this in this turn. Stop and put it"
              " to them as a question (AskUserQuestion) before going further,"
              " and do not reach the same result through another tool."
        )
    print("\n\n".join(parts), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
