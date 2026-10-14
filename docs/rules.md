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
| `HYG-PHA-002` | phantom-reference | warning | A document, an agent instruction file, or agent configuration references a repository path that does not resolve. |
| `HYG-PHA-003` | phantom-reference | warning | A symbolic link stored in the repository points at a target that does not resolve. |
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

## What HYG-PHA-002 reads

Three carriers, and nothing else. Each one is a place where the path is the
value of the construct, so the tool is reading a path rather than guessing at
one:

- **Markdown link and image destinations.** `[label](docs/design.md)` and
  `![alt](docs/diagram.png)`, including a destination in angle brackets, a
  title after the destination, and a `#fragment` or `?query` appended to a
  local file. Fenced code blocks and inline code spans are skipped. A reference
  in a `.rst` or `.txt` file is prose and is read for residue, but its links are
  not Markdown links and are not read.
- **Documented local imports.** The `@path` form in the instruction files whose
  own tool documentation gives an import syntax: the rows of
  `lib/exposure-surfaces.tsv` marked `imports=yes`. Which file answers is read
  from the table the same way every other surface is, by matching the
  repository-relative path against the pattern, so a nested memory file is
  answered by its own row rather than by the row naming the file at the root.
  Today those rows are `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`,
  `AGENTS.md`, `.claude/AGENTS.md`, and their nested forms, which the memory
  documentation gives the same import syntax. A backtick-wrapped filename in any
  other document is not an import and is not read.

  The token has to be shaped like a path as well as placed like one, because an
  at-sign also opens an address, a handle and a package scope, and ordinary
  prose is full of all three. A token is read when it starts where an import
  starts (not inside an address's local part), carries no second at-sign, and
  ends in a file extension: `@CLAUDE.md`, `@docs/rules.md` and `@./docs/rules.md`
  are read, while `@nouvic`, `@someone`, `@notes` and `@scope/pkg` are not. The
  cost is the extensionless import and the form whose spaces are
  backslash-escaped, and both are stated in the rule's own limits. No list of
  domains or platforms takes part in this: the question is where the at-sign
  sits, not who owns the domain after it.
- **Path-bearing agent configuration.** The permission expressions in
  `.claude/settings.json` and `.claude/settings.local.json`, such as
  `Read(src/**)` or `Read(/Users/you/project/docs/**)`. Only these two files and
  only this construct; a JSON string elsewhere in them is not treated as a path,
  however path-like it looks.

Resolution follows the path as written, from the directory of the file that
carries it — except a permission expression, which the tool resolves from the
project root, as it documents. `.` and `..` are normalized. A reference that
climbs above the scanned root is not resolved and not reported. A same-named
file in another directory does not satisfy a reference: `docs/old/design.md` is
not answered by `archive/design.md`.

An absolute destination is read in one of two ways, and the difference is
whether it names a file this repository holds.

- Under the scanned root: resolved like any other reference. A scan of
  `/Users/you/project` answers a link to
  `/Users/you/project/docs/design.md` the same way it answers `docs/design.md`,
  on any platform, and the two agree because the root is the base either way.
  A missing target here is a finding, the same as any other missing
  repository-relative reference.
- Outside the root: outside this rule. It is not opened, not resolved and not
  reported. That covers every absolute path above the root, whatever it is
  under, and every path written with a leading tilde, including a personal
  instruction file a tool documents for the user's own machine under
  `~/.claude`. HYG-PHA-002 asks whether the scanned repository holds and can
  deliver a path it stores, and a target outside the root is not a path that
  scan is entitled to answer for. Reporting one as missing would assert a
  resolution the scan never performed, and the answer would then depend on
  which files happen to exist on the machine that ran it. Nothing outside the
  scanned root is opened, so no arbitrary machine file is ever treated as
  evidence that a repository reference resolves.

An absolute string that was never a checkout path at all, such as the
`/api/reference`-shaped route in ordinary documentation, is not read and not
reported for the same reason.

Not read: `http`, `https`, `mailto`, `data` and protocol-relative destinations;
a fragment on its own; a glob; a placeholder or templating marker such as
`/path/to/project` or `{{repo}}`; a path that exists after the query and
fragment are removed; and an exempt or ignored path. The fragment and the
heading are not validated, only the file.

## What HYG-PHA-003 reads

Every symbolic link in scope, tracked or untracked-but-unignored, whose target
does not resolve. A valid link is not reported, whether it points at a file, a
directory, or another link. The test is whether the target resolves, the target
is never opened, and a link that resolves outside the repository counts as
resolving: the rule is about a link this repository cannot deliver, not about
where the target lives. A chain and a loop both terminate, because the
filesystem resolves them; a loop is reported as a link that does not resolve.
`readlink` supplies the target text for the `match` field. Where it is not
available the link is still reported and `match` is empty, which is the only
part of the check that depends on it.

## Reading a finding

A finding names the rule, the file, the line when one applies, and the text
that matched. `HYG-VOL-001` and `HYG-PHA-003` are file-level and have no line: the condition
is about the whole file. The match field is narrower than the line when the rule
could point at the specific thing it saw, so `HYG-PHA-001` and `HYG-PHA-002`
name the reference they could not resolve, and `HYG-PHA-003` names the target of
the link.

## Adding a rule

Add a number to `HYG_RULES` in `lib/rules.sh`, then fill in the eight
functions for it: category, severity, title, message, name, why, limits, and
remediation. Give
it a case in `benchmark/cases.tsv` at the same time, with a hand-written label,
so the rule arrives with evidence rather than with an assertion.
