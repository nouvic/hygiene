# Output formats

`hygiene scan` prints a text report by default. `--format json` and
`--format sarif` replace that report with a document on stdout. The default
invocation is unchanged: no flag, same text, same exit status.

    hygiene scan                       text report
    hygiene scan --format json PATH    JSON document
    hygiene scan --format sarif PATH   SARIF 2.1.0 log

Two properties hold for both structured formats.

**Nothing else goes to stdout.** A document has to be the whole document, so
progress notes and baseline messages go to stderr. A consumer can pipe stdout
straight into a parser.

**Exit status stays 0.** A finding is not a failure. The only non-zero exits
are usage errors, which is why `--format` rejects an unknown value with status
2 rather than falling back to text.

## JSON

One object, one schema version.

```json
{
  "schemaVersion": 1,
  "tool": { "name": "hygiene", "version": "0.4.0" },
  "root": ".",
  "summary": { "findings": 2, "warning": 1, "info": 1 },
  "findings": [ ... ]
}
```

| field | meaning |
| --- | --- |
| `schemaVersion` | integer, currently `1`. It changes when a field changes meaning or disappears. |
| `tool` | the producing tool and its version, read from `VERSION`. |
| `root` | the path argument as it was given, not a resolved absolute path, so the output is stable across machines. |
| `baseline` | present only under `--new`. Carries the baseline path, how many findings it suppressed, and its own schema version. |
| `summary` | counts by severity. `findings` is the length of the array. |
| `findings[]` | one object per finding, in report order. |

Each finding:

| field | meaning |
| --- | --- |
| `ruleId` | `HYG-<CATEGORY>-<NNN>`. Stable, never reused. |
| `category` | the category half of the identifier, spelled out. |
| `severity` | `warning` or `info`, as the registry assigns it. |
| `file` | repository-relative path. |
| `line` | integer, or `null` for a finding that belongs to a whole file. |
| `match` | the narrow text that matched, or `null` when nothing narrower than the line matched. |
| `fingerprint` | the baseline key. See the baselines document. |
| `message` | one sentence, from the rule registry. |
| `remediation` | what to do, from the rule registry. |
| `evidence` | the whole matched line, so a reader can judge the finding without opening the file. |

`line` and `match` are `null` rather than absent or `0`. A consumer that
treats a missing line as line zero points a code annotation at the top of the
file; a consumer that reads `null` knows there is no line to point at.

### Escaping

Every string field passes through one function. Control characters that JSON
cannot represent literally are dropped rather than turned into invalid escape
sequences, then backslash, double quote, tab, newline and carriage return are
escaped. This matters for matched text, which comes from source files and can
contain anything the file contains.

Filenames are not assumed to be ASCII or to be free of quotes, spaces, and
newlines. A path that needs it is emitted as a JSON string like any other, and
the SARIF location for it is percent-encoded. The benchmark and the test suite
both cover a file whose name contains a space and a double quote.

## SARIF

SARIF 2.1.0, one run, from `tool.driver`.

```json
{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": { "driver": { "name": "hygiene", "version": "...", "informationUri": "...", "rules": [...] } },
      "results": [...]
    }
  ]
}
```

The driver declares only the rules that appear in the run. Each descriptor
carries the identifier, a letters-and-digits `name` for consumers that want an
identifier rather than an id, a short and a full description, a `helpUri`
pointing at the rule documentation, the help text, and a default level.

Each result carries:

- `ruleId` and `ruleIndex`, indexing into the run's rule array.
- `level`: `warning` for the rules the registry marks as warning, `note` for
  the informational ones. A consumer that fails a build on `error` will not
  fail on a Hygiene finding, which is the intended default.
- `message.text`: the truncated evidence, so a GitHub annotation reads as the
  matched line rather than as a rule number.
- `locations[0].physicalLocation.artifactLocation.uri`, percent-encoded, with
  a `region` carrying `startLine` and `snippet.text` when there is a line.
- `partialFingerprints["hygieneFingerprint/v1"]`, the same value the JSON
  format calls `fingerprint`. This is what GitHub uses to track an alert
  across a rebase or a moved file.
- `properties.category`.

A file-level finding has no `region`. SARIF allows that, and inventing line 1
would put a code-scanning annotation on a line that did not produce the
finding.

Uploading the log is a decision for the repository that runs it. The example
workflow in the repository shows the upload step, commented, with the
permissions it needs. Nothing in Hygiene uploads anything.
