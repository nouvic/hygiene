#!/usr/bin/env bash
# findings: the detector core, shared by bin/scan and the benchmark.
#
# Sourced after lib/patterns.sh, lib/rules.sh and lib/references.sh. bash 3.2
# compatible.
#
# hyg_findings <root> emits one TAB-separated record per finding, in a stable
# order: every source-file finding first, in file order, then every prose
# finding, then the configuration findings, then the symbolic links. The fields
# are:
#
#   rule <TAB> category <TAB> severity <TAB> file <TAB> line <TAB> match <TAB> evidence
#
# `line` is empty for a file-level finding, and `match` is empty when nothing
# narrower than the line matched. `evidence` comes last so that it absorbs a
# stray TAB in the matched text; read a record with
#
#   IFS="$(printf '\t')" read -r rule category severity file line match evidence
#
# The scope is exactly the scanner's: source files for governance, phantom
# references and comment volume; source comments and repository prose for
# argument residue; documents, agent instruction files and the agent
# configuration whose paths are read for references that do not resolve; and
# every symbolic link for one whose target is gone. A finding is a condition
# stored in the repository. It is not a claim about what any agent loaded.
#
# None of this writes. Nothing under here creates, moves, or removes a file, and
# nothing under here follows a symbolic link.

# Files in scope for the scanner: tracked plus untracked-but-unignored in a Git
# repository, every file and every symbolic link otherwise. A link is part of the
# inventory in both cases, because a target that is gone is a condition the
# repository stores; and find does not follow a link, so a link to a directory is
# listed as the link and its contents are never walked through it.
hyg_list_files() {
  local root="$1"
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$root" ls-files --cached --others --exclude-standard 2>/dev/null | sort -u
  else
    ( cd "$root" 2>/dev/null && find . \( -type f -o -type l \) 2>/dev/null | sed 's|^\./||' )
  fi
}

hyg_in_git() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1
}

hyg_emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

# One record per finding under <root>.
hyg_findings() {
  local root="$1"
  local extra; extra="$(hyg_extra_exempt "$root")"
  local in_git=0; hyg_in_git "$root" && in_git=1

  local files src="" docs="" rel conf
  files="$(hyg_list_files "$root" | grep -Ev "$HYG_EXEMPT_PATHS")"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    # A link whose target is gone is still a path this repository stores, and
    # -f is false for it. Everything below reads the file it classified, so
    # only these two shapes reach the classification at all.
    [ -L "$root/$rel" ] || [ -f "$root/$rel" ] || continue
    hyg_is_exempt "$rel" "$extra" && continue
    if printf '%s' "$rel" | grep -Eq "$HYG_DOC_EXT"; then
      docs="$docs$rel
"
    elif printf '%s' "$rel" | grep -Eq "$HYG_SRC_EXT"; then
      src="$src$rel
"
    fi
  done <<EOF
$files
EOF

  # Only a path that resolves to a file is read. A link whose target is gone is
  # already a link finding, and reading through it would fail; a link to a
  # directory is not a source file or a document in the first place.
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$root/$rel" ] || continue
    hyg_findings_source "$root" "$rel" "$in_git"
  done <<EOF
$src
EOF

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$root/$rel" ] || continue
    hyg_findings_prose "$root" "$rel"
  done <<EOF
$docs
EOF

  # Agent configuration carries a path the way a document carries a citation, so
  # it is read for references too. Only the two files Claude Code's own
  # documentation places in a project are read, and only when the repository
  # stores them: an ignored settings file does not travel, and a condition about
  # a file that does not travel is not a condition about this repository.
  for conf in .claude/settings.json .claude/settings.local.json; do
    printf '%s\n' "$files" | grep -qxF "$conf" || continue
    hyg_is_exempt "$conf" "$extra" && continue
    hyg_findings_reference "$root" "$conf" config
  done

  hyg_findings_links "$root" "$files" "$extra"
}

