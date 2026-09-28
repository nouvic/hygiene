#!/usr/bin/env bash
# Shared pattern and exemption definitions.
# Sourced by bin/scan and hooks/*. bash 3.2 compatible.
#
# Precision matters more than recall here. A scanner that flags ordinary code
# gets uninstalled the same day, and then none of the rest matters.

# ---------------------------------------------------------------- exemptions
# Paths where prose legitimately contains imperatives and negations:
# product copy, translations, legal text, test fixtures, generated output,
# dependencies. Test suites use both filename and directory conventions.
HYG_EXEMPT_PATHS='(^|/)(node_modules|vendor|dist|build|out|target|coverage|\.next|\.git|\.githooks|\.husky|\.venv|__pycache__)/|(^|/)(content|contents|locales|locale|i18n|lang|messages|translations|test|tests|spec|__tests__|fixtures|testdata)/|(^|/)legal[^/]*\.|(^|/)legal/|\.(test|spec)\.|\.min\.|-lock\.|\.lock$|\.d\.ts$'

# Files whose whole body is prose; scanned as documents, not for comments.
HYG_DOC_EXT='\.(md|mdx|markdown|rst|txt)$'

# Files that carry code, and therefore carry comments. Data and config files are
# excluded — they have no comments to scan and would distort the density figure.
HYG_SRC_EXT='\.(ts|tsx|js|jsx|mjs|cjs|css|scss|sass|less|py|rb|go|rs|java|kt|swift|c|h|cc|cpp|hpp|cs|php|sh|bash|zsh|sql|vue|svelte|astro|ex|exs|lua|dart|scala|clj|hs|ml|r|jl|tf|yml|yaml)$'

# Extensions where a leading `#` is a comment (excludes CSS, where # is a colour).
HYG_HASH_EXT='\.(py|rb|sh|bash|zsh|yml|yaml|toml|tf|pl|r|jl|nim|ex|exs)$'

# ============================================================================
# GOVERNANCE — split by case sensitivity, because SHOUTING is the signal.
# ============================================================================

# --- case SENSITIVE ---------------------------------------------------------
# Loud markers, and imperatives in capitals. Nothing that merely describes what
# code does needs to shout. "can never block a deploy" must not match; "NEVER
# change this" must.
HYG_GOV_CS='⛔|🚫|⚠️|❌|‼️|(^|[^A-Za-z])(NEVER|DO NOT|MUST NOT|SHALL NOT|FORBIDDEN|PROHIBITED|DO NOT REOPEN)([^A-Za-z]|$)|CLAUDE\.md|AGENTS\.md|§[[:space:]]*[0-9]'

# --- case INSENSITIVE -------------------------------------------------------
# A reader-directed imperative needs a demonstrative object. This is what
# separates an instruction from a description:
#   "a CDN outage can never block a deploy"  -> no match (describes behaviour)
#   "do not let a hung gateway hang the UI"  -> no match (describes intent)
#   "never change this file by hand"         -> match    (instructs a reader)
HYG_IMPERATIVE='(do not|dont|don.t|never|must not|shall not|no session)[[:space:]]+(change|edit|modify|touch|remove|delete|reopen|revert|rename|refactor|reintroduce|overwrite|add)[[:space:]]+(this|it|these|those|that|the|any|them)'

# Assertions of authority. Deliberately does NOT include a bare "owner" —
# in a payments codebase "the owner's account" is a business term, not a ruling.
HYG_AUTHORITY='owner.?s?[[:space:]]+(ruling|decision|correction|call|instruction|words|law)|per[[:space:]]+the[[:space:]]+owner|owner[[:space:]]+(said|asked|wants|requires|ruled|decided|supplies)|owner[[:space:]]+law'

# Process control and decision bookkeeping — gates, ledgers, closed lists.
HYG_PROCESS='do not reopen|do-not-reopen|closed for good|launch.?blocker|ship gate|gate does not pass|settled (by|on|verbatim)|is a governing document|governing document'

# Reference to a governing document from inside code.
HYG_DOCREF='[A-Za-z0-9_/-]+\.(md|mdx)([^A-Za-z0-9]|$)'

