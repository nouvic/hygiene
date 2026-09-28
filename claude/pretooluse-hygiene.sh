#!/usr/bin/env bash
# Optional Claude Code PreToolUse hook — refuses the edit before it reaches disk.
#
# The git hooks are the floor: vendor-neutral, and they catch every agent and
# every human. This is earlier and friendlier, but Claude-only and per-machine,
# so it must never be the only thing standing between a rule and your source.
#
# Wire it up in ~/.claude/settings.json — see claude/settings.json in this repo.
#
# Protocol: read the tool call as JSON on stdin; exit 2 to block and hand the
# reason back to the model. No dependencies — the payload is scanned as text.

set -uo pipefail

_hyg_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYG_HOME=""
for _c in "${HYGIENE_HOME:-}" "$_hyg_d/.." "$_hyg_d"; do
  [ -n "$_c" ] && [ -f "$_c/lib/patterns.sh" ] && { HYG_HOME="$_c"; break; }
done
[ -n "$HYG_HOME" ] || exit 0
. "$HYG_HOME/lib/patterns.sh"

PAYLOAD="$(cat)"
[ -n "$PAYLOAD" ] || exit 0

# Only guard writes into source files. Product copy, docs and locales pass through.
printf '%s' "$PAYLOAD" | grep -Eq '"file_path"[[:space:]]*:[[:space:]]*"[^"]*'"$(printf '%s' "$HYG_SRC_EXT" | sed 's/[\$]//g')"'"' || exit 0
printf '%s' "$PAYLOAD" | grep -Eq '"file_path"[[:space:]]*:[[:space:]]*"[^"]*('"$HYG_EXEMPT_PATHS"')' && exit 0

# Judge only what the edit writes. The old_string value is the text being
# replaced; scanning it too blocks every edit that removes a flagged line.
INCOMING="$(printf '%s' "$PAYLOAD" | sed -E 's/"old_string"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"//g')"

HIT="$(printf '%s' "$INCOMING" | tr ',' '\n' | hyg_match_governance | head -3)"

# A warning glyph is a banner in a comment and a value everywhere else: an icon
# in a lookup table, a label in a fixture, a character in interface copy. Drop a
# hit whose only evidence is the glyph and which is not on a comment line. Every
# other pattern is judged exactly as before.
HYG_GLYPH_ONLY='⛔|🚫|⚠️|❌|‼️'
# The payload arrives as JSON, so a hit is a fragment rather than a source
# line and cannot be matched from its start. A banner carries its comment
# opener in the same fragment; a data literal does not.
HYG_COMMENT_NEAR='(^|[^:])//|/\*|<!--|(^|")[[:space:]]*#'
HIT="$(printf '%s\n' "$HIT" | while IFS= read -r hyg_line; do
  [ -n "$hyg_line" ] || continue
  if printf '%s' "$hyg_line" | grep -Eq "$HYG_GLYPH_ONLY" \
     && ! printf '%s' "$hyg_line" | grep -Eq "$HYG_COMMENT_NEAR" \
     && [ -z "$(printf '%s' "$hyg_line" | sed -E "s/$HYG_GLYPH_ONLY//g" | hyg_match_governance)" ]; then
    continue
  fi
  printf '%s\n' "$hyg_line"
done)"

[ -n "$HIT" ] || exit 0

cat >&2 <<EOF
Blocked: this edit writes governance into a source comment.

$(printf '%s\n' "$HIT" | cut -c1-140)

Comments describe what the code does. If this is a real constraint, it needs
something that can fail — a check, a test, or a type — not a comment that a
future session will read as a standing order.

Do not retry by moving, rewording, or exempting the same material. If the
classification still appears wrong, stop and ask the user with the exact line
and category. If this suggests existing project residue, run the read-only
project scan before continuing.
EOF
exit 2
