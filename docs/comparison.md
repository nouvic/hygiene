# Hygiene, ctxlint, and agnix

Three tools work on the material a coding agent reads. They do not do the same
thing, and this page exists because a table that says they overlap invites the
question of which one to use. The answer is scope, not superiority: each of the
three reads a different part of a repository, asserts a different kind of claim,
and can be run next to the other two without contradicting either.

## What this page is, and what it is not

Every statement about Hygiene below is a property of its own code, its fixtures,
or its test suite. Every statement about ctxlint and agnix is quoted from those
projects' public documentation, retrieved on 2026-09-29:

- ctxlint, <https://github.com/YawLabs/ctxlint>
- agnix, <https://github.com/agent-sh/agnix>

Neither project was installed or run to write this page, so nothing here is a
measurement of them, and no accuracy, speed, or false-positive comparison
between the three exists. Where a claim comes from a project's own documentation
it is that project's claim, not an independently checked one. All three
capabilities pages change; follow the projects for their current state.

## The three scopes

| | Hygiene | ctxlint | agnix |
| --- | --- | --- | --- |
| Its own description | Governance hygiene for repos worked on by agents | Lint AI agent context files, MCP server configs, and session data against your actual codebase | Lint agent configurations before they break your workflow |
| What it reads | Source comments, repository prose, Git history | Context files, MCP configs, agent sessions, skills | Agent configuration files, skills, hooks, MCP configs |
| What it asserts | That a comment or prose passage carries instruction-like residue: a rule, a past disagreement, a reference to a document that does not exist, or a size signal | That a context file disagrees with the codebase, or that config and session data carry a documented defect | That an agent configuration is invalid or misleading, per documented specs and breakage patterns |
| Rule set | 6 rules in 5 categories | 43 context-file, 29 MCP, 13 session, and 5 skill rules across four open specs | 457 rules claimed, with per-tool prefixes such as CC-\*, CUR-\*, MCP-\*, AGM-\* |
| Runtime | Bash, Git, standard Unix utilities | Node, single self-contained bundle | Rust binary, also published to npm, Homebrew, pip, and Cargo |
| Network, keys, model | None; the scan is local and deterministic | No API key or model documented; `npx` fetches the package | No network, API key, or model documented for the linter |
| Writes | Never to the scanned tree; only a baseline or report you name | Reporting by default; `--fix`, `init`, and the `ctxlint_fix` MCP tool write | Reporting by default; `--fix`, `--fix-safe`, `--fix-unsafe` write |
| Report formats | text, JSON, SARIF | text, JSON, SARIF | terminal, GitHub annotations, SARIF |
| Strict mode | `--strict` exits 1 on a warning finding | `--strict`; non-strict always exits 0 | `--strict` |
| Editor and CI integration | GitHub Action, Git hooks | GitHub Action, pre-commit, MCP server, seven MCP tools | GitHub Action, VS Code, JetBrains, Neovim, Zed, web playground |

Two rows deserve a caution. "Writes" describes each tool's default and its flags,
not its safety: all three report by default, and the two that can rewrite files
do so only when asked. "Rule set" is a count, and counts are not comparable
across tools with different granularity, one of agnix's rules and one of
Hygiene's rules are not the same size of claim.

## Capability comparison

