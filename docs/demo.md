# A small, reproducible scan

This synthetic example illustrates pattern matching, not measured model behavior.
From the Hygiene checkout, run:

```sh
demo_dir="$(mktemp -d)"
printf '%s\n' '// Owner ruling: NEVER change this flow. See OLD-DESIGN.md' \
  'export const checkout = () => true;' > "$demo_dir/checkout.ts"
./bin/hygiene scan "$demo_dir"
```

Captured with v0.1.1 on macOS (temporary path normalized):

```text
agent hygiene · /tmp/hygiene-demo
  ────────────────────────────────────────────────

  comment density   50% of source is comment  (1 / 2 lines)

  governance in comments   1 lines — potential rules and rulings in source
    checkout.ts:1:// Owner ruling: NEVER change this flow. See OLD-DESIGN.md

  argument residue   none

  phantom authority   1 references — citations, links and targets that do not resolve
    checkout.ts:1 → OLD-DESIGN.md

  markdown   0 lines across 0 files

  ────────────────────────────────────────────────
  2 candidate findings across categories; review for false positives and overlap.
  Run `hygiene install` in this repo to stop more accumulating.
```

One line produces two candidate findings: an instruction-like comment and a
reference to a missing document. Counts across categories can overlap.
The comment density is descriptive, not a pass/fail score. The phantom line is
shown with the line it was written on, so the citation can be found in the file
rather than only in the structured report.

Compare it with a mechanism comment:

```sh
printf '%s\n' '// Returns true when checkout is available.' \
  'export const checkout = () => true;' > "$demo_dir/checkout.ts"
./bin/hygiene scan "$demo_dir"
```

Governance and missing-reference findings disappear. Comment density remains 50%,
so the current scanner still prints a summary of zero candidate findings rather
than its low-density clean verdict. The scan does not change either file.
