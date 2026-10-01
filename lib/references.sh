#!/usr/bin/env bash
# references: ghost references — the path primitives and the reference
# extractors shared by the scanner, the exposure report and the benchmark.
#
# A ghost reference is an explicit repository-local path, stored in a file that
# travels with the repository, that does not resolve. Three carriers produce one,
# and each is extracted here rather than inside the detector, so the extraction
# can be read and exercised on its own:
#
#   markdown destinations        hyg_md_destinations
#   documented local imports     hyg_import_lines
#   configuration path values    hyg_config_paths
#
# Extraction and resolution are separate on purpose. An extractor prints
# "line <TAB> destination" for every destination-shaped string it can see. The
# resolver, which lives with the detector, decides whether that string names this
# repository and whether the path it names exists. Nothing here reads a file
# outside the scanned root, and nothing here writes.
#
# Sourced after lib/patterns.sh, which is where the document extensions and the
# exempt paths come from. bash 3.2 compatible.

[ -n "${HYG_HOME:-}" ] || HYG_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYG_SURFACES="${HYG_SURFACES:-$HYG_HOME/lib/exposure-surfaces.tsv}"
# lib/report.sh defines the tab, but the benchmark runner builds rows without it,
# so the separator is derived here rather than assumed to be set.
[ -n "${HYG_TAB:-}" ] || HYG_TAB="$(printf '\t')"

# ------------------------------------------------------------------- tables

# A table without its comments and blank lines. Read once for the whole run,
# because every file in scope is looked up against the surface table.
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

# ------------------------------------------------------------------- path work

# dir + target with . and .. resolved, for an import written relative to the file
# holding it. An absolute target, or one starting with ~, is returned as it
# stands: it names something outside the repository, and the caller decides what
# that means.
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

# dir + target with . and .. resolved, for a reference that has to stay inside
# the repository. It fails rather than returning a path that climbed above the
# root: a target like ../../etc/hosts is not a statement about this repository,
# and collapsing the leading .. would quietly turn it into one.
hyg_ref_join() {
  local dir="$1" t="$2" out="" seg path esc=0
  if [ -n "$dir" ]; then path="$dir/$t"; else path="$t"; fi
  set -f
  local IFS='/'
  for seg in $path; do
    case "$seg" in
      ''|.) ;;
      ..) if [ -z "$out" ]; then esc=1
          elif [ "${out#*/}" = "$out" ]; then out=""
          else out="${out%/*}"; fi ;;
      *)  out="${out:+$out/}$seg" ;;
    esac
  done
  set +f
  [ "$esc" = 1 ] && return 1
  printf '%s\n' "$out"
}

# Whether the repository holds this path. A symbolic link whose target is gone
# still holds the path: that is its own condition with its own rule, and a
# reference to the link is not a second finding about it.
hyg_ref_exists() { [ -e "$1" ] || [ -L "$1" ]; }

# --------------------------------------------------------------- normalisation

# A destination as written, reduced to the path it names: surrounding space and
# an optional angle-bracket form removed, an optional Markdown title removed, and
# the query and fragment cut at the first ? or #. The fragment is not checked —
# whether a heading exists inside the target is a question this release does not
# answer, and pretending to answer it would report every anchor in a healthy
# document.
hyg_ref_target() {
  printf '%s\n' "$1" | sed -E \
    -e 's/^[[:space:]]+//' \
    -e 's/[[:space:]]+$//' \
    -e 's/^<([^>]*)>.*$/\1/' \
    -e 's/[[:space:]]+".*$//' \
    -e 's/[?#].*$//' \
    -e 's/^[[:space:]]+//' \
    -e 's/[[:space:]]+$//' | tr -d '\t\r'
}

# A destination written with the one percent-escape a Markdown author reaches
# for most often: %20 is what a space becomes when a link is written as a URL.
# Only that one is decoded. Decoding further would mean guessing an encoding the
# document never declared.
hyg_ref_decode() { printf '%s\n' "$1" | sed 's/%20/ /g'; }