One row per capability, one support level per tool. Every ctxlint and agnix cell
is read from that project's public documentation, retrieved on 2026-09-29:
[ctxlint](https://github.com/YawLabs/ctxlint),
[agnix](https://github.com/agent-sh/agnix). Nothing in this table is a
measurement, and no project was installed or run to write it.

| Capability | Hygiene | ctxlint | agnix |
| --- | --- | --- | --- |
| Primary object inspected | Instruction-like residue in a repository: source comments, repository prose, Git history | Agent context files, MCP configs, sessions, memory, and skills, against the codebase | Agent configuration files, against published specs and known breakage patterns |
| Instruction-like text in source comments | Supported (`HYG-GOV-001`, `HYG-ARG-001`, `HYG-PHA-001`) | Not currently supported | Not currently supported |
| General repository prose | Supported (`HYG-ARG-002`, `HYG-VOL-001`) | Partial (the context files it lints are Markdown; repository prose in general is not its object) | Partial (agent instruction files such as `CLAUDE.md` and `SKILL.md` are Markdown; other prose is not its object) |
| Explicit agent instruction files (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`) | Partial (read as prose for argument residue, and modelled by loading surface in `hygiene exposure`; no validity check) | Supported | Supported |
| Git history | Partial (reports prose deleted from the tree that remains retrievable; no path repair) | Partial (documents Git history for `--fix` path repair and rename detection) | Not currently supported |
| Agent configuration schemas: hooks, MCP configs, frontmatter | Outside scope | Supported (MCP configs, frontmatter) | Supported (hooks, MCP configs, per-tool config files) |
| Session data | Outside scope | Supported (reading sessions is opt-in because it leaves the project tree) | Not currently supported |
| Memory data | Partial (gating lives in the optional Claude layer, not in the scan) | Supported (staleness, duplication, caps) | Partial (validates Claude memory and instruction files with `CC-MEM-*` rules; no session or autonomous memory-store audit is documented) |
| Deterministic and offline operation | Supported (Bash and Git; `./test/invariants` fails the build if a network primitive enters the executable surface) | Partial (no model call or network access documented for the checks; no determinism statement published, and `npx` fetches the package) | Partial (no model call or network access documented for the linter; no determinism statement published) |
| Runs with no runtime beyond the OS, Bash, and Git | Supported | Not currently supported (Node) | Not currently supported (a Rust binary, with npm, Homebrew, pip, Cargo, and prebuilt distributions) |
| Emits a structured document | Supported (JSON, SARIF) | Supported (JSON, SARIF) | Partial (SARIF is supported; JSON output is not documented in the retrieved sources) |
| Rewrites files (autofix) | Not currently supported (a comment is a human judgement, so nothing is rewritten) | Supported (`--fix`, `--fix-dry-run`) | Supported (`--fix`, `--fix-safe`, `--fix-unsafe`) |
| Enforces at commit or CI time | Supported (Git hooks, GitHub Action) | Supported (pre-commit, GitHub Action) | Supported (pre-commit, GitHub Action) |

How to read the levels:

- **Supported** means the project documents the capability and ships it.
- **Partial** means the project covers part of it, or the retrieved
  documentation does not establish the whole of it. If you need the whole of it,
  read the linked project rather than this table.
- **Not currently supported** means no documentation or implementation of the
  capability was found in the sources retrieved on the date above. That is a
  statement about those sources, not a promise about the project. The projects
  change; follow the links.
- **Outside scope** means the project's own stated scope leaves the capability
  out. It is not a defect, and nothing here says otherwise.

The first row names each project's scope rather than carrying a support level,
because it is the row the other twelve are read against.

Three rows are worth a note, since a label alone hides the reason:

- **Explicit agent instruction files.** This is where the two projects are
  strongest and Hygiene is deliberately weakest. They validate the file; Hygiene
  asks a different question about the words in it. `hygiene exposure` models
  which files a tool's own documentation says it loads, and it models six tools.
- **Git history.** All three rows are Partial for different reasons, and none of
  them is the same check. Hygiene reports deleted prose that is still
  retrievable; ctxlint repairs a broken path by looking for the rename; agnix
  documents no history use. A repository can use all three.
- **Determinism.** Hygiene's is enforced rather than asserted: the scan and the
  hooks cannot reach the network, and a test fails if that stops being true. The
  other two publish no determinism statement, which is a gap in the
  documentation and not evidence of nondeterminism.

## Where they overlap

- **Instruction files.** ctxlint and agnix both reason about `CLAUDE.md`,
  `AGENTS.md`, skills, and MCP configuration. Hygiene reads those files as prose
  and reports argument residue in them (`HYG-ARG-002`) and, with
  `hygiene exposure`, which documented loading surface a file sits on. The
  overlap is real but the question differs: they ask whether a config is valid
  and whether it matches the codebase, Hygiene asks whether the words in it are
  a record of a disagreement or a rule nobody can check.
- **Stale references.** ctxlint's `paths` check and Hygiene's `HYG-PHA-001` both
  catch a reference to something that is not there. ctxlint does it across
  context files and MCP configs; Hygiene does it for a document cited from a
  source comment.
- **Token cost.** ctxlint has `tokens` and `tier-tokens` checks. Hygiene reports
  comment volume (`HYG-VOL-001`) as a size signal and makes no token claim at
  all.

## What Hygiene does that they document as out of scope

- Instruction-like residue in **source comments**. `HYG-GOV-001` reads `//` and
  `#` comments in code, not configuration files, for imperatives, ruling
  language, and authority claims.
- **Git-history residue.** `HYG-HIS-001` reports prose that is no longer in the
  tree but is still retrievable from history. Neither project documents that
  check: ctxlint uses Git history to repair a broken path during `--fix`, which
  is a different operation over the same input, and agnix documents no history
  use at all.
- **No runtime.** The scanner is Bash and Git, with no package manager, no
  install step, and no network access. That is a deliberate constraint rather
  than a feature comparison: a dependency-free scanner can run in a pre-commit
  hook and in a container with nothing added, which is what makes the commit
  hook practical.

## What they do that Hygiene does not

This list is longer, and that is the honest picture.

- **MCP configuration.** Both validate MCP servers: schema, security,
  deprecated fields, environment variables, duplicate entries. Hygiene has no
  MCP check of any kind.
- **Skills.** Both lint skill definitions, frontmatter, triggers, and orphaned
  skills. Hygiene does not.
- **Sessions and memory.** ctxlint audits agent session data and memory files,
  including staleness, duplication, and accumulation. Hygiene reports deleted
  prose in history and, in its optional Claude layer, quarantines agent memory;
  it does not audit a session.
- **Auto-fix.** Both can rewrite a broken path or config when asked. Hygiene
  never edits a file, on the grounds that a comment is a human judgement and the
  correct fix is to move the constraint somewhere that can fail. That is a
  position, not an advantage.
- **Breadth.** ctxlint documents 16 context-file clients and 8 MCP clients; agnix
  claims 457 rules across Claude Code, Codex CLI, OpenCode, Cursor, Copilot, and
  more. Hygiene has 6 rules and 5 exposure models, and is narrow on purpose.

## Choosing between them

The three-way distinction, stated plainly:

- **agnix** is for configuration validity: is this agent config well formed and
  non-misleading according to the specs and to known breakage patterns?
- **ctxlint** is for consistency between context and code, plus the session and
  memory data around it.
- **Hygiene** is for instruction-like residue in the places agents read but
  people forget they wrote: source comments, repository prose, and history.

They compose. A repository can run all three in one CI job, each with its own
gate, and the finding sets will not be identical because the inputs are not.
Nothing here says one of them subsumes another, and nothing here says Hygiene is
better at its scope than the others would be if they added it.

## Related

- [Context rot and instruction residue](context-rot-and-instruction-residue.md)
  describes the failure mode Hygiene is aimed at.
- [Context exposure](context-exposure.md) describes what Hygiene does and does
  not assert about which files an agent loads.
- [Benchmark](../benchmark/RESULTS.md) is the labeled corpus Hygiene is measured
  against, and the only measured numbers on this page.
