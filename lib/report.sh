#!/usr/bin/env bash
# report: structured output, finding identity, and baselines.
# Sourced by bin/scan after lib/patterns.sh, lib/references.sh, lib/rules.sh and
# lib/findings.sh.
# bash 3.2 compatible.
#
# Three things live here, and nothing else writes to disk:
#
#   * escaping. Every string that reaches a JSON or SARIF document goes through
#     one escaper, so a quote, a backslash or a control byte in a filename or a
#     matched line cannot produce a malformed document.
#   * fingerprints. A finding needs an identity that survives a file move and a
#     shifted line, so that a baseline suppresses what you have already read
#     rather than what happened to move.
#   * the baseline file format. Written only when asked, and never inferred.
#
# The renderers take the rows produced by hyg_rows on stdin and print a whole
# document on stdout. They do not write files.

TAB="$(printf '\t')"
US="$(printf '\037')"

# The version of the JSON document and of the baseline file. They move
# independently of the tool version, and a consumer can refuse a document it
# does not understand.
HYG_JSON_SCHEMA=1
HYG_BASELINE_SCHEMA=1
HYG_BASELINE_HEADER="# hygiene baseline: schema $HYG_BASELINE_SCHEMA"

# ------------------------------------------------------------------ escaping

# JSON cannot carry a raw control byte or an unescaped quote. Bytes that JSON
# has no short escape for are removed rather than encoded: a comment line is
# text a human wrote, and losing a stray vertical tab is better than emitting a
# document a parser rejects. Tab, newline and carriage return are kept, escaped.
hyg_json_escape() {
  local s
  s="$(printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177')"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//"$TAB"/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

hyg_json_string() { printf '"%s"' "$(hyg_json_escape "$1")"; }

hyg_json_string_or_null() {
  if [ -n "${1:-}" ]; then hyg_json_string "$1"; else printf 'null'; fi
}

hyg_json_number_or_null() {
  case "${1:-}" in
    ''|*[!0-9]*) printf 'null' ;;
    *) printf '%s' "$1" ;;
  esac
}

# A SARIF artifactLocation.uri is a URI reference, so the characters that are
# illegal in a URI path have to be percent-encoded. Non-ASCII bytes are passed
# through as UTF-8, which is what code scanning expects.
hyg_uri_encode() {
  local s="$1"
  s="${s//%/%25}"
  s="${s// /%20}"
  s="${s//#/%23}"
  s="${s//\?/%3F}"
  s="${s//\"/%22}"
  s="${s//</%3C}"
  s="${s//>/%3E}"
  s="${s//\`/%60}"
  s="${s//\{/%7B}"
  s="${s//\}/%7D}"
  s="${s//|/%7C}"
  s="${s//\\/%5C}"
  s="${s//^/%5E}"
  s="${s//\[/%5B}"
  s="${s//\]/%5D}"
  printf '%s' "$s"
}

# Cut a long line for a message or a snippet, and say that it was cut.
hyg_truncate() {
  local s="$1" n="${2:-200}"
  if [ "${#s}" -gt "$n" ]; then printf '%s…' "${s%"${s:$n}"}"; else printf '%s' "$s"; fi
}

# -------------------------------------------------------------- fingerprints

# The text of a finding, reduced to what does not change when the file is
# reformatted or moved: no leading and trailing space, no comment marker, and
# single spaces between words.
hyg_normalize_text() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  case "$s" in
    '//'*)   s="${s#//}" ;;
    '/*'*)   s="${s#/*}" ;;
    '<!--'*) s="${s#<!--}" ;;
    '*'*)    s="${s#\*}" ;;
    '#'*)    s="${s#\#}" ;;
  esac
  s="${s# }"
  printf '%s' "$s" | LC_ALL=C tr -s '[:space:]' ' '
}

hyg_cksum() { printf '%s' "$1" | cksum | awk '{print $1}'; }

# rule:m:<checksum of the line's text>   a finding attached to a line of text
# rule:p:<checksum of the path>          a finding attached to a whole file
#
# The path appears only in the second form. A file-level condition is a property
# of the file, so the file is what identifies it, and a comment that moves
# between files keeps its identity.
hyg_fingerprint() {
  local rule="$1" file="$2" line="$3" match="$4" evidence="$5" text
  if [ -z "$line" ]; then
    printf '%s:p:%s' "$rule" "$(hyg_cksum "$file")"
    return
  fi
  text="$match"; [ -n "$text" ] || text="$evidence"
  printf '%s:m:%s' "$rule" "$(hyg_cksum "$(hyg_normalize_text "$text")")"
}

# ------------------------------------------------------------------- records

