#!/usr/bin/env bash
# findings: the detector core, shared by bin/scan and the benchmark.
#
# Sourced after lib/patterns.sh and lib/rules.sh. bash 3.2 compatible.
#
# hyg_findings <root> emits one TAB-separated record per finding, in a stable
# order: every source-file finding first, in file order, then every prose
# finding. The fields are:
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
# argument residue. A finding is a condition stored in the repository. It is
# not a claim about what any agent loaded.
#
# None of this writes. Nothing under here creates, moves, or removes a file.

# Files in scope for the scanner: tracked plus untracked-but-unignored in a Git
# repository, every file otherwise.
hyg_list_files() {
  local root="$1"
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$root" ls-files --cached --others --exclude-standard 2>/dev/null | sort -u
  else
    ( cd "$root" 2>/dev/null && find . -type f 2>/dev/null | sed 's|^\./||' )
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

  local src="" docs="" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -f "$root/$rel" ] || continue
    hyg_is_exempt "$rel" "$extra" && continue
    if printf '%s' "$rel" | grep -Eq "$HYG_DOC_EXT"; then
      docs="$docs$rel
"
    elif printf '%s' "$rel" | grep -Eq "$HYG_SRC_EXT"; then
      src="$src$rel
"
    fi
  done <<EOF
$(hyg_list_files "$root" | grep -Ev "$HYG_EXEMPT_PATHS")
EOF

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    hyg_findings_source "$root" "$rel" "$in_git"
  done <<EOF
$src
EOF

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    hyg_findings_prose "$root" "$rel"
  done <<EOF
$docs
EOF
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
# the text.
hyg_findings_prose() {
  local root="$1" rel="$2" hit line text
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    line="${hit%%:*}"; text="${hit#*:}"
    hyg_emit HYG-ARG-002 argument-residue warning "$rel" "$line" "" "$text"
  done <<EOF
$(grep -nEi "$HYG_RESIDUE" "$root/$rel" 2>/dev/null)
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
