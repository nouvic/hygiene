# Capability and evidence map

This is the honest version of the pitch. It maps a symptom a developer reports
to the condition Hygiene actually looks for, to what the tool establishes when
it finds it, and to how strongly that is supported.

The rule is simple and it is enforced by reviewing this file: **a row may not
claim more than its evidence level carries.** Where the evidence is a single
project's experience, the row says so. Where the outcome depends on which tool
loads which file, the row says so. Where nothing here supports a claim, the row
says that too, and the claim does not appear anywhere else in the project.

Nothing in this map describes a model's context. Every condition below is a
property of the repository, and every check reads files or commits.

## The table

| Symptom or query | Stored repository condition | Hygiene signal or feature | Mechanism when loaded | What Hygiene establishes | What remains tool or task dependent | Evidence level | Supporting source or reproducible test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| "Claude Code is getting sloppy" | Instruction-shaped comments and prose accumulate and stay in the tree | `hygiene scan`; `HYG-GOV-001`, `HYG-ARG-001`, `HYG-ARG-002`, `HYG-PHA-001` | A matched line travels with the file, so anything that loads the file reads it: input tokens, and text shaped like a directive | That the material is present, with a file and a line, under fixed patterns and exemptions | Whether any agent loads that file, and whether the text changes a reply or a patch | MECHANICAL FACT; REPRODUCIBLE HYGIENE TEST | `lib/findings.sh`; `benchmark/cases.tsv` (governance, argument-residue); `./test/run` |
| "The agent ignores `CLAUDE.md` or `AGENTS.md`" | The file mixes current directives with stale ones, or a comment cites a document that is gone | `hygiene exposure --tool <name>`; `HYG-GOV-001`, `HYG-PHA-001` | Two directives with equal standing compete inside one loaded context, and a citation points at a source that cannot be consulted | Which stored findings sit in a file that tool's own published documentation says it loads, and which cited documents do not exist | Retrieval, attention, and adherence. Hygiene does not observe a model's context or behaviour, so it cannot show why an instruction was not followed | MECHANICAL FACT; REPRODUCIBLE HYGIENE TEST. That this residue *causes* the ignoring is NOT ESTABLISHED | `bin/exposure`; [context exposure](context-exposure.md); exposure cases in `./test/run` |
| "The agent repeats an approach the team already ruled out" | A comment (`HYG-ARG-001`) or a prose passage (`HYG-ARG-002`) that records a past disagreement | `hygiene scan`; `HYG-ARG-001`, `HYG-ARG-002` | A record of what happened reads as a standing position, so a later reader inherits an argument they were not part of | That the record is stored in this repository, at a file and a line | Whether the record is loaded, and whether a reader treats it as binding, ignores it, or treats it as history | REPRODUCIBLE HYGIENE TEST; FOUNDING CASE OBSERVATION for the effect on a project | `HYG-ARG-001`, `HYG-ARG-002` in `lib/rules.sh`; argument-residue in `benchmark/cases.tsv`; the known false positive at `docs/DESIGN.md` in [benchmark/README.md](../benchmark/README.md) |
| "The agent refers to deleted architecture" | A source comment cites a document the tree does not contain | `HYG-PHA-001` | The citation keeps pointing at authority nobody can consult, and a reader either chases it or supplies content for it | That the cited path does not resolve by basename anywhere in the tree at scan time | What a reader does with a dangling citation. Resolution is by basename and is not a link resolver, so a section reference or an external URL is not modelled | REPRODUCIBLE HYGIENE TEST | `HYG-PHA-001`; its stated limits in `docs/rules.md`; the phantom-reference rows in `benchmark/RESULTS.md` |
| "The docs link to files that were moved or deleted" | A Markdown destination, a documented local import in an agent instruction file, or a path-valued agent configuration entry names a repository path that does not resolve | `hygiene scan`; `HYG-PHA-002` | The reference is resolved from the directory of the file that carries it, so a moved file leaves a reader, a tool that follows imports, or a permission expression pointing at nothing | That the reference does not resolve at the path it is written as, from the directory it is written in, inside the scanned root. A target outside the scanned root is outside this rule: it is not opened, not resolved and not reported, so a machine-specific path is neither cleared nor reported | Whether a reader or a tool follows the reference, and what it does when the target is absent. Resolution is textual and relative; a basename elsewhere in the tree does not satisfy it, and a symlink or a case-insensitive filesystem is seen as the local platform sees it | REPRODUCIBLE HYGIENE TEST | `HYG-PHA-002`; `lib/references.sh`; its stated carriers and limits in `docs/rules.md`; `md-pha-link-missing`, `md-pha-import-missing` and `md-pha-import-nested` against `md-clean-links` and `md-clean-agent-instructions` in `benchmark/cases.tsv` |
| "A file in the repository points at something that is not there" | A symbolic link in the tree whose target does not resolve | `hygiene scan`; `HYG-PHA-003` | A tool that follows the link reads nothing, or reads whatever now sits at that path; the link is stored in the repository and travels with it | That the link's target does not resolve, with the link path and the target text as written | Where the reader lands when the target is missing, and whether anything follows the link. The target is never opened, and nothing is written, deleted, or repaired | REPRODUCIBLE HYGIENE TEST | `HYG-PHA-003`; `hyg_findings_links` in `lib/findings.sh`; the symlink cases in `./test/run` |
| "My repository context keeps growing" | Prose is added and rarely removed; some documents only ever grow | The markdown line count and the monotonic-growth list in the text report; `HYG-VOL-001` for comment-heavy source files; `HYG-HIS-001` for prose deleted from the tree but still in history | Growth is additive, and every loaded line is a cost at the moment something loads it | Current size, which documents grew across at least three revisions without ever shrinking, and what was deleted but remains retrievable | Which of those files a given tool loads, and how much of each. The growth list and the line count are text-report signals with no rule identifier and do not appear in the JSON or SARIF output | MECHANICAL FACT; REPRODUCIBLE HYGIENE TEST | Sections 5 to 7 of `bin/scan`; `HYGIENE_MD_BUDGET` in `hooks/pre-commit`; `./test/self-scan` |
| "Context bloat is increasing token usage" | The counted volume of comments and prose that ships with the tree | `HYG-VOL-001` comment proportion; the markdown line count; the commit-time budget | Loaded text is input tokens, and model providers price input tokens by token, with premium long-context rates above a threshold | The cost mechanism, which is published by the providers, and the local volume, which is countable and comparable before and after a cleanup | How much of the tree a given tool loads, and the resulting bill. Cleaning a repository has no measured percentage saving here, and Hygiene states no such figure | MECHANICAL FACT for the pricing and the local count; TOOL-DEPENDENT for what is loaded; NOT ESTABLISHED for any savings figure | Anthropic and OpenAI pricing pages linked from the [README](../README.md); `bin/scan`; `hooks/pre-commit` |
| "Conflicting repository instructions" | Several directive-shaped statements in comments or prose, sometimes citing a document that is gone | `HYG-GOV-001` and `HYG-PHA-001`; `hygiene exposure` groups them by loading surface | Two directives with no expiry read as equally current, and the newer one is not marked as such | That more than one authority-shaped statement exists, and where each one sits | Which statement a reader follows. Matching is lexical: this is not a semantic contradiction detector, and it does not rank which directive is current | MECHANICAL FACT; REPRODUCIBLE HYGIENE TEST | "What every rule has in common" in [rules.md](rules.md); the `HYG-GOV-001` limits printed by `hygiene explain HYG-GOV-001` |
| "Autonomous memory keeps accumulating" | Durable memory carriers written without a review step | The optional Claude layer: quarantine, candidate-specific approval, promotion, and a `PreToolUse` hook that rejects direct writes to memory carriers | A memory carrier is loaded in later sessions, so an unreviewed entry becomes standing context instead of a note | That the broker exists, that direct writes to recognised carriers are rejected, and that an approval binds one immutable candidate to one destination, scope, evidence fingerprint, and expiry | The host. This is a tripwire and a broker rather than an OS sandbox, and an obfuscated write or an editable hook configuration can evade it. The read-only scan does not cover memory carriers at all | REPRODUCIBLE HYGIENE TEST for the broker; EXTERNAL EMPIRICAL EVIDENCE for reported accumulation | `./install-claude`; `claude/pretooluse-persistence.py`; the installer and broker cases in `./test/run`; the memory-governance report linked from the README |
| "A comment is acting like permanent policy" | An imperative or authority-shaped source comment | `HYG-GOV-001` | The comment travels with the code, carries no expiry, and is read as context by anything that loads the file | That the comment matches the rule, ruling, or document-reference shapes | Whether a reader treats it as policy. The rule's own limits say the match does not establish that the rule is wrong or that anyone obeys it | REPRODUCIBLE HYGIENE TEST | `HYG-GOV-001`; governance rows in `benchmark/RESULTS.md`; `hygiene explain HYG-GOV-001` |
| "How do I stop new instruction residue?" | New residue arrives with commits, and nothing inspects staged text | `hygiene install`: a `pre-commit` check on staged source comments and a markdown budget, a `commit-msg` Conventional Commit check, and a GitHub Action for the hosted side | The check runs before the commit exists, so the residue never reaches shared history | That the staged diff was inspected and the commit refused, with the file and the line; that the hook fails open when its own dependencies are missing | Activation is per clone, because Git does not run hooks on clone; a hosted CI service needs its own invocation; `HYGIENE_SKIP=1` bypasses one commit | REPRODUCIBLE HYGIENE TEST | `hooks/pre-commit`, `hooks/commit-msg`; [continuous integration](ci.md); [when Hygiene blocks](when-hygiene-blocks.md); hook cases in `./test/run` |

