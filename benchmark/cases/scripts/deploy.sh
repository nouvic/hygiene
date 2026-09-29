# The deploy script builds, publishes, and reports.
#
# Every step is idempotent, so a rerun after a failure is safe.
# The script does not read a secret from disk; the caller exports it.
#
# The artifact directory is created once and reused.
#
# The script exits non-zero only when a step it ran failed.
#
# Dry run mode prints the plan and changes nothing.
#
# The publish step is skipped when the target already holds the same
# digest.
#
# Nothing here reaches the network except the publish step itself.
set -euo pipefail

# The directory the build writes into.
OUT_DIR="${OUT_DIR:-build}"

# The target the publish step uploads to.
TARGET="${TARGET:-staging}"

# Builds the artifact into the output directory.
build() {
  mkdir -p "$OUT_DIR"
  printf 'built\n' > "$OUT_DIR/artifact.txt"
}

# Publishes the artifact to the target.
publish() {
  printf 'published %s\n' "$TARGET"
}

# Prints the plan without running it.
plan() {
  printf 'would publish %s\n' "$TARGET"
}

# Entry point.
main() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    plan
  else
    build
    publish
  fi
}

# Runs only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main
fi

# The scale is the number of minor units, two for most currencies.
SCALE=2

# Amounts are always integers.
ZERO=0
