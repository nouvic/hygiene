#!/usr/bin/env bash
# exposure: the loading surface of each file a finding sits in, for one named
# agent tool. Sourced by bin/exposure after lib/patterns.sh, lib/rules.sh,
# lib/findings.sh and lib/report.sh. bash 3.2 compatible.
#
# The path patterns, the surfaces, the reasons and the limitations are data, in
# two tables beside this file. This file is the interpreter: it matches a path
# against a row and, for the families whose answer depends on the file rather
# than on the path, reads that file's frontmatter.
#
# Four surfaces. automatic is one the tool documents reading without a per-run
# choice. configured is one the repository itself scopes, by a glob, a path
# pattern or a directory. referenced is a file named by an import inside a file
# on one of the first two: reachable, not loaded. unknown is everything else,
# and it is the answer rather than a guess, because a scanner can see a
# repository and cannot see a context.
#
# Nothing here reads a settings file or makes a network request. A classification
# is computed from a path and, for the frontmatter families, from the metadata the
# file carries.

[ -n "${HYG_HOME:-}" ] || HYG_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYG_SURFACES="$HYG_HOME/lib/exposure-surfaces.tsv"
HYG_LIMITS="$HYG_HOME/lib/exposure-limits.tsv"

HYG_EXPOSURE_TOOLS='claude-code
cursor
codex
copilot
generic'

hyg_exposure_tool_known() { printf '%s\n' "$HYG_EXPOSURE_TOOLS" | grep -qx "$1"; }

# A table without its comments and blank lines. Both are read once for the whole
# run, because every file in scope is looked up against the surface table.
hyg_table() {
  if [ -z "${HYG_TABLE_CACHE:-}" ]; then
    HYG_TABLE_CACHE="$(grep -v '^[[:space:]]*#' "$HYG_SURFACES" 2>/dev/null | grep -v '^[[:space:]]*$')"
  fi
  printf '%s\n' "$HYG_TABLE_CACHE"
}

# A table pattern is a pipe-separated list of case globs. An expansion in a case
# pattern does not split on the separator, so the alternatives are walked here
# with globbing off and the separator as IFS.
hyg_path_matches() {
  local p="$1" pat="$2" alt
  set -f
  local IFS='|'
  for alt in $pat; do
    case "$p" in $alt) set +f; return 0 ;; esac
  done
  set +f
  return 1
}

hyg_limits_table() {
  grep -v '^[[:space:]]*#' "$HYG_LIMITS" 2>/dev/null | grep -v '^[[:space:]]*$'
}

# ------------------------------------------------------------------ frontmatter

# none | ok | unterminated. A file whose first line is not a delimiter has no
# frontmatter; one that opens a block and closes nothing does not parse. The two
# are kept apart because the tools document different fallbacks.
hyg_frontmatter_state() {
  local f="$1" first
  first="$(sed -n '1p' "$f" 2>/dev/null | sed 's/[[:space:]]*$//')"
  [ "$first" = '---' ] || { printf 'none\n'; return; }
  awk 'NR > 1 && /^---[[:space:]]*$/ { ok = 1; exit } END { print (ok ? "ok" : "unterminated") }' "$f"
}

hyg_frontmatter_block() {
  awk 'NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
       NR == 1 { next }
       /^---[[:space:]]*$/ { exit }
       { print }' "$1" 2>/dev/null
}

hyg_frontmatter_has() {
  hyg_frontmatter_block "$1" | grep -qE "^[[:space:]]*$2[[:space:]]*:"
}

# ------------------------------------------------------------------- path work

