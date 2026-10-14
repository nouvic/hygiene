# Hygiene

**Find stale instructions hiding in your AI-assisted repo.**

Hygiene is a free, local scanner for instruction-like source comments, records of
past disagreements, references and links that do not resolve, and growing
repository prose. Optional Git hooks help keep new residue out of commits.

Bash and Git. No API key, model calls, telemetry, or package installation.

## Is your coding agent getting sloppy or following old instructions?

Developers often describe the symptom before they know the cause:

- Claude Code or another coding agent appears to ignore `CLAUDE.md` or `AGENTS.md`.
- Cursor, Copilot, Codex, or another agent repeats an approach the team already rejected.
- An agent refers to deleted architecture documents or decisions that no longer apply.
- Repository instructions have grown into noisy, conflicting, or stale context.
- A long-running project feels affected by context bloat, context drift, or context rot.

Hygiene came from a real project where accumulated repository residue created
friction, context bloat, and unintended governance for later AI-assisted work.
Reviewing and cleaning that residue improved the workflow. The scanner tests for
the same stored conditions in another repository. When an agent loads governance
comments or stale repository prose, that material becomes input context: it
consumes tokens, contradictory statements create conflicting context, and
prescriptive comments can become unintended governance. What varies is which
material an agent loads and how strongly it affects a particular task.

See [Context rot, context bloat, and instruction residue](docs/context-rot-and-instruction-residue.md)
for the distinction and a practical diagnostic sequence.

## Problems Hygiene is designed to surface

Each row is a symptom people report, the stored condition Hygiene looks for,
and what a scan gives you back.

| If you observe | Hygiene checks for | Result |
|---|---|---|
| A coding agent is getting sloppy | Instruction-shaped comments and prose that travel with the files a tool loads | Findings with a file and a line to review, or a clean report |
| An agent ignores `CLAUDE.md` or `AGENTS.md` | Which instruction files a tool's own documentation says it loads, and what is stored in them | Stored findings sorted by loading surface, with a verdict per finding |
| An agent repeats an approach the team already ruled out | Comments and prose recording a past disagreement (`HYG-ARG-001`, `HYG-ARG-002`) | The record, located, so it can be deleted or left to Git history |
| An agent refers to architecture that was deleted | Citations in comments (`HYG-PHA-001`), and repository-local paths in Markdown links, agent-file imports and agent configuration that the tree does not contain (`HYG-PHA-002`) | The dangling reference, with the file it is written in and the line, before anyone acts on it |
| A file in the tree points at a path that is not there | Every symbolic link stored in the repository, tracked or untracked-but-unignored (`HYG-PHA-003`) | The link and the target it names. Nothing is read, followed, or repaired |
| Repository context keeps growing | Markdown volume, and documents that only ever grow | The size, the accreting files, and what was deleted but stays retrievable |
| Context bloat is raising token usage | How much comment and prose ship with the tree (`HYG-VOL-001`) | A count you can compare before and after a cleanup. No savings figure is claimed |
| Repository instructions conflict | Directive-shaped statements across comments and prose | Each one, with its location. Matching is lexical, not a contradiction detector |
| Autonomous memory keeps accumulating | Memory carriers written without a review step, via the optional Claude layer | Quarantine, and a candidate-specific approval before anything is promoted |
| A comment is acting like permanent policy | Imperative and authority-shaped source comments (`HYG-GOV-001`) | The comment, so the constraint can move to a check that can fail |
| New instruction residue keeps arriving | Staged source comments and a Markdown budget at commit time | A refused commit naming the file and line, before it reaches shared history |

Those rows are the short version. [Capability and evidence
map](docs/capability-and-evidence-map.md) has the same list with what each check
establishes, what stays dependent on the tool and the task, and the evidence
behind it, so a claim can be checked rather than taken on trust.

## Try a read-only scan

Download or clone this repository, open its directory, then run:

```sh
./bin/hygiene scan /path/to/your-project
```

The scan writes nothing and always exits 0. No hooks or agent settings are changed.
It prints candidate findings with file locations so you can inspect them locally.
For a small reproducible example, see the [demo](docs/demo.md).

For CI and other tools, the same scan emits a document:

```sh
./bin/hygiene scan --format json  /path/to/your-project
./bin/hygiene scan --format sarif /path/to/your-project > hygiene.sarif
```