# Findings inside one source file: governance, residue, phantom references,
# then comment volume.
hyg_findings_source() {
  local root="$1" rel="$2" in_git="$3" hit line text

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    line="${hit%%:*}"; text="${hit#*:}"
    hyg_emit HYG-GOV-001 governance warning "$rel" "$line" "" "$text"
  done <<EOF
$(hyg_comment_lines "$root/$rel" | hyg_match_governance)
EOF

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    line="${hit%%:*}"; text="${hit#*:}"
    hyg_emit HYG-ARG-001 argument-residue warning "$rel" "$line" "" "$text"
  done <<EOF
$(hyg_comment_lines "$root/$rel" | grep -Ei "$HYG_RESIDUE" 2>/dev/null)
EOF

  hyg_findings_phantom "$root" "$rel" "$in_git"
  hyg_findings_volume "$root" "$rel"
}

# A source comment citing a .md that the repository does not contain.
hyg_findings_phantom() {
  local root="$1" rel="$2" in_git="$3" r base line text refs
  refs="$(hyg_comment_lines "$root/$rel" | grep -oE "$HYG_DOCREF" 2>/dev/null \
          | sed -E 's/[^A-Za-z0-9]+$//' | sort -u)"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    [ -e "$root/$r" ] && continue
    base="$(basename "$r")"
    if [ "$in_git" = 1 ]; then
      git -C "$root" ls-files 2>/dev/null | grep -qi "/$base\$\|^$base\$" && continue
    else
      [ -n "$(find "$root" -name "$base" -print -quit 2>/dev/null)" ] && continue
    fi
    line="$(hyg_comment_lines "$root/$rel" | grep -F -m1 -- "$r" | cut -d: -f1)"
    text="$(hyg_comment_lines "$root/$rel" | grep -F -m1 -- "$r" | cut -d: -f2-)"
    hyg_emit HYG-PHA-001 phantom-reference warning "$rel" "$line" "$r" "$text"
  done <<EOF
$refs
EOF
}

# A source file whose comment share is high enough to be worth looking at.
# File level, so `line` stays empty.
hyg_findings_volume() {
  local root="$1" rel="$2" total cmt pct
  total="$(wc -l < "$root/$rel" 2>/dev/null | tr -d ' ')"
  [ "${total:-0}" -ge "$HYG_VOLUME_MIN_LINES" ] || return 0
  cmt="$(hyg_comment_lines "$root/$rel" | wc -l | tr -d ' ')"
  pct=$(( cmt * 100 / total ))
  [ "$pct" -ge "$HYG_VOLUME_PCT" ] || return 0
  hyg_emit HYG-VOL-001 prose-volume info "$rel" "" "" \
    "$pct% of $total lines are comment"
}

# Findings inside one prose file. Prose has no comments, so the whole file is
# the text. Argument residue is read from every document; references are read
# from Markdown, and from an agent instruction file whose own tool documents an
# import syntax.
hyg_findings_prose() {
  local root="$1" rel="$2" hit line text
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    line="${hit%%:*}"; text="${hit#*:}"
    hyg_emit HYG-ARG-002 argument-residue warning "$rel" "$line" "" "$text"
  done <<EOF
$(grep -nEi "$HYG_RESIDUE" "$root/$rel" 2>/dev/null)
EOF

  printf '%s' "$rel" | grep -Eq "$HYG_MD_EXT" \
    && hyg_findings_reference "$root" "$rel" markdown
  hyg_import_carrier "$rel" \
    && hyg_findings_reference "$root" "$rel" import
}

# The files whose documentation gives a local import syntax: the rows of the
# exposure table that carry imports=yes. Read from that table rather than
# restated, so a tool's import syntax cannot be documented in one file and
# parsed in another. Only one tool documents a local import today; a second one
# is a row, not a code change.
#
# The repository-relative path is what gets matched, as it is for every other
# surface. Testing the basename as well would answer with the root file's row
# for every nested file, which is wider than the table: the nested rows answer
# for nested paths, and a path no row matches carries nothing.
hyg_import_carrier() {
  local rel="$1" tool pat family surface reason param imports
  while IFS="$HYG_TAB" read -r tool pat family surface reason param imports; do
    [ "$imports" = yes ] || continue
    hyg_path_matches "$rel" "$pat" && return 0
  done <<EOF
$(hyg_table)
EOF
  return 1
}