# Detector records in, report rows out. A row is the seven detector fields plus
# the fingerprint, joined with the unit separator: a tab is IFS whitespace and
# splitting on it silently collapses the empty line and match fields that a
# file-level finding carries. Evidence stays last, so a tab inside a matched
# line survives being read back.
hyg_rows() {
  local rec rule catg sev file line match rest
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    rule="${rec%%"$TAB"*}";  rest="${rec#*"$TAB"}"
    catg="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"
    sev="${rest%%"$TAB"*}";  rest="${rest#*"$TAB"}"
    file="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"
    line="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"
    match="${rest%%"$TAB"*}"; rest="${rest#*"$TAB"}"
    printf '%s\n' "$rule$US$catg$US$sev$US$file$US$line$US$match$US$(hyg_fingerprint "$rule" "$file" "$line" "$match" "$rest")$US$rest"
  done
}

# ------------------------------------------------------------------- JSON

# hyg_render_json <root-label> <baseline-label> <suppressed>  < rows
hyg_render_json() {
  local root="$1" baseline_label="$2" suppressed="${3:-0}" body="" rec rule catg sev file line match fp ev
  local n=0 warn=0 info=0 first=1
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    IFS="$US" read -r rule catg sev file line match fp ev <<EOF
$rec
EOF
    [ -n "$rule" ] || continue
    n=$((n + 1))
    if [ "$sev" = "warning" ]; then warn=$((warn + 1)); else info=$((info + 1)); fi
    if [ "$first" = 1 ]; then first=0; else body="$body,"; fi
    body="$body
    {
      \"ruleId\": $(hyg_json_string "$rule"),
      \"category\": $(hyg_json_string "$catg"),
      \"severity\": $(hyg_json_string "$sev"),
      \"file\": $(hyg_json_string "$file"),
      \"line\": $(hyg_json_number_or_null "$line"),
      \"match\": $(hyg_json_string_or_null "$match"),
      \"fingerprint\": $(hyg_json_string "$fp"),
      \"message\": $(hyg_json_string "$(hyg_rule_message "$rule")"),
      \"remediation\": $(hyg_json_string "$(hyg_rule_remediation "$rule")"),
      \"evidence\": $(hyg_json_string "$ev")
    }"
  done

  printf '{\n'
  printf '  "schemaVersion": %s,\n' "$HYG_JSON_SCHEMA"
  printf '  "tool": { "name": "hygiene", "version": %s },\n' "$(hyg_json_string "$HYG_VERSION")"
  printf '  "root": %s,\n' "$(hyg_json_string "$root")"
  if [ -n "$baseline_label" ]; then
    printf '  "baseline": { "path": %s, "suppressed": %s, "schemaVersion": %s },\n' \
      "$(hyg_json_string "$baseline_label")" "$suppressed" "$HYG_BASELINE_SCHEMA"
  fi
  printf '  "summary": { "findings": %s, "warning": %s, "info": %s },\n' "$n" "$warn" "$info"
  printf '  "findings": ['
  [ -n "$body" ] && printf '%s\n  ' "$body"
  printf ']\n}\n'
}

# ------------------------------------------------------------------- SARIF

# The rules that produced a result, in registry order, so that ruleIndex is
# stable for a given set of results.
hyg_sarif_level() {
  case "$1" in
    warning) printf 'warning' ;;
    *) printf 'note' ;;
  esac
}

# hyg_render_sarif <root-label> <baseline-label> <suppressed>  < rows
hyg_render_sarif() {
  local root="$1" baseline_label="$2" suppressed="${3:-0}" rows rules rec rule catg sev file line match fp ev
  local idx body res first rfirst
  rows="$(cat)"
  rules="$(printf '%s\n' "$rows" | sed "s/$US.*//" | grep -v '^$' | LC_ALL=C sort -u)"

  body=""; first=1
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    if [ "$first" = 1 ]; then first=0; else body="$body,"; fi
    body="$body
            {
              \"id\": $(hyg_json_string "$r"),
              \"name\": $(hyg_json_string "$(hyg_rule_name "$r")"),
              \"shortDescription\": { \"text\": $(hyg_json_string "$(hyg_rule_title "$r")") },
              \"fullDescription\": { \"text\": $(hyg_json_string "$(hyg_rule_message "$r")") },
              \"helpUri\": \"https://github.com/nouvic/hygiene/blob/main/docs/rules.md\",
              \"help\": { \"text\": $(hyg_json_string "$(hyg_rule_help "$r")") },
              \"defaultConfiguration\": { \"level\": \"$(hyg_sarif_level "$(hyg_rule_severity "$r")")\" }
            }"
  done <<EOF
$rules
EOF

  res=""; rfirst=1
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    IFS="$US" read -r rule catg sev file line match fp ev <<EOF
$rec
EOF
    [ -n "$rule" ] || continue
    if [ "$rfirst" = 1 ]; then rfirst=0; else res="$res,"; fi
    idx="$(printf '%s\n' "$rules" | grep -nxF "$rule" | head -1 | cut -d: -f1)"
    res="$res
    {
      \"ruleId\": $(hyg_json_string "$rule"),
      \"ruleIndex\": $(( ${idx:-1} - 1 )),
      \"level\": \"$(hyg_sarif_level "$sev")\",
      \"message\": { \"text\": $(hyg_json_string "$(hyg_truncate "$ev" 200)") },
      \"locations\": [
        {
          \"physicalLocation\": {
            \"artifactLocation\": { \"uri\": $(hyg_json_string "$(hyg_uri_encode "$file")") }$(hyg_sarif_region "$line" "$ev")
          }
        }
      ],
      \"partialFingerprints\": { \"hygieneFingerprint/v1\": $(hyg_json_string "$fp") },
      \"properties\": { \"category\": $(hyg_json_string "$catg") }
    }"
  done <<EOF