Both keep stdout to the document alone and still exit 0 on findings. See
[Output formats](docs/formats.md) for the JSON schema and the SARIF mapping, and
`./bin/hygiene explain HYG-GOV-001` for what any single rule does and does not
claim.

A repository with an existing backlog can record it once and then report only
what is new:

```sh
./bin/hygiene scan --write-baseline /path/to/your-project
./bin/hygiene scan --new --baseline /path/to/your-project
```

`--new` without a baseline is an error rather than an empty baseline, so a
missing file cannot masquerade as a clean history. See
[Baselines](docs/baselines.md) for how a baseline differs from `.hygieneignore`.

A scan is a report, so it exits 0 whether or not it found anything. A build gate
needs the other behaviour, and that is the one flag that changes it:

```sh
./bin/hygiene scan --strict /path/to/your-project
```

`--strict` exits 1 when the report holds a warning-severity finding. Informational
findings (`HYG-VOL-001`, `HYG-HIS-001`) are size and history signals rather than
defects, so they are reported and the run stays green. A usage error still exits 2.
See [Continuous integration](docs/ci.md) for the GitHub Action and a complete
workflow.

```text
// Owner ruling: NEVER change this flow. See OLD-DESIGN.md
// The user rejected this approach twice.
```

These synthetic comments illustrate what Hygiene looks for. They can preserve a
conversation as apparent policy long after the surrounding code has changed.
Useful comments explaining a mechanism belong in the code; a match is a prompt
for review, not proof that a comment is wrong.

## Where a stored finding actually sits

A finding is a property of the repository, not of a session. To see whether the
file it sits in is one a tool's documentation says it loads:

```sh
./bin/hygiene exposure --tool claude-code /path/to/your-project
./bin/hygiene exposure --tool cursor --format json /path/to/your-project
```

`--tool` is required and takes `claude-code`, `cursor`, `codex`, `copilot`, or
`generic`. The report sorts stored findings by the loading surface that tool's
own public documentation describes, and gives each one a verdict: `likely
exposed`, `loading unknown`, or `stored`. Most findings in most repositories are
`stored`, and that is the point of running it.

The command is read-only, writes nothing, exits 0 for any report, and never
claims an agent read a file. See
[Context exposure](docs/context-exposure.md) for the surfaces it models, the
documentation each one is read from, and what it does not know.

## What the detector is checked against

The detector was run against a labeled corpus before it was published. Every
number is generated by `benchmark/run` and written by `benchmark/report`; none is
typed by hand, and CI fails if the committed results stop matching the code.

| measure | value |
| --- | --- |
| cases | 156 |
| expected (case, rule) pairs | 76 |
| precision | 98.7% |
| recall | 100.0% |
| release gate | at least 95% aggregate precision |
| gate | pass |

The labels were written by reading each case, before the detector ran on it, and
they live in `benchmark/cases.tsv` with the files. Regenerate with
`./benchmark/report`. Full tables by rule and by category are in
[benchmark/RESULTS.md](benchmark/RESULTS.md), and the method is in
[benchmark/README.md](benchmark/README.md).