# Whether a normalised destination is a path at all, rather than a URL, a
# same-page anchor, a templated path or a glob. Every one of those is something a
# reader is not meant to open, so reporting one would be a false positive on
# ordinary documentation. The placeholder list is deliberately short and specific:
# a bare word like todo or master is a real file name in a real repository.
hyg_ref_candidate() {
  local t="$1" low
  [ -n "$t" ] || return 1
  case "$t" in
    '#'*|'//'*|'/'|'~') return 1 ;;
    *'://'*|mailto:*|data:*|tel:*) return 1 ;;
  esac
  case "$t" in
    *'{{'*|*'${'*|*'<'*|*'>'*|*'*'*|*'?'*|*'['*|*']'*|*'…'*|*'...'*) return 1 ;;
  esac
  low="$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')"
  case "$low" in
    *'/path/to/'*|*'your_'*|*'your-'*|*'/absolute/'*|*'example.com'*) return 1 ;;
  esac
  return 0
}

# The verdict for one destination already known to be path-shaped. Succeeds
# when the destination is a repository path this checkout does not hold, and
# fails otherwise, which includes every destination this repository cannot
# answer for at all.
#
# The verdict is only ever an answer about this repository, because a finding
# says a reference does not resolve and that is a claim only a checkout can
# support. An absolute path under the scanned root is checked like any other
# reference. One that falls outside the root, and any path written with a
# leading tilde, names somewhere this repository cannot speak for. It is
# outside this rule's evidence boundary: nothing outside the root is opened, and
# no verdict is reached about it. Reporting such a path as missing would assert
# a resolution the scan never performed, and whether the file happens to exist
# on the machine that ran it would stop the answer from being the same
# everywhere. Such a reference may be perfectly sound where it was written, so
# the silence here is a boundary and not a clean bill of health.
hyg_ref_verdict() {
  local root="$1" dir="$2" dest="$3" path alt
  hyg_ref_candidate "$dest" || return 1
  case "$dest" in
    /*)
      path="$(hyg_ref_local "$root" "" "$dest")" || return 1
      hyg_ref_exists "$root/$path" && return 1
      return 0
      ;;
    '~'*) return 1 ;;
  esac
  path="$(hyg_ref_local "$root" "$dir" "$dest")" || return 1
  hyg_ref_exists "$root/$path" && return 1
  # A link written as a URL escapes its spaces as %20. The one escape that turns
  # a resolving target into a reported one is decoded and retried, so a link to
  # a file whose name has a space in it is not a finding.
  alt="$(hyg_ref_decode "$dest")"
  if [ "$alt" != "$dest" ]; then
    alt="$(hyg_ref_local "$root" "$dir" "$alt")" || alt=""
    [ -n "$alt" ] && hyg_ref_exists "$root/$alt" && return 1
  fi
  return 0
}

# The repository-relative path a candidate names, or nothing when it cannot be
# tied to the scanned tree. <dir> is the directory the reference is written in,
# relative to the root. An absolute candidate is accepted only when it lies under
# the root: a path into somebody's home directory is not evidence about this
# repository, and treating an arbitrary machine file as repository proof would
# make the result depend on the machine that ran the scan.
hyg_ref_local() {
  local root="$1" dir="$2" t="$3" joined
  case "$t" in
    '/') return 1 ;;
    /*) case "$t" in
          "$root"/*) joined="$(hyg_ref_join '' "${t#"$root"/}")" || return 1 ;;
          *) return 1 ;;
        esac ;;
    *) joined="$(hyg_ref_join "$dir" "$t")" || return 1 ;;
  esac
  [ -n "$joined" ] || return 1
  printf '%s\n' "$joined"
}

# ---------------------------------------------------------------- extraction

# Inline Markdown destinations, one per line, as "line <TAB> destination". Fenced
# blocks are skipped and inline code spans are removed first: a path inside
# backticks is text, and an example is not a reference. Reference-style
# definitions ("[label]: path") and targets carrying nested parentheses are not
# read here, which is a stated limit rather than an attempt that half works.
hyg_md_destinations() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      while (match(line, /\]\([^()]*\)/)) {
        printf "%d\t%s\n", NR, substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" 2>/dev/null
}

# The @path tokens a memory file carries, one per line, as
# "line <TAB> destination". Fenced blocks and inline code spans come out first: a
# path inside backticks is text rather than an import, and a parser that missed
# that would report a file named in an example as one that loads. This is the
# syntax lib/exposure-surfaces.tsv marks with imports = yes, and no other import
# syntax is invented here.
#
# An at-sign is not a path. The same character opens an address
# (team@company.org), a handle (@nouvic) and a package scope (@scope/pkg), and
# ordinary prose is full of all three. A token counts as an import when three
# things hold at once:
#
#   - it starts where an import starts: the character ahead of the at-sign is
#     not one an address's local part is made of (A-Z a-z 0-9 . _ % + -). There
#     the at-sign separates the two halves of an address instead of introducing
#     a path. This is a test on position, not a list of domains.
#   - it holds no second at-sign, so an address written with its instance
#     attached reads as an address rather than as a path.
#   - it ends in a file extension, tested after trailing punctuation and any
#     ?query or #fragment comes off. A bare word reads as a mention more often
#     than as a file, so the extensionless token is skipped; what that gives up
#     is the extensionless import, which the rule's own limits record beside the
#     backslash-escaped-space form.
#
# The extension test also keeps a handle and a package scope out, since both are
# words with no dot in the tail.
hyg_import_lines() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      i = 1
      while (i <= length(line)) {
        rest = substr(line, i)
        if (!match(rest, /@[^[:space:]]+/)) break
        start = i + RSTART - 1
        t = substr(rest, RSTART + 1, RLENGTH - 1)
        i = start + RLENGTH
        if (start > 1 && substr(line, start - 1, 1) ~ /[A-Za-z0-9._%+-]/) continue
        sub(/[[:punct:]]+$/, "", t)
        if (t ~ /@/) continue
        dest = t
        sub(/[?#].*$/, "", dest)
        if (dest !~ /\.[A-Za-z][A-Za-z0-9]*$/) continue
        printf "%d\t%s\n", NR, t
      }
    }
  ' "$1" 2>/dev/null
}

# The tokens alone, for the exposure closure, which does not carry line numbers.
hyg_imports_in() { hyg_import_lines "$1" | awk 'NF > 1 { print $2 }'; }

# Path values in the agent configuration Hygiene already supports: a permission
# expression, Tool(path), in the two Claude Code settings files. The parse is a
# literal list of the tools whose argument is a path, so an arbitrary JSON string
# that happens to contain a slash is never read as one. A trailing /** is the
# documented way to mean the directory and everything under it, and comes off
# before the value is tested; a glob anywhere else is left alone and skipped by
# the candidate test rather than guessed at.
hyg_config_paths() {
  awk '
    {
      line = $0
      while (match(line, /"(Read|Edit|Write|NotebookEdit|MultiEdit)\([^"]*\)"/)) {
        d = substr(line, RSTART + 1, RLENGTH - 2)
        sub(/^[A-Za-z]+\(/, "", d)
        sub(/\)$/, "", d)
        if (d ~ /^\/\//) sub(/^\/\//, "/", d)
        sub(/\/\*\*$/, "", d)
        printf "%d\t%s\n", NR, d
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$1" 2>/dev/null
}

# The text a symbolic link holds, read without following it. readlink is optional
# here: where it is absent the finding is still reported and only the target text
# is missing, because the target is the one part of this condition that needs a
# tool, and losing it must not lose the finding. One operand, no options.
hyg_symlink_target() {
  command -v readlink >/dev/null 2>&1 || return 0
  readlink "$1" 2>/dev/null | tr -d '\r'
  return 0
}