# dir + target with . and .. resolved, for an import written relative to the file
# holding it. An absolute target, or one starting with ~, is returned as it
# stands: it resolves outside the repository, and the caller reports that.
hyg_join_path() {
  local dir="$1" t="$2" out="" seg path
  case "$t" in
    /*|'~'*) printf '%s\n' "$t"; return ;;
  esac
  if [ -n "$dir" ]; then path="$dir/$t"; else path="$t"; fi
  set -f
  local IFS='/'
  for seg in $path; do
    case "$seg" in
      ''|.) ;;
      ..) case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *)  out="${out:+$out/}$seg" ;;
    esac
  done
  set +f
  printf '%s\n' "$out"
}

# The directory an entry-level file governs. Empty means the repository root,
# which is the difference between a root surface and a nested one.
hyg_dir_of() { case "$1" in */*) printf '%s\n' "${1%/*}" ;; *) printf '' ;; esac; }

# Whether a directory holds any of the named files, where the names arrive as a
# pipe-separated list from the table. Only literals are tested: a name carrying
# a wildcard is skipped rather than expanded, because a list of displacing
# instruction files is a list of files and not a pattern.
hyg_dir_holds_any() {
  local root="$1" dir="$2" names="$3" name prefix=""
  [ -n "$names" ] || return 1
  [ -n "$dir" ] && prefix="$dir/"
  local IFS='|'
  for name in $names; do
    case "$name" in *'*'*|*'?'*) continue ;; esac
    [ -f "$root/$prefix$name" ] && return 0
  done
  return 1
}

# --------------------------------------------------------------- import graph

