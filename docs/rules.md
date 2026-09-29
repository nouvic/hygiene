# Rule identifiers

Every finding carries a stable identifier, so a baseline, a CI annotation, a
suppression, or a bug report can name the same thing across versions.

    HYG-<CATEGORY>-<NNN>

The category names the kind of condition that is stored in the repository, and
the number distinguishes the mechanisms inside it. Identifiers are never
reused and never renumbered. A rule that stops being reported is retired and
its number stays retired, because reusing it would silently re-point every
baseline and every issue that mentions it.

`lib/rules.sh` is the registry. It holds the identifier list and the text for
each rule: a title, a one-sentence explanation, why the rule exists, what it
does not establish, and safe remediation. `bin/scan`, `bin/explain`, and
`benchmark/run` all read it, so no two of them can describe a rule differently.
`hygiene explain RULE_ID` prints that text for one rule; with no argument it
lists every rule with its title.

## The rules

| identifier | category | severity | what it is |
| --- | --- | --- | --- |
| `HYG-GOV-001` | governance | warning | A source comment states a rule, a ruling, or an authority a reader is expected to obey. |
| `HYG-ARG-001` | argument-residue | warning | A source comment records a past disagreement rather than describing the code. |
| `HYG-ARG-002` | argument-residue | warning | Repository prose records a past disagreement rather than describing the system. |
| `HYG-PHA-001` | phantom-reference | warning | A source comment cites a document the repository does not contain. |
| `HYG-VOL-001` | prose-volume | info | A source file is mostly comment. A size signal, not a quality score. |
| `HYG-HIS-001` | history-residue | info | Prose deleted from the tree is still retrievable from Git history. |

## What every rule has in common

Each one describes a condition stored in a file or in history. None of them
describes a model's context, and none of them is evidence that a reader
loaded, followed, or was influenced by anything. A finding says the material
is there and that it travels with the code. What an agent did with it is not
observable from the repository, and Hygiene does not claim to observe it.

Each rule's own limits are part of the registry, not a footnote here. They are
read from the registry, and they say what the match does not establish:
that governance matching is lexical, that a phantom reference is resolved by
basename rather than by a link resolver, that a design rationale can share its
vocabulary with the residue patterns.

## Reading a finding

A finding names the rule, the file, the line when one applies, and the text
that matched. `HYG-VOL-001` is file-level and has no line: the condition is
about the whole file. The match field is narrower than the line when the rule
could point at the specific thing it saw, so `HYG-PHA-001` names the reference
it could not resolve.

## Adding a rule

Add a number to `HYG_RULES` in `lib/rules.sh`, then fill in the eight
functions for it: category, severity, title, message, name, why, limits, and
remediation. Give
it a case in `benchmark/cases.tsv` at the same time, with a hand-written label,
so the rule arrives with evidence rather than with an assertion.
