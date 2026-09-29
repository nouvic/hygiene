# Continuous integration

    hygiene scan --strict /path/to/your-project

A scan is a report, so it exits `0` whether or not it found anything. That is
the right default for a person reading a report and the wrong default for a
build gate, so there is one flag that changes it. `--strict` exits `1` when the
report holds a **warning**-severity finding. Informational findings are reported
and the run stays green, because a size signal is not a defect.

| exit | meaning |
| --- | --- |
| `0` | the report ran, with or without findings |
| `1` | `--strict` was given and the report holds a warning-severity finding |
| `2` | usage error: unknown format, unknown option, missing path, missing baseline |

Warnings are `HYG-GOV-*`, `HYG-ARG-*`, and `HYG-PHA-*`: a source comment stating
a rule or a ruling, argument residue, and a reference to a document the
repository does not contain. Informational findings are `HYG-VOL-*` and
`HYG-HIS-*`: a source file that is mostly comment, and prose still retrievable
from Git history. `hygiene explain HYG-GOV-001` prints what any rule does and
does not claim.

## The GitHub Action

`action.yml` at the root of this repository is a composite action. It runs the
same Bash CLI the README documents, with nothing installed and no third-party
action to trust. It never writes to the scanned tree, makes no network request,
and sends no telemetry; the only file it can write is the report you ask for.

| input | default | meaning |
| --- | --- | --- |
| `path` | `.` | directory to scan |
| `format` | `text` | `text`, `json`, or `sarif` |
| `output` | empty | file to write the report to; empty prints it in the job log |
| `baseline` | empty | baseline file to compare against, resolved against `path` |
| `new-only` | `false` | report only findings the baseline does not hold; errors without `baseline` |
| `strict` | `false` | fail the step on a warning-severity finding |
| `summary` | `true` | append a text report to the job summary |

A minimal job:

```yaml
name: hygiene

on: [push, pull_request]

permissions:
  contents: read
  # Only the SARIF upload needs this. Remove both together.
  security-events: write

jobs:
  hygiene:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0
      - uses: nouvic/hygiene@v0.1.1
        with:
          strict: 'true'
```

Pin a release tag. This repository has no release automation, so a tag is a
fixed point and a branch is not; that tag is the version this tree carries, and
the newest one is on the repository's tags page. `fetch-depth: 0` matters for
the same reason the hooks do: history residue is read from Git history, and a
shallow clone hides part of it.

## A complete workflow

This is the whole thing, including the structured report and the optional SARIF
upload. It is [`docs/examples/hygiene.yml`](examples/hygiene.yml) in this
repository, so it can be copied rather than retyped.

```yaml
name: hygiene

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  # Only the SARIF upload needs this. Remove both together.
  security-events: write

jobs:
  hygiene:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0

      # One scan, written to a file, so the same result feeds the gate, the
      # uploaded artifact, and code scanning.
      - name: Scan
        uses: nouvic/hygiene@v0.1.1
        with:
          path: .
          format: sarif
          output: hygiene.sarif
          strict: 'true'

      # Always: a report is worth reading whether or not the gate failed.
      - name: Keep the report
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        with:
          name: hygiene.sarif
          path: hygiene.sarif
          if-no-files-found: error

      # Optional. Uploading SARIF to code scanning needs `security-events:
      # write` and code scanning enabled for the repository. On a public
      # repository that is free; on a private one it needs GitHub Advanced
      # Security. When neither applies, delete this step and the artifact step
      # above still gives you the report.
      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@1190a975f95ce23525efb6a3fc21ea29567c1b52 # v3
        with:
          sarif_file: hygiene.sarif
          category: hygiene
```

Three things about the SARIF upload. It needs `security-events: write`, which
the block above grants and the comment marks as belonging to that one step.
`github/codeql-action/upload-sarif` is third-party code this repository does not
vendor, so it is pinned by SHA the way the checkout step is pinned; that SHA is
v3 as published on 2026-09-29, and the same is true of the artifact step's SHA,
which is v4.6.2. And on a repository where code scanning is unavailable, the
step is the only thing to delete: the scan, the gate, and the artifact all still
work.

## An existing backlog

A repository with a long history has findings already, and a gate that fails on
all of them on the first day is a gate nobody keeps. Record the backlog once and
gate only what is new:

```yaml
      - name: Scan
        uses: nouvic/hygiene@v0.1.1
        with:
          format: sarif
          output: hygiene.sarif
          baseline: .hygiene-baseline
          new-only: 'true'
          strict: 'true'
```

Then commit the baseline:

```sh
hygiene scan --write-baseline .
git add .hygiene-baseline
```

`--new` without a baseline is a usage error rather than a silent empty baseline,
so a baseline that fails to reach the runner fails the job instead of reporting
a clean tree. See [Baselines](baselines.md) for how a baseline differs from
`.hygieneignore`, and for the properties that keep it useful as files move.

## Outside GitHub

The exit status is the whole interface, so any runner works:

```sh
# .gitlab-ci.yml, a Makefile, a Jenkins stage, or a shell in a container
hygiene scan --strict .
```

The action is a convenience over the CLI, not a different scanner. If the
action cannot do something you need, run `bin/hygiene` directly; the scan has no
network dependency and no package to install, so a checkout of this repository
is the whole installation.

## What CI does not get

- No findings are ever uploaded by Hygiene itself. The SARIF upload is a
  separate step you add and can remove; `scan` writes only the file you name.
- No baseline is generated automatically. A gate decides what it holds from a
  file in the repository, and a file a human committed is a decision someone
  can review.
- No comment is deleted. Every rule reports; the fix is a code change a person
  makes.
