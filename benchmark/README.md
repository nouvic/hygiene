# The detector benchmark

A labeled corpus, a runner, and a published result. The point is to be able to
say what the detector does to a specific set of examples, and to notice when a
change to `lib/patterns.sh` moves the numbers.

    ./benchmark/run              score the corpus against the labels
    ./benchmark/report           regenerate benchmark/RESULTS.md
    ./benchmark/run --no-gate    score without failing on a low result

`benchmark/RESULTS.md` is generated. Do not edit it: a hand-edited number is a
claim that nothing checks.

## What a case is

One file, one expected result. The expected result is either `clean` or a
comma-separated list of rule identifiers, because one file can legitimately
carry more than one thing worth reporting: a comment that cites a document
which does not exist is both governance and a phantom reference.

The files live at `benchmark/cases/`, at the path they would have in a real
repository, so path-based exemptions are exercised by the corpus itself rather
than by a stub. `benchmark/cases.tsv` is the manifest:

    id      a stable name for the case, unique
    expect  rule identifiers, or "clean"
    path    where the case sits, relative to benchmark/cases/
    family  the language or format the case is written in
    note    one line on what the case is and what it is testing

## How scoring works

Findings and expectations are compared as sets of `(case, rule)` pairs.

    true positive    a pair in both
    false positive   a pair the detector produced that was not expected
    false negative   a pair that was expected and did not appear

Precision is `TP / (TP + FP)`, recall is `TP / (TP + FN)`, reported per rule,
per category, and in aggregate. A rule that fires on three lines of one file
counts once for that file: the label says the file carries that kind of
material, and a reviewer can check that claim. It does not say how many times
it appears.

The gate is aggregate precision. Recall is reported and not gated, because the
choice at the detector is always the same one: a false positive is what makes
a scanner get uninstalled, and a miss is what it was built to find.

## Adding a case

1. Pick a family. The nine code families (TypeScript, JavaScript, Python, Go,
   Rust, Java, Ruby, Shell, YAML) each carry the same sixteen archetypes, and
   Markdown carries fourteen of its own. Keeping the archetypes parallel is what
   lets a per-family comparison mean anything.
2. Write the file the way a real file of that family looks. A Go comment has a
   `//` and a package clause; a YAML case is a real fragment of configuration.
3. Decide the expectation by reading it, before running anything. If you are
   unsure what a careful reviewer would say, the case is not ready.
4. Run `./benchmark/run`. If the detector disagrees, one of the two is wrong,
   and saying which one is the point of the exercise:
   - If the label is wrong, fix the label and say why in the note.
   - If the detector is wrong, fix `lib/patterns.sh` and check the other cases
     did not move.
   - If both readings are defensible, label both rules and say so in the note.
     `sh-arg-decision` is one of these: "we settled on Postgres" is a decision
     record and a statement that the matter is closed, so it carries both.
5. Run `./benchmark/report` and commit the regenerated `RESULTS.md` with the
   case.

Do not write a case to make a number move, and do not derive a label by
running the detector first. The corpus is the specification; a detector that
passes a corpus written to match it has been tested against itself.

## What the reference cases cover, and what they do not

`HYG-PHA-002` is scored on the two carriers the corpus can hold on its own: a
path written as a Markdown destination and a path written as a documented local
import, each in a file whose directory is the base a reader resolves it from.
`md-pha-link-missing` is the positive for the first carrier. `md-clean-links` is
its nearest negative: a resolving link, a fragment, a fragment on a resolving
link, an external URL, a mail and a data destination, a protocol-relative URL, a
placeholder, a glob, a destination in a code span, a destination in a fenced
block, and a link that climbs above the corpus root.

For the second carrier, `md-pha-import-missing` is the positive in a memory file
at the corpus root and `md-pha-import-nested` is the positive in a nested one,
whose import is joined from the directory it sits in before it is found missing.
Both files import a second path that does resolve, so a rule that read the whole
file as one reference, or that reported every token after an at-sign, is not
scored as correct by them. `md-clean-agent-instructions` is the nearest
negative: agent instructions carrying an address, a handle and an import that
resolves, none of them a finding.

