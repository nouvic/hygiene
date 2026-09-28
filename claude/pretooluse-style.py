#!/usr/bin/env python3
"""Check newly authored lines in direct file writes against opted-in punctuation style."""

import difflib
import json
import os
import re
import sys


EXEMPT = re.compile(
    r"(?:^|/)(?:\.git|\.githooks|node_modules|vendor|dist|build|out|target|"
    r"coverage|\.next|\.venv|__pycache__|\.scribe|tests?|spec|__tests__|fixtures|testdata)/|"
    r"\.(?:test|spec)\.|\.min\.|-lock\.|\.lock$|\.d\.ts$"
)
TEXT_FILE = re.compile(
    r"\.(?:md|mdx|markdown|rst|txt|json|html|xml|toml|ts|tsx|js|jsx|mjs|cjs|"
    r"css|scss|sass|less|py|rb|go|rs|java|kt|swift|c|h|cc|cpp|hpp|cs|php|sh|"
    r"bash|zsh|sql|vue|svelte|astro|ex|exs|lua|dart|scala|clj|hs|ml|r|jl|tf|yml|yaml)$",
    re.I,
)
DASH = re.compile("[\u2013\u2014]")


def main():
    if os.environ.get("HYGIENE_NO_DASHES") != "1":
        return
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    if not isinstance(payload, dict):
        return
    tool, data = payload.get("tool_name"), payload.get("tool_input", {})
    if not isinstance(data, dict) or tool not in ("Write", "Edit", "MultiEdit"):
        return
    path = data.get("file_path", "")
    if not isinstance(path, str) or EXEMPT.search(path) or not TEXT_FILE.search(path):
        return
    if tool == "Write":
        try:
            with open(path, encoding="utf-8") as fh:
                old = fh.read()
        except FileNotFoundError:
            old = ""
        except (OSError, UnicodeError):
            return
        changes = [(old, data.get("content", ""))]
    else:
        edits = data.get("edits", []) if tool == "MultiEdit" else [data]
        if not isinstance(edits, list):
            return
        changes = [(e.get("old_string", ""), e.get("new_string", ""))
                   for e in edits if isinstance(e, dict)]
    for old, new in changes:
        if not isinstance(old, str) or not isinstance(new, str):
            continue
        added = (line[2:] for line in difflib.ndiff(old.splitlines(), new.splitlines())
                 if line.startswith("+ "))
        if any(DASH.search(line) for line in added):
            print(f"hygiene: em/en dash in new text for {path}. "
                  "Use a comma, period, colon, or plain hyphen.", file=sys.stderr)
            raise SystemExit(2)


if __name__ == "__main__":
    main()