# The @path tokens in a memory file, one per line. Fenced blocks and inline code
# spans come out first: a path inside backticks is text rather than an import,
# and a parser that missed that would report a file named in an example as one
# that loads.
hyg_imports_in() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    { print }
  ' "$1" 2>/dev/null | sed 's/`[^`]*`//g' \
    | grep -oE '@[^ 	]+' 2>/dev/null | sed 's/^@//' | sed -E 's/[.,;:)]+$//'
}

# The files the table marks as carrying an import. The syntax is documented for
# some of them and not for a rules directory, and a file that cannot carry one is
# never in the closure.
hyg_memory_files() {
  local root="$1" t pat fam surf why param imp
  while IFS="$TAB" read -r t pat fam surf why param imp; do
    [ "$t" = claude-code ] || continue
    [ "$imp" = yes ] || continue
    case "$pat" in *'*'*|*'?'*|*'|'*) continue ;; esac
    [ -f "$root/$pat" ] && printf '%s\n' "$pat"
  done <<EOF
$(hyg_table)
EOF
}

# Every repository path reachable from a memory file by documented imports,
# following them to the documented maximum depth of four hops. Printed as
# path <TAB> the file that named it.
hyg_import_closure() {
  local root="$1" file dir t abs frontier next hops
  frontier="$(hyg_memory_files "$root")"
  hops=0
  while [ -n "$frontier" ] && [ "$hops" -lt 4 ]; do
    hops=$((hops + 1)); next=""
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      [ -f "$root/$file" ] || continue
      dir="$(hyg_dir_of "$file")"
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        case "$t" in
          /*|'~'*) printf '%s\t%s\n' "$t" "$file"; continue ;;
        esac
        abs="$(hyg_join_path "$dir" "$t")"
        [ -n "$abs" ] || continue
        printf '%s\t%s\n' "$abs" "$file"
        case "$abs" in *'*'*|*'?'*) continue ;; esac
        [ -f "$root/$abs" ] && next="$next$abs
"
      done <<EOF
$(hyg_imports_in "$root/$file")
EOF
    done <<EOF
$frontier
EOF
    frontier="$next"
  done
}

# ------------------------------------------------------------------ surfaces

# hyg_surface_of <root> <tool> <path> prints "surface<TAB>why". The first table
# row for the tool whose pattern matches wins; a path that matches nothing the
# tool documents is unknown.
hyg_surface_of() {
  local root="$1" tool="$2" p="$3" t pat fam surf why param imp
  while IFS="$TAB" read -r t pat fam surf why param imp; do
    [ "$t" = "$tool" ] || continue
    hyg_path_matches "$p" "$pat" || continue
    hyg_surface_family "$root" "$tool" "$p" "$fam" "$surf" "$why" "$param"
    return
  done <<EOF
$(hyg_table)
EOF
  printf 'unknown\t%s\n' "no documented loading surface for $tool"
}

hyg_surface_family() {
  local root="$1" tool="$2" p="$3" fam="$4" surf="$5" why="$6" param="$7"
  case "$fam" in
    plain)               printf '%s\t%s\n' "$surf" "$why" ;;
    agents-file)         hyg_surface_agents_file "$root" "$p" "$surf" "$why" "$param" ;;
    alt-instruction)     hyg_surface_alt_instruction "$root" "$surf" "$why" "$param" ;;
    claude-rule)         hyg_surface_claude_rule "$root" "$p" ;;
    cursor-rule)         hyg_surface_cursor_rule "$root" "$p" ;;
    copilot-instruction) hyg_surface_copilot_instruction "$root" "$p" ;;
    *)                   printf 'unknown\t%s\n' "no documented loading surface for $tool" ;;
  esac
}

# An instruction file a sibling can displace. The displacers come from the
# table, relative to the directory this file governs.
hyg_surface_agents_file() {
  local root="$1" p="$2" surf="$3" why="$4" param="$5" dir
  dir="$(hyg_dir_of "$p")"
  if hyg_dir_holds_any "$root" "$dir" "$param"; then
    printf 'unknown\t%s\n' "read only where no displacing instruction file applies, and one applies here"
    return
  fi
  printf '%s\t%s\n' "$surf" "$why"
}

# A root instruction file that the presence of another file demotes.
hyg_surface_alt_instruction() {
  local root="$1" surf="$2" why="$3" param="$4" base
  [ -n "$param" ] || { printf '%s\t%s\n' "$surf" "$why"; return; }
  while IFS= read -r base; do
    [ -n "$base" ] || continue
    if hyg_path_matches "$base" "$param"; then
      printf 'unknown\t%s\n' "documented as an alternative to the agent-instruction file, and this repository has one"
      return
    fi
  done <<EOF
$(hyg_list_files "$root" | awk -F/ '{ print $NF }' | sort -u)
EOF
  printf '%s\t%s\n' "$surf" "$why"
}

# A rules file: scoped by a path pattern, scoped by its directory, or unscoped.
# An unreadable block is reported as unscoped, which is the fallback the tool
# documents for frontmatter it cannot parse.
hyg_surface_claude_rule() {
  local root="$1" p="$2" rest dir st
  rest="${p%/*}"
  case "$rest" in
    */.claude/rules) dir="${rest%/.claude/rules}" ;;
    .claude/rules)   dir="" ;;
    *)               dir="$rest" ;;
  esac
  st="$(hyg_frontmatter_state "$root/$p")"
  case "$st" in
    ok)
      if hyg_frontmatter_has "$root/$p" paths; then
        printf 'configured\t%s\n' "rule scoped by a paths pattern; loads when a matching file is read"
      elif [ -z "$dir" ]; then
        printf 'automatic\t%s\n' "rule with no paths field; loads at launch with the project instructions"
      else
        printf 'configured\t%s\n' "nested rules directory; loads on demand"
      fi ;;
    none)
      if [ -z "$dir" ]; then
        printf 'automatic\t%s\n' "rule with no frontmatter; loads at launch"
      else
        printf 'configured\t%s\n' "nested rules directory; loads on demand"
      fi ;;
    *)
      printf 'automatic\t%s\n' "frontmatter does not close, and the documented fallback loads the rule unscoped" ;;
  esac
}

# A rule file: the activation modes the rules reference documents, told apart by
# the frontmatter the rule carries.
hyg_surface_cursor_rule() {
  local root="$1" p="$2" st
  st="$(hyg_frontmatter_state "$root/$p")"
  if [ "$st" != ok ]; then
    printf 'unknown\t%s\n' "frontmatter is $st, and no fallback is documented for a rule that cannot be read"
    return
  fi
  if printf '%s\n' "$(hyg_frontmatter_block "$root/$p")" | grep -qE '^[[:space:]]*alwaysApply[[:space:]]*:[[:space:]]*true'; then
    printf 'automatic\t%s\n' "alwaysApply is true; included in every session"
  elif hyg_frontmatter_has "$root/$p" globs; then
    printf 'configured\t%s\n' "auto-attached when a matching file is in context"
  elif hyg_frontmatter_has "$root/$p" description; then
    printf 'unknown\t%s\n' "the agent decides from the description whether to pull the rule in"
  else
    printf 'unknown\t%s\n' "documented as included only when the rule is mentioned in chat"
  fi
}

# A path-specific instruction file, which the documentation scopes by a pattern
# in its frontmatter and reads for the cloud agent and for code review.
hyg_surface_copilot_instruction() {
  local root="$1" p="$2" st
  st="$(hyg_frontmatter_state "$root/$p")"
  if [ "$st" != ok ]; then
    printf 'unknown\t%s\n' "frontmatter is $st, and a pattern in it is what scopes this file"
    return
  fi
  if hyg_frontmatter_has "$root/$p" applyTo; then
    printf 'configured\t%s\n' "scoped by an applyTo pattern; path-specific instructions reach the cloud agent and code review"
  else
    printf 'unknown\t%s\n' "no applyTo pattern, and path-specific instructions are documented to require one"
  fi
}

# --------------------------------------------------------------- the report

# The verdict for a finding, from the surface its file sits on and whether a
# documented rule leaves that file's loading open. Three words, and none of them
# is a claim about what a running agent did:
#
#   likely exposed   documentation says a session of this tool loads this path
#   loading unknown  something documented reaches it, and whether it loads is
#                    not established here
#   stored           nothing documented in this repository reaches it
#
# The second case covers a loaded file that names this one, and a rule the
# documentation describes that settles the answer only by reading the file: a
# rule the agent decides whether to pull in, a file displaced by a sibling,
# frontmatter that will not parse. Saying a finding there is stored would read as
# "nothing reaches it", which is not what the documentation says. A path the
# documentation names only to exclude, or does not name at all, is the third.
hyg_exposure_verdict() {
  case "$1" in
    automatic|configured) printf 'likely exposed\n' ;;
    referenced)           printf 'loading unknown\n' ;;
    *) case "$2" in
         1) printf 'loading unknown\n' ;;
         *) printf 'stored\n' ;;
       esac ;;
  esac
}

# The file that names a path through a documented import, if one does. The
# closure is a path-and-naming-file pair per line, and the first naming file
# wins, which is the order the closure was walked in.
hyg_referenced_by() {
  local referenced="$1" p="$2"
  [ -n "$referenced" ] || return 0
  printf '%s\n' "$referenced" | awk -F"$TAB" -v p="$p" '$1 == p { print $2; exit }'
}

# What the surface table says about a path, as two flags on one line:
#
#   <about> <rule>
#
# about is 1 when some row is about the path at all, which is what makes a file
# worth showing: a path with a row and no surface is a different answer from a
# path no tool documents, and a reader should see it either way. rule is 1 when
# the matching row describes a rule that decides for the path rather than
# stating its surface, which is what leaves a finding's loading open. A plain
# row is not such a rule: it states a surface, or names the path only to exclude
# it, and the second of those settles the question against loading.
hyg_path_rows() {
  local tool="$1" p="$2" t pat fam surf why param imp rule=0
  while IFS="$TAB" read -r t pat fam surf why param imp; do
    [ "$t" = "$tool" ] || continue
    hyg_path_matches "$p" "$pat" || continue
    [ "$fam" != plain ] && rule=1
    printf '1 %s\n' "$rule"
    return 0
  done <<EOF
$(hyg_table)
EOF
  printf '0 0\n'
}

# One map row: path, surface, whether the row is worth showing, whether a rule
# leaves the answer open, and the reason. A plain source file with no documented
# surface is counted and not listed, or the report would be the file listing
# with a column bolted on. A file a row is about is listed even when the answer
# for it is unknown.
hyg_surface_of_file() {
  local root="$1" tool="$2" rel="$3" referenced="$4" s surf why by listed=0 open=0 doc rule
  s="$(hyg_surface_of "$root" "$tool" "$rel")"
  surf="${s%%"$TAB"*}"; why="${s#*"$TAB"}"
  if [ "$surf" != unknown ]; then
    listed=1; open=1
  else
    by="$(hyg_referenced_by "$referenced" "$rel")"
    if [ -n "$by" ]; then
      surf=referenced; why="named by an import in $by"; listed=1; open=1
    else
      read -r doc rule <<EOF
$(hyg_path_rows "$tool" "$rel")
EOF
      [ "$doc" = 1 ] && listed=1
      [ "$rule" = 1 ] && open=1
    fi
  fi
  printf '%s\n' "$rel$US$surf$US$listed$US$open$US$why"
}

# Every file in scope with the surface it sits on, sorted by path. One map, made
# once, read by both the report and the per-finding lookup, so a file and a
# finding in it cannot disagree.
hyg_exposure_surfaces() {
  local root="$1" tool="$2" referenced="$3" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$root/$rel" ] || continue
    hyg_surface_of_file "$root" "$tool" "$rel" "$referenced"
  done <<EOF
$(hyg_list_files "$root" | LC_ALL=C sort)
EOF
}

hyg_surface_lookup() {
  local map="$1" p="$2" line
  [ -n "$map" ] || return 0
  line="$(printf '%s\n' "$map" | awk -F"$US" -v p="$p" '$1 == p { print; exit }')"
  [ -n "$line" ] && printf '%s\n' "$line"
}

# The findings, with the surface and the verdict for each. One row per finding,
# in the row format lib/report.sh defines, with three fields appended and the
# reason last so it absorbs a stray separator. A history finding can name a file
# the working tree no longer holds, and that is said rather than guessed at.
hyg_exposure_rows() {
  local map="$1" rec rule catg sev file line match fp ev s surf why open
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    IFS="$US" read -r rule catg sev file line match fp ev <<EOF
$rec
EOF
    [ -n "$rule" ] || continue
    s="$(hyg_surface_lookup "$map" "$file")"
    # The map row carries whether a documented rule leaves loading open for this
    # path, which is what separates a file the documentation is about but cannot
    # settle from one it names only to exclude. A finding whose file is gone from
    # the tree has no row at all.
    open=0
    if [ -n "$s" ]; then
      surf="${s#*"$US"}"; surf="${surf%%"$US"*}"
      open="$(printf '%s' "$s" | awk -F"$US" '{ print $4 }')"
      why="${s##*"$US"}"
    else
      surf=unknown
      why="the file this finding refers to is not in the working tree"
    fi
    printf '%s\n' "$rec$US$surf$US$(hyg_exposure_verdict "$surf" "$open")$US$why"
  done
}

# Whether a limitation is true of this repository.
hyg_limit_applies() {
  local root="$1" check="$2" pat="$3" rel
  case "$check" in
    present)
      [ -n "$pat" ] || return 1
      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        hyg_path_matches "$rel" "$pat" && return 0
      done <<EOF
$(hyg_list_files "$root")
EOF
      return 1 ;;
    *) return 0 ;;
  esac
}

# The limitations this repository makes true, from the table, then the two that
# hold for every run.
hyg_exposure_limits() {
  local root="$1" tool="$2" t check pat text
  while IFS="$TAB" read -r t check pat text; do
    [ -n "$t" ] || continue
    [ "$t" = "$tool" ] || continue
    hyg_limit_applies "$root" "$check" "$pat" || continue
    printf '%s\n' "$text"
  done <<EOF
$(hyg_limits_table)
EOF
  if [ "$tool" != claude-code ]; then
    printf '%s\n' "Only Claude Code documents an import syntax, so no file is classified as referenced under $tool."
  fi
  printf '%s\n' "No tool's loading is observed. Every classification above is a property of a path in this repository, not evidence that an agent read it."
}

# ---------------------------------------------------------------- rendering

# hyg_render_exposure_text <root> <tool> <surfaces-tsv> <rows>
hyg_render_exposure_text() {
  local root="$1" tool="$2" surfaces="$3" rows="$4"
  local rule catg sev file line match fp ev surf verdict why
  local n=0 na=0 ncfg=0 nr=0 nu=0 le=0 lu=0 st=0 sfile surffile sshow sway

  while IFS="$US" read -r sfile surffile sshow sopen sway; do
    [ -n "$sfile" ] || continue
    case "$surffile" in
      automatic)  na=$((na + 1)) ;;
      configured) ncfg=$((ncfg + 1)) ;;
      referenced) nr=$((nr + 1)) ;;
      unknown)    nu=$((nu + 1)) ;;
    esac
  done <<EOF
$surfaces
EOF

  printf '\n  agent context exposure · %s · %s\n' "$tool" "$root"
  printf '  %s\n\n' "────────────────────────────────────────────────"

  printf '  documented surfaces\n'
  hyg_count() { [ "$1" = 1 ] && printf '1 file' || printf '%s files' "$1"; }
  printf '    %-11s %6s\n' automatic  "$(hyg_count "$na")"
  printf '    %-11s %6s\n' configured "$(hyg_count "$ncfg")"
  printf '    %-11s %6s\n' referenced "$(hyg_count "$nr")"
  printf '    %-11s %6s   no documented surface\n\n' unknown "$(hyg_count "$nu")"

  while IFS="$US" read -r sfile surffile sshow sopen sway; do
    [ -n "$sfile" ] || continue
    [ "$sshow" = 1 ] || continue
    # The surface name explains itself for automatic and configured. Unknown and
    # referenced need the reason beside them or the reader cannot tell a
    # displaced file from a dangling import.
    case "$surffile" in
      unknown|referenced) printf '    %-11s %-52s %s\n' "$surffile" "$sfile" "$sway" ;;
      *)                   printf '    %-11s %s\n' "$surffile" "$sfile" ;;
    esac
  done <<EOF
$surfaces
EOF

  printf '\n  findings\n'
  while IFS="$US" read -r rule catg sev file line match fp ev surf verdict why; do
    [ -n "$rule" ] || continue
    n=$((n + 1))
    case "$verdict" in
      'likely exposed')  le=$((le + 1)) ;;
      'loading unknown') lu=$((lu + 1)) ;;
      *)                 st=$((st + 1)) ;;
    esac
  done <<EOF
$rows
EOF
  printf '    %-16s %3s\n' 'likely exposed'  "$le"
  printf '    %-16s %3s\n' 'loading unknown' "$lu"
  printf '    %-16s %3s\n\n' 'stored' "$st"

  if [ "$n" -gt 0 ]; then
    while IFS="$US" read -r rule catg sev file line match fp ev surf verdict why; do
      [ -n "$rule" ] || continue
      if [ -n "$line" ]; then printf '    %s:%s\n' "$file" "$line"
      else printf '    %s\n' "$file"; fi
      printf '      %s  %s  (%s)\n' "$rule" "$verdict" "$surf"
      printf '      %s\n' "$why"
    done <<EOF
$rows
EOF
    printf '\n'
  else
    printf '    nothing stored to report\n\n'
  fi

  printf '  limits\n'
  hyg_exposure_limits "$root" "$tool" | sed 's/^/    /'
  printf '\n'
  printf '  A finding is a condition stored in the repository. Nothing here observed an\n'
  printf '  agent, a session, or a model context.\n\n'
}

# hyg_render_exposure_json <root> <tool>   < rows
# hyg_render_exposure_json <root> <tool> <surfaces>   < rows
hyg_render_exposure_json() {
  local root="$1" tool="$2" surfaces="$3"
  local rec rule catg sev file line match fp ev surf verdict why
  local body="" first=1 n=0 le=0 lu=0 st=0 firstl=1 lim sfile ssurf sshow sopen sway
  local na=0 ncfg=0 nr=0 nu=0 files="" firstf=1
  while IFS="$US" read -r rule catg sev file line match fp ev surf verdict why; do
    [ -n "$rule" ] || continue
    n=$((n + 1))
    case "$verdict" in
      'likely exposed')  le=$((le + 1)) ;;
      'loading unknown') lu=$((lu + 1)) ;;
      *)                 st=$((st + 1)) ;;
    esac
    if [ "$first" = 1 ]; then first=0; else body="$body,"; fi
    body="$body
    {
      \"ruleId\": $(hyg_json_string "$rule"),
      \"category\": $(hyg_json_string "$catg"),
      \"severity\": $(hyg_json_string "$sev"),
      \"file\": $(hyg_json_string "$file"),
      \"line\": $(hyg_json_number_or_null "$line"),
      \"surface\": $(hyg_json_string "$surf"),
      \"exposure\": $(hyg_json_string "$verdict"),
      \"surfaceReason\": $(hyg_json_string "$why"),
      \"fingerprint\": $(hyg_json_string "$fp"),
      \"message\": $(hyg_json_string "$(hyg_rule_message "$rule")"),
      \"evidence\": $(hyg_json_string "$ev")
    }"
  done

  printf '{\n'
  printf '  "schemaVersion": %s,\n' "$HYG_JSON_SCHEMA"
  printf '  "tool": { "name": "hygiene", "version": %s },\n' "$(hyg_json_string "$HYG_VERSION")"
  printf '  "root": %s,\n' "$(hyg_json_string "$root")"
  printf '  "agentTool": %s,\n' "$(hyg_json_string "$tool")"
  printf '  "summary": { "findings": %s, "likelyExposed": %s, "loadingUnknown": %s, "stored": %s },\n' \
    "$n" "$le" "$lu" "$st"
  while IFS="$US" read -r sfile ssurf sshow sopen sway; do
    [ -n "$sfile" ] || continue
    case "$ssurf" in
      automatic)  na=$((na + 1)) ;;
      configured) ncfg=$((ncfg + 1)) ;;
      referenced) nr=$((nr + 1)) ;;
      *)          nu=$((nu + 1)) ;;
    esac
    [ "$sshow" = 1 ] || continue
    if [ "$firstf" = 1 ]; then firstf=0; else files="$files,"; fi
    files="$files
      { \"path\": $(hyg_json_string "$sfile"), \"surface\": $(hyg_json_string "$ssurf"), \"reason\": $(hyg_json_string "$sway") }"
  done <<EOF
$surfaces
EOF
  printf '  "surfaces": {\n'
  printf '    "counts": { "automatic": %s, "configured": %s, "referenced": %s, "unknown": %s },\n' \
    "$na" "$ncfg" "$nr" "$nu"
  printf '    "files": ['
  [ -n "$files" ] && printf '%s\n    ' "$files"
  printf ']\n  },\n'
  printf '  "limits": ['
  while IFS= read -r lim; do
    [ -n "$lim" ] || continue
    if [ "$firstl" = 1 ]; then firstl=0; else printf ','; fi
    printf '\n    %s' "$(hyg_json_string "$lim")"
  done <<EOF
$(hyg_exposure_limits "$root" "$tool")
EOF
  if [ "$firstl" = 1 ]; then printf '],\n'; else printf '\n  ],\n'; fi
  printf '  "findings": ['
  [ -n "$body" ] && printf '%s\n  ' "$body"
  printf ']\n}\n'
}
