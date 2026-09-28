# Security

## Reporting

Use GitHub's private vulnerability reporting (Security tab → *Report a
vulnerability*), not a public issue. One maintainer reads these; a response
within a week is the aim, and a resend after two weeks of silence is welcome,
not rude.

## What this tool is allowed to do

Hygiene installs code that runs at sensitive moments: git hooks run on every
commit, and the optional Claude layer runs on tool calls. The response-retry
hook additionally runs after every reply only when explicitly enabled.
The PreToolUse hooks see each tool payload — commands, paths, file contents —
and the rulings backtest reads your local session transcripts under
`~/.claude/projects`. That access is exactly why the tool holds a short list
of verifiable properties:

- **No network, ever.** Nothing in the executable surface opens a connection.
  `test/invariants` greps the surface for network primitives, locally and in CI.
- **No dependencies.** bash and git; the optional Claude layer additionally
  uses python3's standard library, from a named allowlist that
  `test/invariants` enforces. No package manager is involved anywhere, so
  there is no supply chain to attack.
- **Writes stay in known places.** `<repo>/.githooks/` plus one git config
  key on install; `~/.claude/hygiene/` and a key-preserving merge into
  `~/.claude/settings.json` for the Claude layer; the rulings file and its
  `hits.log`; quarantined candidates, exact approvals, and single-use markers
  below `~/.claude/hygiene/memory-control/`. Promotion writes only to the exact
  reviewed destination. `bin/scan` is read-only and always exits 0 — asserted
  in the test suite.
  The pre-commit hook uses a temporary directory for staged snapshots and removes
  it on exit. `CLAUDE_CONFIG_DIR` can select the Claude installation directory.
- **Hooks fail open.** Unreadable files, malformed regexes, unparseable
  stdin, an absent transcript, or a regex that blows past a hard matching
  deadline: exit 0. A safety layer that can wedge a session is worse than
  none.
- **Nothing updates itself.** Updating is `git pull` plus explicitly
  re-running the installers, so what runs on your machine is always something
  you chose.

A change that loosens any of these is a security decision, not a feature
request.

## Threat model, honestly

**Rulings are tripwires, not a sandbox.** An action ruling matches the
literal text of a tool call, so a semantically equivalent action written
differently — `cd ~/.claude && mkdir skills/x` against a ruling keyed to
`\.claude/skills/` — can pass. That is the design point: rulings catch an
agent drifting in good faith into a settled mistake. Against a genuinely
adversarial model they are no defence — such a model could as easily edit the
hook wiring in `~/.claude/settings.json`, which is an ordinary file write. If
your threat model is a malicious agent, you need OS-level sandboxing
underneath this tool, not more regexes in it.

**Persistence hygiene is also a tripwire.** Built-in auto memory is disabled;
candidate capture is inactive until exact, single-use promotion. Conceptual
candidates are fingerprinted to a project artifact and fail promotion if it
changes. The hook blocks direct memory writes, live control-record edits, and
unapproved broker calls, but it does not control provider-managed transcripts.
An obfuscated command, unknown write tool, subagent without inherited hooks, or
editable hook configuration can still evade it. Against that threat, put the
durable destinations and hook settings behind an OS sandbox or managed policy
that the agent cannot write.

`install-claude --harden` supplies the local sandbox half of that boundary for
Claude Bash subprocesses: fail closed if the OS sandbox is unavailable, disable
unsandboxed commands, and deny writes to live settings and control state. It is
opt-in because it changes how every Bash command runs. Managed hooks and managed
permission rules remain the stronger organization-controlled boundary.

**The rulings file is your own trust domain**, like a shell rc: only you and
your hooks write it. A pathological regex (catastrophic backtracking) is
surfaced at intake as evidence (exit 3), and if one reaches the file anyway
the hook's matching deadline makes it a miss instead of a hang.

**Response retries spend another model turn.** Claude Code invokes a Stop hook
after it has generated the answer. Blocking that Stop makes the conversation
continue; it cannot erase the generation that already happened, and an
interface may keep both answers visible. For that reason `install-claude` does
not register the speech-ruling Stop hook by default. `--response-retries` is an
explicit efficiency and presentation tradeoff, not a stronger security mode.

**Style guidance is advisory; file checks are deterministic.** Opt-in concise
guidance adds a small reminder before each prompt without calling a model or
retrying a response. The punctuation hook checks added text in direct file edits;
shell writes are checked when staged and committed in a project with the style
marker enabled. These checks do not erase existing text or police every response.

**The git hooks are bypassable on purpose.** `HYGIENE_SKIP=1` skips them.
They are collaboration guardrails, not access control, and pretending
otherwise would only hide where the real boundary is.

**Failed-commit guidance is context, not authority.** The optional
`PostToolUseFailure` hook adds a fixed, session-only diagnostic reminder after a
failed `git commit`. It does not inspect or store project content, write a marker,
run the scanner, or call a model. Claude Code may retain that reminder in the
current session transcript, like the failed command output beside it.

**Scanned repos are untrusted data.** `scan` and the git hooks read arbitrary
repo content with grep and awk and never execute or eval any of it. A crafted
repo can at worst distort its own report.

## What a good report looks like

The most valuable reports: anything that makes the tool break the property
list above; repo content that achieves code execution or an out-of-tree write
during scan, hooks, or install; a way past `test/invariants` that a reviewer
would plausibly miss; false negatives in the fail-open behaviour.

## Continuity

MIT licensed, deliberately small, no dependencies. If maintenance ever stops,
fork freely — the licence and the test suite are the succession plan.
