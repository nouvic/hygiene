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

- [ ] `--format text|json|sarif`, with the existing invocation unchanged.
- [ ] A versioned JSON schema, with schema version, rule identifier, category,
      severity, file, line when available, matched evidence, explanation, and
      remediation guidance per finding.
- [ ] Correct escaping for arbitrary filenames and matched content.
- [ ] SARIF that validates structurally and carries usable GitHub code locations.
- [ ] No new required runtime for the core scanner.
- [ ] Tests for text, JSON, and SARIF output.
- [ ] `hygiene explain RULE_ID`.
- [ ] A baseline workflow: `--write-baseline` and `--new --baseline`.
- [ ] Tests for moved files, changed line numbers, removed findings, and
      genuinely new findings.
- [ ] Documentation of how `.hygieneignore` differs from a baseline.

## P2: Context exposure

- [ ] `hygiene exposure --tool claude-code|cursor|codex|copilot|generic`.
- [ ] Only documented, deterministic loading surfaces, with the sources cited.
- [ ] Findings split into stored in explicit instruction files, reachable
      through documented imports, and elsewhere in the repository.
- [ ] Text and JSON output.
- [ ] Synthetic repositories for every supported tool, plus ambiguous and
      negative tests.
- [ ] Fail open when a configuration cannot be parsed, and report the limitation.

## P3: Distribution and authority

- [ ] An official GitHub Action supporting path, format, baseline, new-only
      mode, and optional SARIF upload.
- [ ] Read-only by default, with an explicit strict option.
- [ ] A complete example workflow.
- [ ] Benchmark status in README.md.
- [ ] A comparison document covering Hygiene, ctxlint, and agnix.
- [ ] A case-study template and a process for anonymized public-beta submissions.
