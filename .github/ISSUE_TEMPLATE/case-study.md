---
name: Case study
about: One repository's experience with Hygiene, using the published template
title: "Case study: "
labels: ""
assignees: ""
---

Hygiene version and commit (`./bin/hygiene version`):
OS and `bash --version`:
The exact scan command line:
Attribution requested (name / handle / link / anonymous):

### Repository characteristics

Size, languages, history depth, team size, which agents and tools, which
instruction files, and whether Git hooks already blocked commits.

### Findings by rule

Counts as reported, plus one anonymized example line per rule that fired.

### Reviewed true and false positives

For each rule that fired: how many you judged true, how many false, and what the
false positives actually were. This is the most useful part of a case study.

### Cleanup performed

What was changed, how many files, who reviewed it, and what you deliberately did
not change. "None" is a result and is welcome.

### Token counts, when actually measured

Only if measured, with the tool and method. Write "not measured" otherwise; do
not estimate.

### Observed workflow change

Whether the gate changed anything, whether it blocked a commit, whether
`HYGIENE_SKIP=1` was used, and whether you would keep it installed.

### Limitations

What this single case cannot establish.

---

The full guidance for each section, and the placeholders, are in
[docs/case-study-template.md](https://github.com/nouvic/hygiene/blob/main/docs/case-study-template.md).
Read it before filling this in: a few fields have a preferred shape, and the
consent line at the end is required.