# The line-numbered destinations one carrier yields for one file, as
# `line <TAB> destination`.
hyg_ref_extract() {
  local root="$1" rel="$2" kind="$3"
  case "$kind" in
    markdown) hyg_md_destinations "$root/$rel" ;;
    import)   hyg_import_lines "$root/$rel" ;;
    config)   hyg_config_paths "$root/$rel" ;;
  esac
}

# The directory a reference of this kind is written from. A link or an import
# is relative to the file that carries it, which is what the syntax means; a
# permission expression in agent configuration is relative to the project root,
# which is where that tool resolves it, not to the directory holding the
# settings file.
hyg_ref_base() {
  local rel="$1" kind="$2"
  case "$kind" in
    config) printf '%s\n' "" ;;
    *) if [ "${rel%/*}" = "$rel" ]; then printf '%s\n' ""; else printf '%s\n' "${rel%/*}"; fi ;;
  esac
}

# One finding per reference in one file that does not resolve. Every finding
# this produces is about a path the scanned repository holds and cannot deliver:
# a reference outside the scanned root reaches no verdict and so no finding, so
# a file that carries a machine-specific path is simply not reported here.
hyg_findings_reference() {
  local root="$1" rel="$2" kind="$3" dir line dest ev
  dir="$(hyg_ref_base "$rel" "$kind")"
  while IFS="$HYG_TAB" read -r line dest; do
    [ -n "$line" ] || continue
    dest="$(hyg_ref_target "$dest")"
    [ -n "$dest" ] || continue
    hyg_ref_verdict "$root" "$dir" "$dest" || continue
    case "$kind" in
      markdown) ev="link destination not found in this repository" ;;
      import)   ev="imported path not found in this repository" ;;
      *)        ev="configured path not found in this repository" ;;
    esac
    hyg_emit HYG-PHA-002 phantom-reference warning "$rel" "$line" "$dest" "$ev"
  done <<EOF
$(hyg_ref_extract "$root" "$rel" "$kind")
EOF
}

# Broken symbolic links. A link is in the inventory whether or not it is
# tracked, and it is reported when its target does not resolve. The test is the
# kernel's: -e follows the whole chain, so a chain resolves or does not, and a
# loop terminates at the kernel's own limit rather than in a loop of ours.
# Nothing here follows a link into a directory to enumerate through it, and
# nothing writes, moves or removes one.
hyg_findings_links() {
  local root="$1" files="$2" extra="$3" rel target
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -L "$root/$rel" ] || continue
    hyg_is_exempt "$rel" "$extra" && continue
    [ -e "$root/$rel" ] && continue
    target="$(hyg_symlink_target "$root/$rel")"
    hyg_emit HYG-PHA-003 phantom-reference warning "$rel" "" "$target" \
      "symbolic link target does not resolve"
  done <<EOF
$files
EOF
}

# Prose that was deleted from the tree and is still retrievable from history.
# Separate from hyg_findings because it needs commits, not files, and the
# scanner calls it under conditions the benchmark does not.
hyg_findings_history() {
  local root="$1" in_git=0
  hyg_in_git "$root" && in_git=1
  [ "$in_git" = 1 ] || return 0
  local p sha n
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$root/$p" ] && continue
    sha="$(git -C "$root" rev-list -1 --all -- "$p" 2>/dev/null)"
    [ -n "$sha" ] || continue
    n="$(git -C "$root" show "$sha^:$p" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] || n="$(git -C "$root" show "$sha:$p" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] || continue
    hyg_emit HYG-HIS-001 history-residue info "$p" "" "" "$n lines retrievable from history"
  done <<EOF
$(git -C "$root" log --diff-filter=D --name-only --format='' 2>/dev/null \
  | grep -Ei "$HYG_DOC_EXT" | sort -u)
EOF
}