## What the evidence labels mean

- **MECHANICAL FACT.** A property of the code or of a published specification
  that can be confirmed by reading it or running it.
- **REPRODUCIBLE HYGIENE TEST.** A command in this repository that produces the
  same result for anyone who runs it, covered by `./test/run` or by
  `./benchmark/run`.
- **FOUNDING CASE OBSERVATION.** One project's experience. Hygiene came out of a
  repository where accumulated residue made later work harder to steer and
  cleaning it reduced that friction. That is an observation from one case, not a
  measured effect, and it is labelled as one.
- **EXTERNAL EMPIRICAL EVIDENCE.** A study or public report from outside this
  project. It supports the existence of a broader problem; it does not transfer
  its numbers to any particular repository.
- **TOOL-DEPENDENT.** The outcome depends on the agent, its tools, its
  configuration, or the task, and this repository cannot observe it.
- **NOT ESTABLISHED.** Nothing here supports the claim. Rows carrying this label
  are the reason the project does not make the claim.

## Claims this map does not support

These appear nowhere in the project as product claims, and this list is the
reason:

- That Hygiene reduces token cost by any specific percentage, in any repository,
  in general. No measurement of that exists here.
- That cleaning a repository eliminates context bloat, or that any tool can.
- That Hygiene fixes hallucination, makes a model more accurate, or makes an
  agent smarter. Nothing here measures model behaviour.
- That the scanner performs semantic reasoning or contradiction detection. It
  matches patterns in comments, prose, and commits.
- That Hygiene is the only tool in this area. It is not, and
  [comparison.md](comparison.md) names the others.
- That a scan result is a guaranteed recommendation to delete something. A match
  is a prompt for review, and the reasons are in [rules.md](rules.md).

## Keeping this map honest

Every Hygiene row above names a rule identifier, a benchmark category, a test,
or a linked document. `./test/invariants` fails when a rule identifier cited in
the documentation is not in the registry in `lib/rules.sh`, or when a registered
rule is missing from [rules.md](rules.md), so a claim here cannot outlive the
rule it points at.

Adding a capability to Hygiene means adding a row here. Adding a row here means
naming what it establishes and what it does not, and deciding which of the six
labels applies before the wording is chosen.
