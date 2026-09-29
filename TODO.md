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
- No agent instruction file and no structured-data block is added to this
  repository for crawler or search discovery. `AGENTS.md` routes an agent that
  is already reading it; nothing here exists to attract one.

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

- [x] An official GitHub Action supporting path, format, baseline, new-only
      mode, and optional SARIF upload. `action.yml` is a composite action at the
      repository root, so there is no third-party action to trust and nothing to
      install: it runs the same Bash CLI with inputs for `path`, `format`,
      `output`, `baseline`, `new-only`, `strict`, and `summary`. The action
      uploads nothing itself. The SARIF upload is a separate step the workflow
      adds, and `docs/ci.md` shows it with the permission it needs and the two
      cases where code scanning is unavailable.
- [x] Read-only by default, with an explicit strict option. `scan` still exits 0
      for any report. `--strict` exits 1 when the report holds a
      warning-severity finding, and informational findings stay reported and
      ungated, which is what their severity already says about them. A usage
      error still exits 2 and `--strict` does not downgrade it. `test/run`
      covers each of those, including that the flag does not change the report
      it prints.
- [x] A complete example workflow. `.github/workflows/hygiene.yml` runs the
      action on this repository with the gate on and on both macOS and Linux, so
      a change that breaks the action fails here rather than in a consuming
      project. `docs/ci.md` covers the inputs, the exit contract, a minimal job,
      a complete job with the report artifact and the optional SARIF upload, and
      the baseline pattern for a repository that cannot fix everything at once.
      The copyable workflow is `docs/examples/hygiene.yml`.
- [x] Benchmark status in README.md. The measured precision, recall, and gate
      result, with the label count and what the corpus does and does not
      establish stated beside them. The numbers come from `benchmark/RESULTS.md`,
      which is generated, so the README cannot drift from the measurement.
- [x] A comparison document covering Hygiene, ctxlint, and agnix.
      `docs/comparison.md`. Every statement about Hygiene is a property of its
      own code, fixtures, or tests; every statement about the other two is
      quoted from their public documentation with the retrieval date, and
      neither was installed or run, which the page says. It describes scope
      rather than superiority and lists what the other two do that Hygiene does
      not.
- [x] A case-study template and a process for anonymized public-beta
      submissions. `docs/case-study-template.md` asks for repository
      characteristics, scan version and command, findings by rule, reviewed true
      and false positives, cleanup performed, token counts only when actually
      measured, observed workflow change, and limitations, and treats "not
      measured" as a complete answer. `docs/public-beta.md` documents what to
      send, how to anonymize it, what Hygiene does not collect, and what happens
      to a submission. `.github/ISSUE_TEMPLATE/case-study.md` is the issue form
      for the third kind.

## P4: Discovery and claim integrity

The rule for this section: a claim ships with the thing that makes it
checkable, and a claim nothing supports is removed rather than softened.

- [x] The repository `AGENTS.md` routes its two readers apart before it
      instructs either one. An agent installing the tool into another project
      is sent to the installation steps; an agent working on this repository is
      sent to `CONTRIBUTING.md` and to `./test/run` and `./test/invariants`, and
      is told not to install the tool into itself. Enforced by section 3 of
      `test/invariants`, with a tamper case in `test/run` proving the tripwire
      fires on a copy that instructs first and routes never.
- [x] `docs/capability-and-evidence-map.md`. Ten symptoms, each mapped to the
      stored condition, the rule or feature, the mechanism, what Hygiene
      establishes, what stays tool and task dependent, an evidence label, and
      the source or test behind it. Six labels are defined and used
      consistently: MECHANICAL FACT, REPRODUCIBLE HYGIENE TEST, FOUNDING CASE
      OBSERVATION, EXTERNAL EMPIRICAL EVIDENCE, TOOL-DEPENDENT, and NOT
      ESTABLISHED.
- [x] A `## Problems Hygiene is designed to surface` section in `README.md`,
      with the same symptoms in one line each and a link to the map.
- [x] A capability matrix in `docs/comparison.md`, thirteen rows, one support
      level per tool, with every competitor cell read from that project's own
      published documentation. The levels are Supported, Partial, Not currently
      supported, and Outside scope, and the page defines what each one asserts.
      The claim that neither project documents a history check was narrowed:
      ctxlint documents Git history for `--fix` path repair and rename
      detection, which is a different operation over the same input.
- [x] Documented rule identifiers are validated. `test/invariants` fails when a
      rule identifier cited in `README.md`, `AGENTS.md`, `TODO.md`, `docs/`, or
      `benchmark/` is not in the registry in `lib/rules.sh`, and when a
      registered rule is missing from `docs/rules.md`. A capability row can no
      longer point at a rule that does not exist.
- [x] Claim-consistency review. Every occurrence of token, context bloat,
      hallucination, semantic, only, guarantee, eliminate, 20 percent,
      zero-token, memory, and context engineering was read in context. Where a
      term appears it is a stated limit or a cited source. The review is
      recorded in the pull request description rather than in a planning file.
- [ ] `llms.txt` was not updated by this pass, and deliberately. The file is not
      in this branch's working tree; it lives on the orphan `gh-pages` branch,
      which this branch does not own, and the published copy already points at
      the README, the context-rot guide, the demo, `CONTRIBUTING.md`, and
      `SECURITY.md`. Whoever next works on the Pages source should add the
      capability and evidence map, the comparison page, and the benchmark
      report to that list, and should keep every sentence there inside the
      claims the map supports.
- [ ] Structured data for search discovery (schema.org, JSON-LD, crawler
      metadata) belongs on the GitHub Pages site, not in GitHub Markdown, and
      no JSON-LD is added here. Not started, because this pass did not touch the
      Pages source.
- [x] No `.cursorrules`, `CLAUDE.md`, or other agent instruction file is added
      to this repository for discovery. `AGENTS.md` exists to route an agent
      that is already reading it, and it is the only such file here. The
      boundary is stated under Boundaries above and is checked by the routing
      tripwire in `test/invariants`.
