---
name: hygiene
description: Governance and persistence hygiene for repos worked on by agents. Use when the user says "run hygiene", "hygiene scan", or asks about comment governance, argument residue, project memory, persistence prevention, rulings, or the hygiene toolkit.
---

# hygiene

Hygiene keeps governance out of source code. Rules for agents belong in checks,
tests, and hooks — not in comments that future sessions read as standing orders.
This machine has the toolkit installed at `~/.claude/hygiene/`.

## Scan a project

```
~/.claude/hygiene/bin/scan [path]
```

Read-only: writes nothing, never fails a build, always exits 0. Defaults to the
current directory. The report covers:

- **comment density** — how much of the source is comment, with per-file outliers
- **governance in comments** — rules, rulings, dates, and doc references living
  in source comments
- **argument residue** — records of past disagreements left in the code
- **phantom authority** — assertions of authority inside code
- **markdown volume and monotonic growth** — instruction files that only ever grow
- **history** — commit subjects used as session bookkeeping

After a scan, report the findings and offer to clean the flagged lines. A real
constraint moves into something that can fail — a check, a test, a type. A date
or doc reference in a comment usually just comes out.

## When a hook blocks

Treat the category and reported lines as evidence. Do not relocate, reword,
unstage, exempt, or bypass the same material, and never use `HYGIENE_SKIP` on the
user's behalf.

After a failed Hygiene commit, run the repository's `.githooks/scan .` before
another commit. Report the totals. Preserve real behavior in code, a test, a
check, or a type; remove narrative rules, dates, and history. Obtain approval
before cleaning unrelated files found by the project-wide scan.

If the classification remains uncertain, stop and ask the user. Include the
category, path, exact line, intended meaning, and the choices: revise it, add a
narrow `.hygieneignore` entry, approve one human-owned bypass, or cancel. Do not
attempt an alternative write before the answer.

## Rulings

Permanent decisions only the user revokes, never loaded into context. Speech
rulings can be checked explicitly:

```
~/.claude/hygiene/bin/rulings              # list
~/.claude/hygiene/bin/rulings add "<text>" "<regex>"
~/.claude/hygiene/bin/rulings rm <n>
~/.claude/hygiene/bin/rulings test "<sentence>"
```

They are not enforced after every reply by default. A blocking Claude Code
Stop hook necessarily generates another model response and some interfaces
show both. The user may opt into that tradeoff by reinstalling with
`install-claude --response-retries`; common punctuation and style patterns are
poor candidates because they can retry most turns.

Scope writing-style checks to the artifact they govern. A punctuation rule for
sales copy, articles, or books does not govern ordinary session replies. Check
the finished artifact explicitly with `rulings test`, or put a deterministic
check in that content project's own workflow; do not turn it into a global
reply retry or an unscoped write blocker.

## Action rulings

Lines prefixed `never:` or `ask:` reach what the agent *does*. A PreToolUse
hook renders every tool call as text — tool name, paths, command, content —
and matches each action ruling's regex against the whole of it:

- `never:` — the call is blocked. The same result must not be sought through
  another tool; put the matter to the user.
- `ask:` — the call is held because the user did not ask for it this turn. Put
  it to the user with AskUserQuestion; a yes clears the way.

If the user's own last message matches the regex, the ruling stands down —
rulings restrain unrequested initiative, not requested work.

```
~/.claude/hygiene/bin/rulings add-never "<text>" "<regex>"
~/.claude/hygiene/bin/rulings add-ask "<text>" "<regex>"
~/.claude/hygiene/bin/rulings test-action "<text>"   # which mode would fire
~/.claude/hygiene/bin/rulings stats                  # real blocks per ruling
```

## Recording on the user's behalf

Every `add*` runs mechanical intake checks and exits 3 — recording nothing —
when the new ruling collides with an existing line or its regex looks too
broad (it matches the empty string, or would have fired repeatedly on the
user's own recent sessions). On exit 3 an agent must not pass `--force`; that
flag is for a human at a terminal. Instead, put the collision to the user with
AskUserQuestion — the new ruling beside the colliding line(s) or the breadth
evidence, with options to keep both, replace the earlier line (`rulings rm
<n>`, then re-add), or cancel — and act on the answer.

## Offering a correction as a ruling

When the user corrects course mid-session and the lesson is durable, judge
which bucket it belongs in:

- **enforceable preference** — expressible as one narrow, precision-safe regex
  over a reply or an action payload → offer it as a ruling. Show the exact
  line that would be written (mode, text, regex) via AskUserQuestion and
  record it only on a yes. A no, or a narrower regex, is a fine outcome.
- **project knowledge** — submit an inactive `hygiene memory propose` candidate.
  Never write a memory carrier directly or preserve who proposed, rejected,
  corrected, or agreed to it.

Rulings are machine-wide and enforced by hooks; memory is per-project text a
model merely reads. Prefer a ruling when the user's words widen the scope
("never…", "always…", "whenever you…") and the mistake would recur across
projects.

## Also installed here

- A PreToolUse hook that blocks Write/Edit calls writing governance into source
  comments. If an edit is blocked, do not work around it — move the constraint
  into a check or drop it.
- A second PreToolUse hook (matcher `*`) enforcing the action rulings above.
- A persistence PreToolUse hook (matcher `*`) that blocks conversational residue,
  every direct memory write, unapproved broker calls, control-record edits, and
  location-bearing handoffs before they reach disk. This skill only explains it.
- Git-level hooks are per-repo and vendor-neutral: from a checkout of the
  hygiene repo, `bin/hygiene install <repo>` (requires git).

Updating: the install copies files, so it does not track the repo checkout.
Pull the repo and re-run its `install-claude` to update this layer.

ISO dates are data, not governance, in both tests and production code. Test and
fixture paths are exempt, and dates never contribute to a Hygiene finding. If a
dated line is blocked, report the other pattern that actually caused it.

## Controlled project memory

Treat every correction as session-only. For a durable conceptual fact, propose
it with `~/.claude/hygiene/bin/memory propose concept`, including
`--evidence` and an in-project `--evidence-file`. For a repeatable procedure,
use `propose procedure` with `--verify`. Do not propose task state, branch state,
rejected approaches, conversation history, or an inference about user intent.

Batch review with the same broker's `review`. Before promotion, show
`memory show <id>` and
ask the user to approve that exact id. Only after the reply names the id, run
`memory approve <id> --to <carrier> --yes`, then use its hash once with
`memory promote <id> --approval <hash>`. A generic “yes” is not approval.