What this establishes is narrow, and worth stating plainly: on 156 files written
to exercise the rules, the detector reported 77 (case, rule) pairs, 76 of which a
reviewer had independently labeled. It is not a claim about prevalence in real
repositories, and there is no claim here about what a scan saves in tokens. That
is what the [public beta](#help-with-the-first-public-beta) is for.

## Why this exists

This started with a frustrating experience: an AI-assisted project accumulated
notes and constraints that made later work harder to untangle. The question behind
Hygiene is simple: **what instructions has the repository accumulated?**

Source comments, documentation, and retrievable Git history can carry stale
context. Whether an agent reads or follows that material depends on its tools and
the task. Hygiene does not observe the model's context or diagnose its behavior.

The project that produced Hygiene is the first case observation: accumulated
residue made later AI-assisted work harder to steer, and cleaning it reduced that
friction. There is also evidence for the broader problem. A [Claude Code memory-governance
report](https://github.com/anthropics/claude-code/issues/34776) describes feedback
accumulating without expiry. An [ETH Zurich study](https://www.sri.inf.ethz.ch/publications/gloaguen2026agentsmd)
found no improvement in task success and over 20% higher inference cost from
context files in its evaluated settings. Those observations support further
testing; they do not establish the effect size across every repository or agent.

The cost mechanism itself is established: model providers charge for input tokens,
and longer relevant context means more input tokens to process. [Anthropic's pricing
documentation](https://docs.anthropic.com/en/docs/about-claude/pricing) defines
input-token and premium long-context rates, while [OpenAI's pricing](https://platform.openai.com/pricing)
also prices input by token. What Hygiene still needs to measure is how much scanned
residue actually enters each agent's context and how much a cleanup removes.

## What the scan reports

| Signal | Meaning |
|---|---|
| Governance in comments | Text resembling rules, rulings, or references to documents |
| Argument residue | Text resembling records of past disagreements |
| Phantom authority | Citations, links, imports and symbolic links that name something this repository does not contain |
| Comment and Markdown volume | A size signal, not a quality score |
| Monotonic growth | Documents with at least three revisions and no net-shrinking revision |
| Deleted documents | Prose still retrievable from Git history; not necessarily loaded by an agent |

Matching is heuristic, with a fixed set of source extensions and comment patterns.
It is not a language parser or a semantic contradiction detector. Findings can
overlap. A clean report means no matches under the current patterns and exemptions.

## Add commit checks when useful

After reviewing a scan:

```sh
./bin/hygiene install /path/to/your-project
```

The installer copies hooks and the scanner into `.githooks/`, creates
`.hygieneignore` if absent, and sets `core.hooksPath` to `.githooks`.
If your project already uses another hook setup, review that integration first:
this installer replaces the configured hook path and same-named hook files.

- `pre-commit` checks staged source comments and a Markdown budget.
- `commit-msg` requires a Conventional Commit subject such as `fix: handle empty input`.

Git hooks run on local commits. CI needs its own invocation; installing locally
does not make a hosted CI service enforce them. For the hosted side there is a
GitHub Action in this repository and a complete example workflow: see
[Continuous integration](docs/ci.md).

Commit `.githooks/` and `.hygieneignore` to share the checks. Each person cloning the
project activates them once with `git config core.hooksPath .githooks`.
`HYGIENE_SKIP=1 git commit ...` bypasses one commit.

For a blocked commit, see [When Hygiene blocks](docs/when-hygiene-blocks.md).

## Help with the first public beta

Try one scan on a repository you use with a coding agent. Tell us whether it found
something useful, flagged an ordinary comment, or came back clean. An anonymized
line and its file extension are enough; your repository can stay private.

The most valuable early result is a finding you can explain and act on.
The prevalence of this specific problem and the effect of cleaning it up are
still unproven.

Nothing is uploaded and nothing phones home: you send what you choose to send.
[The public beta](docs/public-beta.md) has the process, what to redact, and what
Hygiene does not collect. For a repository's experience end to end, there is a
[case study template](docs/case-study-template.md) with the fields that make a
result checkable, and "not measured" is a complete answer for any of them.

## Contributing

Bug reports, feature requests, false positives, clean-scan results, and focused
pull requests are welcome. Start with the [contribution and coding
guidelines](CONTRIBUTING.md). Changes to `main` go through review and CI.

## Related tools

[agnix](https://github.com/agent-sh/agnix) validates agent configurations, skills,
and hooks. [ctxlint](https://github.com/YawLabs/ctxlint) checks context against the
codebase and also audits session and memory data. There is real overlap.
Hygiene focuses on instruction-like residue in source comments and repository
prose, with a small Bash/Git scan-and-hook workflow.

| Tool | Primary scope | Runtime |
|---|---|---|
| Hygiene | Instruction-like comments, repository prose, unresolved references and links, and Git-history residue | Bash and Git |
| agnix | Agent configuration, skills, and hook validation | See the agnix project |
| ctxlint | Context-to-code consistency plus session and memory auditing | See the ctxlint project |

This comparison describes scope, not superiority. Features change, so follow the
linked projects for their current capabilities. [Comparison](docs/comparison.md)
adds what each project documents, what it does not, and which statements here
were checked against the projects themselves.

<details>
<summary>Optional Claude Code features: rulings, memory review, and style checks</summary>

These features are separate from the read-only scan and project Git hooks.
`install-claude` changes your Claude settings, including disabling built-in auto
memory. Read the feature descriptions and [security model](SECURITY.md) before
choosing this layer.

## Rulings — checking settled topics

The scanner and hooks above work on files. They do nothing about the other half
of this: an agent that keeps re-opening something you already decided, inside a
single conversation, where no file is involved.

Repeated or conflicting context may contribute to this behavior. Rulings provide
explicit pattern checks; they do not establish why a model produced a response.

A ruling is a decision **only you can revoke** — nothing external can make it
false. Hygiene checks a local ledger without injecting the full ledger into the prompt:

```sh
rulings add "never propose gates or blockers on placeholder content" \
            "(ship|launch)[ -]?(gate|blocker)"

rulings                      # list
rulings test "add a ship gate here"   # see what a sentence would trip
rulings rm 4
```

`rulings test` checks a draft or sentence without loading the rulings into the
model's context. Action rulings remain deterministic because they run before a
tool executes.

Response enforcement has a hard platform tradeoff. Claude Code's `Stop` hook
runs only after the reply is generated; blocking it means "continue the
conversation" and requests another model response. Some interfaces retain the
first answer, producing two visible answers and charging the tokens for both.
Hygiene therefore leaves response retries off by default.

If a corrected second response is preferable to a single violating response,
opt in explicitly:

```sh
./install-claude --response-retries
```

Use that mode for rare, high-impact speech rulings rather than common style
preferences. A pattern matching punctuation or ordinary prose can retry most
turns. Re-running `./install-claude` without the flag removes only Hygiene's
response-retry hook and preserves unrelated hooks.

**It only blocks unprompted mentions.** If you raise the subject yourself, the
agent answers normally.

## Short replies and punctuation

Writing preferences have a separate opt-in path from speech rulings:

```sh
./install-claude --concise --no-dashes
./bin/hygiene install /path/to/repo --no-dashes
```

`--concise` supplies a brief reminder before each prompt: one-sentence progress
updates and final replies of at most 120 words by default, expanding when requested
or needed for the deliverable. This guides generation; it is not a hard output cap.
It does not retry replies or load the rulings ledger into the conversation.

`--no-dashes` rejects newly authored lines containing em or en dashes in direct
Claude Write/Edit/MultiEdit calls. The project Git check catches added lines at
commit time, including writes made through a shell. Existing unchanged lines pass;
removing offending punctuation passes. Product copy and translations are included.
Tests, fixtures, generated output and dependencies are excluded. These are separate
style checks: `.hygieneignore` exempts governance findings, not punctuation.

The Claude switches persist as `HYGIENE_CONCISE` and `HYGIENE_NO_DASHES` in the
settings `env` object. Set either to `"0"` to disable it. The project switch lives
in the committed `.githooks/no-dashes` marker; remove that marker to disable the
project punctuation check. Plain reinstalls preserve these choices.

The installer respects `CLAUDE_CONFIG_DIR` and records absolute paths for the
shared rulings and memory store. If a launcher remaps `HOME`, it must explicitly
load the shared settings, for example `claude --settings /path/to/settings.json`.
A symlink at an otherwise undiscovered path does not make Claude load the file.
No nested configuration directory is needed for that explicit settings file.

Git checks read the index, so unstaged fixes cannot hide a staged violation and
unstaged text cannot block a clean staged version. Repositories already above the
Markdown budget may install and make changes without increasing that debt; further
growth above the budget is blocked. Existing content is not rewritten on install.

## Persistence — the part that stops the remembering

The optional Claude layer turns off Claude's built-in auto memory and replaces
autonomous publication with two separate steps: **capture** and **promotion**.
An agent may submit a conceptual fact or repeatable procedure as a quarantined
candidate. Candidates live outside the project tree, are never loaded into a
future session, and are separated by an opaque project key.

```sh
hygiene memory propose concept \
  --text "Cache keys include the locale." \
  --evidence "The implementation constructs locale-separated keys." \
  --evidence-file src/cache-key.ts

hygiene memory review
hygiene memory show 2f91a4c03b7e
```

Promotion requires a candidate-specific yes. The approval binds the immutable
candidate to one destination, scope, evidence fingerprint, and approval expiry.
Changing any of those invalidates it; the approval can be used once.

```sh
hygiene memory approve 2f91a4c03b7e --to MEMORY.md --yes
hygiene memory promote 2f91a4c03b7e --approval <the-returned-hash>
```

Corrections, task or branch state, rejected approaches, attributed user intent,
agent conclusions about intent, and argument history cannot enter quarantine.
They expire with the working context. Preferences and permanent policies go
through explicit rulings intake instead.

The `PreToolUse` hook rejects every direct write to a recognized memory carrier;
neither an explicit request nor clean-looking `Concept:` prose bypasses review.
It also blocks direct edits to live control records and requires the last user
message to name the exact candidate before approval or promotion. Handoffs remain
a separate carrier: explicitly requested, unfinished intent only, location-free.

The matcher is `*` so recognizable shell writes are covered alongside direct
file tools. This is still a tripwire and broker, not an OS sandbox: an obfuscated
command, unknown write tool, subagent path, or editable hook configuration can
evade it unless the host also makes durable memory and policy files physically
unwritable to the agent.

For the stronger local boundary, install with `./install-claude --harden`. It
enables Claude's OS-backed Bash sandbox in fail-closed mode, removes the
unsandboxed-command escape hatch, and denies subprocess writes to the live
settings and Hygiene control directory. Only the deterministic memory broker is
excluded so approved promotion can complete. This changes the security boundary
for every Claude Bash command on the machine; the normal installer leaves it off.

### Action rulings

Rulings can also reach what the agent *does*, not just what it says. Prefix a
line `never:` to block a matching tool call outright, or `ask:` to stop the
agent taking it *unrequested* — the action goes back to you as a question
instead of just happening:

```sh
rulings add-never "skills are not registered; skills-library only" '\.claude/skills/'
rulings add-ask   "global installs need a yes" "npm install (-g|--global)"
```

A `PreToolUse` hook matches the regex against the whole action — tool name,
paths, command, content — so a ruling written about file writes also catches
the same result attempted through the shell. The same stand-down applies: if
your own last message matches the regex, you asked for it, and the ruling
stays quiet. Same file, same authority, still never loaded into context, and
with an empty file the hook is inert — every rule it enforces is one you wrote.

Intake pushes back before recording: a duplicate or contradicting line, a
regex that matches the empty string, or one that would have fired repeatedly
on your own recent sessions is reported and refused (exit 3) with the
evidence. `--force` records it anyway — the file is yours. After that,
`rulings stats` counts real blocks per ruling, so an overbroad one shows up
as numbers rather than as a feeling.

### What is not a ruling

Titles, product concepts, storylines, logos, layout, copy — **content decisions**.
They land in the artifact and change constantly. Hardening one is how a nav CTA
ends up arguing with you the day you change your mind.

A ruling is about *who decides* and *what never gets raised*. If the world could
falsify it, it isn't a ruling — it's a fact that belongs in a check.

### Honest limits

Prohibitions get teeth: a hook can catch "you mentioned X." **Permissions can't** —
you cannot grep for the absence of hedging, so "stop hedging about placeholders"
stays advisory.

And matching is by regex, so it will occasionally catch a legitimate mention.
`rulings rm` is one line, deliberately — intake doesn't have to be perfect when
the wrong outcome takes two seconds to reverse.

</details>

## False positives

Product copy, translations, legal text, conventional test and fixture paths,
and generated output are exempt by default. `.hygieneignore` accepts path regexes
for additional governance exemptions. Report unexpected matches with an anonymized
line, file extension, and expected result. The optional punctuation check has
separate exemptions.

## Update or remove

Pull this checkout to update its source, then explicitly update each project:

```sh
./bin/hygiene update /path/to/your-project
./bin/hygiene uninstall /path/to/your-project
```

Nothing updates itself. Uninstall deletes the project's entire `.githooks/`
directory and unsets `core.hooksPath`; `.hygieneignore` remains.

## Requirements and status

v0.1.1, MIT licensed. The core uses Bash, Git, and standard Unix utilities.
The optional Claude layer and punctuation checker use Python 3.
The CI configuration targets macOS and Linux; native Windows compatibility is
not established.

Run `./test/run` and `./test/invariants` for local checks.
See [Contributing](CONTRIBUTING.md) and [Security](SECURITY.md) for details.
