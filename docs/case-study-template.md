# Case study template

A case study is one repository's experience with Hygiene, written so that a
reader can check the claims in it. The value is in the detail that makes a
result reproducible and in the parts that did not work; a case study that only
reports a large number is an advertisement, and this project does not publish
those.

Copy the sections below into an issue or a pull request. Delete a section and
write why rather than inventing a value for it. **"Not measured" is a complete
and acceptable answer** for any field, and it is better than an estimate.

If a number in the study was not produced by a command whose output you can
paste, either paste the command and its output or drop the number.

---

## Template

### Repository characteristics

<!-- Size, languages, age of the history, team size, and whether agents work in
it. Enough that a reader knows what kind of repository this is, and no more
identifying detail than you are comfortable publishing. -->

- Tracked files, source files, and total Git commits:
- Languages and rough proportions:
- History depth and shape (years, contributors, whether it was squashed):
- Team size, and whether it is solo:
- Which coding agents and which tools, since that is what makes a finding
  loadable:
- Instruction and config files present (`CLAUDE.md`, `AGENTS.md`, `.cursor/rules`,
  `.github/copilot-instructions.md`, others):
- Whether Git hooks or another check already blocked commits:

### Scan version and command

```sh
./bin/hygiene version
./bin/hygiene scan --format json /path/to/repository > scan.json
```

- Hygiene version and commit:
- OS, and `bash --version`:
- The exact scan command line, including any `--new` or `--baseline`:
- Whether hooks were installed, and whether the scan ran on a clean checkout:

### Findings by rule

Counts as reported, not as judged. One anonymized example per rule makes the
table checkable.

| rule | findings | example line (anonymized) |
| --- | --- | --- |
| HYG-GOV-001 |  |  |
| HYG-ARG-001 |  |  |
| HYG-ARG-002 |  |  |
| HYG-PHA-001 |  |  |
| HYG-PHA-002 |  |  |
| HYG-PHA-003 |  |  |
| HYG-VOL-001 |  |  |
| HYG-HIS-001 |  |  |

- Total findings, and how many files they sit in:
- Which category the findings concentrated in, and where in the tree:
- `hygiene exposure --tool <tool>` verdicts for those files, when run:

### Reviewed true and false positives

This is the most useful section of the study. For every rule that fired, say how
many you judged true and how many false, and for each false positive say what
kind of ordinary comment it was. A false positive you cannot explain is still
worth reporting as unexplained.

| rule | judged true | judged false | what the false positives were |
| --- | --- | --- | --- |
|  |  |  |  |

- Total precision as judged by you, with the arithmetic shown:
- Any false positive you could turn into a `.hygieneignore` path regex, and the
  regex:
- Any finding you judged wrong once you had read it closely, and why:

### Cleanup performed

Say "none" when the answer is none. That is a result, and so is "reviewed and
kept every comment".

- What was changed: comments deleted, constraints moved into a test or a type, a
  document written so a reference resolves, prose moved out of the repository,
  files exempted.
- How many files, and in how many commits:
- Who reviewed the change and whether they agreed with the deletions:
- What was **not** cleaned up, and why (for example, a comment that is a genuine
  explanation of a mechanism):
- Time spent, if you tracked it, as a range rather than a precise figure:

### Token counts, when actually measured

Only fill this in if you measured it. Do not estimate from file size, count
characters, or assume a tokenizer's behaviour: a converted number is a claim
nobody can check. If you measured it, name the measurement.

- Measured? yes / no / not measured
- What was counted (instruction files only, instruction files plus the residue
  that was removed, a whole prompt):
- How it was counted (tool and version, or the command):
- Before, after, and the difference:
- What the measurement does not include, since context is assembled per session
  and a file on disk is not a session:

### Observed workflow change

- Did the gate change what anyone did, or was it ignored?
- Did a commit get rejected, and what happened next? A rewrite of the message, a
  fix to the comment, or `HYGIENE_SKIP=1`?
- Was `HYGIENE_SKIP=1` used, and about how often?
- Did anyone other than the author have to configure `core.hooksPath`?
- Would you keep it installed? What would make you uninstall it?

### Limitations

- What this study is one sample of, and what it cannot establish about other
  repositories:
- Which findings a reviewer did not look at:
- Anything about the scan that made the result easier or harder to interpret:

### Attribution and consent

- How you want to be credited: a name, a handle, a link, or anonymous.
- Confirm the text and any examples are safe to publish, and that you are happy
  for it to be edited for length with the meaning kept.

---

## What happens to a submission

1. It is read as a bug report about the tool as much as a result about the
   repository. A false positive usually becomes a benchmark case or a pattern
   fix.
2. If any part is unclear, you will be asked rather than guessed at. The study is
   not edited to make the tool look better; it is edited for length and for
   anything identifying.
3. Nothing is published until you say so, and it is removed on request.

## What is not a case study

- A scan output on its own. That is a useful [scan
  report](public-beta.md#how-to-send-one) and it belongs in the feedback issue
  template, not here.
- A number with no repository behind it, which is a claim rather than a result.
- A study that reports only the good part. The limitations section is not
  optional, and "we uninstalled it" is a result worth publishing.