HYG_GOV_CI="$HYG_IMPERATIVE|$HYG_AUTHORITY|$HYG_PROCESS|$HYG_DOCREF"

# ----------------------------------------------------------- argument residue
# The record of a past disagreement. Near-zero information value, and it primes
# an agent's stance toward the user before it reads a line of code.
HYG_RESIDUE='owner[[:space:]]+(corrected|rejected|struck|overruled|flagged|caught|had to)|(stated|said|corrected|repeated|told)[[:space:]]+(it[[:space:]]+)?(twice|three times|3 times|for the [a-z]+ time)|(second|third|fourth|fifth|tenth|3rd|4th)[[:space:]]+time|was[[:space:]]+(rejected|superseded|reversed|overruled)|(he|she|they|the owner)[[:space:]]+had[[:space:]]+to|recurred[[:space:]]+across|cost[[:space:]]+(him|her|them|us)[[:space:]]+(a|his|her|their)[[:space:]]+day|re-?litigat|so[[:space:]]+it[[:space:]]+is[[:space:]]+not[[:space:]]+(proposed|raised|reopened)|(the[[:space:]]+)?(user|owner|client)[[:space:]]+(wanted|asked|preferred|rejected|refused|corrected|decided|agreed|insisted|objected|overruled)|(^|[^a-z])(i|we|the agent|the assistant|claude)[[:space:]]+(argued|refused|pushed back|convinced|disagreed)|we[[:space:]]+(eventually[[:space:]]+|finally[[:space:]]+)?(agreed|decided|settled|concluded)|(after|during|in)[[:space:]]+(the[[:space:]]+|this[[:space:]]+|our[[:space:]]+)?(argument|discussion|conversation|session|debate)'

# ---------------------------------------------------------- commit subjects
HYG_CONVENTIONAL='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-zA-Z0-9 ._/-]+\))?!?: .+'
HYG_COMMIT_BANNED='^(handoff|hand-off|wip|session|notes?|context|state|checkpoint|save|progress|misc|stuff)\b'

# ============================================================================
# helpers
# ============================================================================

# Honour .hygieneignore (one path-regex per line, # comments allowed).
hyg_extra_exempt() {
  local f="$1/.hygieneignore"
  if [ -f "$f" ]; then
    local pat
    pat="$(grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -v '^[[:space:]]*$' | paste -sd'|' -)"
    [ -n "$pat" ] && { printf '%s' "$pat"; return; }
  fi
  printf '%s' '__none__'
}

hyg_is_exempt() {
  local path="$1" extra="${2:-__none__}"
  printf '%s' "$path" | grep -Eq "$HYG_EXEMPT_PATHS" && return 0
  if [ "$extra" != '__none__' ]; then
    printf '%s' "$path" | grep -Eq "$extra" && return 0
  fi
  return 1
}

# Emit "lineno:text" for every comment line in a source file.
hyg_comment_lines() {
  local path="$1"
  if printf '%s' "$path" | grep -Eq "$HYG_HASH_EXT"; then
    grep -nE '^[[:space:]]*#' "$path" 2>/dev/null | grep -v '^[0-9]*:#!'
  else
    grep -nE '^[[:space:]]*(//|/\*|\*[^/]|\*$|<!--)|//[^"'"'"']*$' "$path" 2>/dev/null
  fi
}

# Reads lines on stdin, emits those matching governance under the correct case
# rules. Deduplicated, original order preserved by line number.
hyg_match_governance() {
  local buf; buf="$(cat)"
  [ -n "$buf" ] || return 0
  {
    printf '%s\n' "$buf" | grep -E  "$HYG_GOV_CS"
    printf '%s\n' "$buf" | grep -Ei "$HYG_GOV_CI"
  } 2>/dev/null | sort -t: -k1,1n -u
}

hyg_color() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    HYG_RED=$'\033[31m'; HYG_YEL=$'\033[33m'; HYG_DIM=$'\033[2m'
    HYG_BLD=$'\033[1m'; HYG_GRN=$'\033[32m'; HYG_OFF=$'\033[0m'
  else
    HYG_RED=''; HYG_YEL=''; HYG_DIM=''; HYG_BLD=''; HYG_GRN=''; HYG_OFF=''
  fi
}