Three things this corpus deliberately does not carry, each for a reason
recorded here rather than left to be inferred:

- **The settings carrier.** A path-bearing permission expression is read only in
  the two Claude Code settings files, which are one specific path each. A
  fixture a reader has to be told about to trust is written and asserted in
  `./test/run`, which builds one under a temporary directory. The corpus is a
  shared tree with no `.claude/` in it, and adding one would make every other
  case's path set depend on it.
- **`HYG-PHA-003`.** The run reports the rule as unscored rather than as a
  pass, because a symbolic link is not a file the corpus can hold: copying the
  corpus dereferences or drops it, and a link that survives the copy resolves
  differently depending on where the copy landed. `./test/run` builds links,
  including a loop and a broken one, and asserts the rule there.
- **The residue shape in an agent instruction file.** `md-clean-agent-instructions`
  covers current instructions in `AGENTS.md` and stays clean; the residue
  sentences, and the import grammar inside a memory file, are asserted in
  `./test/run` alongside it.

## Reviewing a case

A reviewer checks three things.

- Is the file plausible on its own terms? Open it and read it. A fixture that
  only exists to trip a pattern is visible immediately.
- Is the label what a careful reader would say? The negatives matter more than
  the positives here: product copy, legal prose, translations, test fixtures,
  dated incident notes, and real technical invariants all have to survive.
- Does the note say what the case is teaching? A case nobody can explain is a
  case a later change will quietly delete.

## Known false-positive classes

One case in the corpus is a false positive today, and it is left standing on
purpose.

- `docs/DESIGN.md` is a design document that explains why an alternative was
  ruled out. `HYG-ARG-002` fires on it, because the sentence records a
  rejection. `hyg_rule_limits HYG-ARG-002` names this class: a specification or
  a design rationale can legitimately describe a rejected alternative, and the
  match is lexical. Tightening the pattern far enough to exclude it would start
  losing the cases where prose really is carrying a disagreement, so the
  finding stays and the number stays honest.

A new known class goes here, in the same shape: name the case, say what fires
on it, say why it is left standing.

## Limits

- **The corpus is not a sample.** It is one instance of each archetype per
  family, written to be clear. Recall against it is an upper bound. It is not
  an estimate of what the detector finds in an unfamiliar repository.
- **Scoring ignores line numbers and counts.** A case scores the same whether
  the detector found the material once or five times.
- **`HYG-HIS-001` is not scored.** It needs Git history with a deleted
  document, and this corpus is a plain tree. The scanner's own tests cover it.
- **The corpus is scanned as a copy.** `benchmark/run` copies `cases/` to a
  temporary directory before scanning it, so a surrounding Git repository
  cannot change what is in scope, and `docs/ARCHITECTURE.md` resolves against
  the corpus alone. `benchmark/` is listed in `.hygieneignore` so that
  scanning the Hygiene repository itself does not read the fixtures.

## Deliberate dependencies between cases

Two, and both are load-bearing.

- Nine cases cite `docs/ARCHITECTURE.md` and expect governance only, which is
  the negative control for the phantom-reference check: the citation is real, so
  `HYG-PHA-001` must not fire. That file is supplied by
  `md-clean-architecture`, which is itself expected to be clean. Deleting or
  moving that case breaks the nine, so its note says so.
- `md-pha-link-missing` links two documents the corpus does not contain *and*
  two it does: `RUNBOOK.md` and `../assets/topology.png` are the ones that must
  fire. `md-clean-links` resolves every one of its destinations against
  `RUNBOOK.md`, `DESIGN.md` and `GLOSSARY.md`, supplied by `md-clean-runbook`,
  `md-clean-spec` and `md-clean-glossary`. Deleting any of those three turns a
  negative into a positive without touching the case that changed.
