# Roadmap

Hygiene finds and prevents unintended repository authority: governance comments,
argument residue, phantom document references, accreting prose, deleted prose in
Git history, and uncontrolled durable agent memory.

This file is the canonical public roadmap. Completed items are marked here
rather than moved elsewhere, so the history of what was promised and what
shipped stays in one place.

## Boundaries that do not move

- The core scanner stays local, deterministic, inspectable, and read-only.
- No API keys, network calls, telemetry, model calls, npm packages, Cargo
  dependencies, or required package installation.
- Hygiene never deletes or rewrites a comment for you.
- Hygiene does not observe a model's private context, and does not claim that
  every finding was loaded by every agent.
- Hygiene is not a general code linter, and does not reimplement ctxlint or agnix.

## P0: Evidence and benchmark

- [x] A labeled benchmark of at least 120 reviewed examples, independent of the
      implementation patterns, spanning TypeScript/JavaScript, Python, Go, Rust,
      Java, Ruby, Shell, YAML, and Markdown. Shipped as 156 hand-labeled cases
      in `benchmark/cases/`, listed in `benchmark/cases.tsv`, across ten
      families.
- [x] Positive and hard-negative examples for governance comments, argument
      residue, phantom document references, ordinary explanatory comments, real
      technical invariants, product copy, legal prose, translations, test
      fixtures, dates and incident descriptions, and stale or conflicting agent
      instructions. Most cases are negative by design: 90 of the 156 expect
      nothing at all.
- [x] Stable, documented rule identifiers. `HYG-<CATEGORY>-<NNN>`, in
      `lib/rules.sh` and documented in `docs/rules.md`. Identifiers are never
      reused and never renumbered.
- [x] A benchmark runner reporting true positives, false positives, false
      negatives, per-category precision and recall, and aggregate precision and
      recall. `benchmark/run`, scoring at the granularity of one (case, rule)
      pair.
- [x] A release gate of at least 95% aggregate precision, with recall reported
      honestly. Measured at 98.7% precision and 100% recall over this corpus.
      Both figures are upper bounds measured on clear archetypes, not field
      estimates, and `benchmark/RESULTS.md` says so.
- [x] The benchmark wired into CI. `.github/workflows/ci.yml` runs
      `benchmark/run` and then fails if `benchmark/RESULTS.md` is not what a
      fresh run produces.
- [x] Contributor documentation for adding and reviewing benchmark cases.
      `benchmark/README.md`.
- [x] A generated, reproducible Markdown benchmark report.
      `benchmark/RESULTS.md`, written by `benchmark/report` and never edited by
      hand.
- [ ] Benchmark coverage for `HYG-HIS-001`. Deleted prose retrievable from Git
      history is not scored: the corpus is a plain tree with no history, and the
      runner reports the rule as unscored rather than as a pass. The rule is
      exercised by `test/run` instead.

## P1: Interoperability and adoption

- [x] `--format text|json|sarif`, with the existing invocation unchanged.
      `scan [path]` with no flags still prints the text report and still exits 0.
      The format is selected by one flag; the shape of the unflagging call did
      not change.
- [x] A versioned JSON schema, with schema version, rule identifier, category,
      severity, file, line when available, matched evidence, explanation, and
      remediation guidance per finding. `docs/formats.md` describes every field
      and the reason `line` is `null` rather than `0` for a file-level finding.
- [x] Correct escaping for arbitrary filenames and matched content. One escaping
      chokepoint, `hyg_json_string`, covers JSON and SARIF both; every string in
      either format goes through it.
- [x] SARIF that validates structurally and carries usable GitHub code locations.
      SARIF 2.1.0 with a driver, a rule descriptor per rule, `ruleIndex` on each
      result, `region.startLine` and a snippet where the finding has a line, and
      a percent-encoded `artifactLocation.uri`.
- [x] No new required runtime for the core scanner. The scanner still uses only
      `awk`, `sed`, `grep`, `sort`, `find`, `git`, `printf`, `wc`, `cksum`,
      `cut`, `tr`, `basename`, and `paste` — all POSIX or already required.
      `test/invariants` holds the network tripwire over the shipped surface.
- [x] Tests for text, JSON, and SARIF output. `test/run` asserts the structured
      report against the text report, so a field that disagrees with the report
      a human reads fails the suite.
- [x] `hygiene explain RULE_ID`. `bin/explain`, reachable as
      `hygiene explain`. With no argument it lists the rules with their titles;
      with an unknown identifier it prints the known ones and exits 2.
- [x] A baseline workflow: `--write-baseline` and `--new --baseline`. Stable
      fingerprints, never written silently, and `--new` without a baseline is an
      error rather than a silent full report. Documented in `docs/baselines.md`.
- [x] Tests for moved files, changed line numbers, removed findings, and
      genuinely new findings. `test/run` covers each of the five transitions,
      including that a moved file-level finding is re-reported once.
- [x] Documentation of how `.hygieneignore` differs from a baseline.
      `docs/baselines.md` compares them: an ignore is a judgement about a path,
      a baseline is a record of what was already there, and only one of them
      goes stale.

## P2: Context exposure

- [x] `hygiene exposure --tool claude-code|cursor|codex|copilot|generic`.
      `bin/exposure` is read-only, requires the tool, and exits 0 for any report
      and 2 for a usage error. There is no default tool, because the tools
      document different surfaces and a default would invent an answer for
      whichever one was not chosen.
- [x] Only documented, deterministic loading surfaces, with the sources cited.
      Per-tool behaviour is derived from each vendor's own public documentation
      and cited with a URL in `docs/context-exposure.md`. The behaviour itself
      is data in `lib/exposure-surfaces.tsv` and `lib/exposure-limits.tsv`,
      interpreted by `lib/exposure.sh`.
- [x] Findings split into stored in explicit instruction files, reachable
      through documented imports, and elsewhere in the repository. Three
      verdicts, none of them a claim about a running agent: `likely exposed`
      for a documented surface, `loading unknown` for a referenced file or a
      rule that decides by reading the file, `stored` for everything else.
- [x] Text and JSON output. `--format json` carries the surface of every file
      in scope with the reason beside it, so a finding and its verdict are read
      against the same map.
- [x] Synthetic repositories for every supported tool, plus ambiguous and
      negative tests. `test/exposure/` holds one repository per tool and one
      that is deliberately ambiguous, with the expected surface and verdict for
      each path in `test/exposure/expected.tsv`. Most rows are negative: a file
      reported as loaded when the documentation does not say so is the worst
      bug this feature can have.
- [x] Fail open when a configuration cannot be parsed, and report the limitation.
      Frontmatter that does not close is reported as unknown with the reason in
      the row, and a documented fallback is used and named where a tool
      describes one. A path that resolves outside the tree is printed as
      written.

## P3: Distribution and authority

- [ ] An official GitHub Action supporting path, format, baseline, new-only
      mode, and optional SARIF upload.
- [ ] Read-only by default, with an explicit strict option.
- [ ] A complete example workflow.
- [ ] Benchmark status in README.md.
- [ ] A comparison document covering Hygiene, ctxlint, and agnix.
- [ ] A case-study template and a process for anonymized public-beta submissions.