$rows
EOF

  printf '{\n'
  printf '  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",\n'
  printf '  "version": "2.1.0",\n'
  printf '  "runs": [\n    {\n'
  printf '      "tool": {\n        "driver": {\n'
  printf '          "name": "hygiene",\n'
  printf '          "version": %s,\n' "$(hyg_json_string "$HYG_VERSION")"
  printf '          "informationUri": "https://github.com/nouvic/hygiene",\n'
  printf '          "rules": ['
  [ -n "$body" ] && printf '%s\n          ' "$body"
  printf ']\n        }\n      },\n'
  if [ -n "$baseline_label" ]; then
    printf '      "properties": { "hygieneBaseline": { "path": %s, "suppressed": %s, "schemaVersion": %s } },\n' \
      "$(hyg_json_string "$baseline_label")" "$suppressed" "$HYG_BASELINE_SCHEMA"
  fi
  printf '      "results": ['
  [ -n "$res" ] && printf '%s\n    ' "$res"
  printf ']\n    }\n  ]\n}\n'
}

# The region is what makes a GitHub code location usable. A finding with no line
# has nothing to point at, so it carries the file and no region rather than a
# line number that would be wrong.
hyg_sarif_region() {
  local line="$1" ev="$2"
  case "${line:-}" in
    ''|*[!0-9]*) printf '' ;;
    *) printf ',\n            "region": { "startLine": %s, "snippet": { "text": %s } }' \
         "$line" "$(hyg_json_string "$(hyg_truncate "$ev" 200)")" ;;
  esac
}

# ------------------------------------------------------------------ baselines

# Write the baseline for the rows on stdin. Only ever called for an explicit
# --write-baseline: nothing else in the scanner writes to disk.
hyg_baseline_write() {
  local path="$1" rec rule catg sev file line match fp ev
  mkdir -p "$(dirname "$path")" 2>/dev/null
  {
    printf '%s\n' "$HYG_BASELINE_HEADER"
    printf '%s\n' "# Generated by hygiene scan --write-baseline. One row per finding"
    printf '%s\n' "# that existed when it was written. A finding is matched by fingerprint,"
    printf '%s\n' "# which is the rule plus the text of the matched line, or the path for a"
    printf '%s\n' "# finding that belongs to a whole file. See docs/baselines.md."
    printf '# rule\tfingerprint\tfile\n'
    while IFS= read -r rec; do
      [ -n "$rec" ] || continue
      IFS="$US" read -r rule catg sev file line match fp ev <<EOF
$rec
EOF
      [ -n "$rule" ] || continue
      printf '%s\t%s\t%s\n' "$rule" "$fp" "$file"
    done
  } > "$path"
}

# Read a baseline and print one fingerprint per line. Refuses a file it cannot
# recognize, and says which schema it found: treating an unreadable baseline as
# empty would report every known finding as new.
hyg_baseline_read() {
  local path="$1" head
  [ -f "$path" ] || { printf 'scan: no baseline at %s\n' "$path" >&2; return 2; }
  head="$(sed -n '1p' "$path")"
  case "$head" in
    "$HYG_BASELINE_HEADER") ;;
    '# hygiene baseline: schema '*)
      printf 'scan: %s is schema %s; this is schema %s\n' \
        "$path" "${head##*schema }" "$HYG_BASELINE_SCHEMA" >&2
      return 2 ;;
    *)
      printf 'scan: %s is not a hygiene baseline (no schema line on line 1)\n' "$path" >&2
      return 2 ;;
  esac
  awk -F'\t' '/^#/ { next } NF >= 2 && $2 != "" { print $2 }' "$path"
}
