# Hygiene

**Find stale instructions hiding in your AI-assisted repo.**

Hygiene is a free, local scanner for instruction-like source comments, records of
past disagreements, references to missing documents, and growing repository prose.
Optional Git hooks help keep new residue out of commits.

Bash and Git. No API key, model calls, telemetry, or package installation.

## Try a read-only scan

Download or clone this repository, open its directory, then run:

```sh
./bin/hygiene scan /path/to/your-project
```

The scan writes nothing and always exits 0. No hooks or agent settings are changed.
It prints candidate findings with file locations so you can inspect them locally.
For a small reproducible example, see the [demo](docs/demo.md).

```text
// Owner ruling: NEVER change this flow. See OLD-DESIGN.md
// The user rejected this approach twice.
```

These synthetic comments illustrate what Hygiene looks for. They can preserve a
conversation as apparent policy long after the surrounding code has changed.
Useful comments explaining a mechanism belong in the code; a match is a prompt
for review, not proof that a comment is wrong.

## Why this exists

This started with a frustrating experience: an AI-assisted project accumulated
notes and constraints that made later work harder to untangle. The question behind
Hygiene is simple: **what instructions has the repository accumulated?**

Source comments, documentation, and retrievable Git history can carry stale
context. Whether an agent reads or follows that material depends on its tools and
the task. Hygiene does not observe the model's context or diagnose its behavior.

There is evidence for the broader problem. A [Claude Code memory-governance
report](https://github.com/anthropics/claude-code/issues/34776) describes feedback
accumulating without expiry. An [ETH Zurich study](https://www.sri.inf.ethz.ch/publications/gloaguen2026agentsmd)
found no improvement in task success and over 20% higher inference cost from
context files in its evaluated settings. Neither establishes Hygiene's effectiveness;
that is what early real-world trials can help assess.

## What the scan reports

| Signal | Meaning |
|---|---|
| Governance in comments | Text resembling rules, rulings, or references to documents |
| Argument residue | Text resembling records of past disagreements |
| Phantom authority | Source comments referencing documents the scan cannot find |
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
does not make a hosted CI service enforce them. The scanner itself is informational.

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
