# Context exposure

    hygiene exposure --tool TOOL [path]
    hygiene exposure --tool TOOL --format json [path]

This command answers one question about the findings `hygiene scan` already
reports: is the file this finding is stored in on a loading surface that one
named tool documents? It is a sorting of stored findings by where they sit. It
is not a measurement of a session, and it never reports that an agent read
anything.

## The four surfaces

| surface | what it means |
| --- | --- |
| `automatic` | The tool's documentation says it reads this file without a per-run choice: at launch, from the working directory upward, or from the project root. |
| `configured` | This repository scopes the file, by a glob in its frontmatter, by the directory it sits in, or by the path a session is working under. |
| `referenced` | A file on one of the two surfaces above names this one through a documented import syntax. Reachable, not loaded. |
| `unknown` | Everything else. It is an answer, not a gap: nothing documented here establishes how or whether this file loads. |

The verdict a finding gets follows from that, and the three words are chosen
so that none of them is a claim about a running agent:

| verdict | surface | what it asserts |
| --- | --- | --- |
| `likely exposed` | `automatic`, `configured` | Documentation says a session of this tool loads this path. |
| `loading unknown` | `referenced`, or a rule the documentation describes that leaves the answer to the file | Something documented reaches it. Whether it loads is not established here. |
| `stored` | `unknown` | Nothing documented in this repository reaches it. |

The middle row is where a rule the agent decides whether to pull in lands, and
so does a file a sibling displaces and frontmatter that will not parse. In each
the documentation describes a rule that applies to the path and decides by
reading the file, so the reason beside the verdict is what tells a rule the
model chooses from a file nothing reads.

The last row is where two different things land, and the reason beside it is
what separates them. Most of the time nothing names the path at all. The rest
of the time the documentation names it only to exclude it: a plain `.md` in a
Cursor rules directory, a `.cursorrules`, a `CLAUDE.md` under a tool whose page
documents a different filename. Those are reported, as `unknown`, because a
reader who finds one wants to know why it is not a surface. The finding in such
a file is `stored`, which is what the documentation says about it.

`stored` is the important one. Most findings in most repositories get it, and
it is the reason the command is worth running: it separates residue that
merely exists from residue that a documented configuration pulls in.

## What is modelled, and where it comes from

Everything the command asserts about a tool is read from that tool's own
public documentation. Nothing is inferred from the tool's behaviour, from its
source, or from what a session appears to do. The tables are
`lib/exposure-surfaces.tsv` and `lib/exposure-limits.tsv`; the interpreter is
`lib/exposure.sh`.

### Claude Code

Source: **How Claude remembers your project**, <https://code.claude.com/docs/en/memory>.

- Project instructions load from `./CLAUDE.md` or `./.claude/CLAUDE.md`, and
  `./CLAUDE.local.md` loads alongside them, appended after `CLAUDE.md` at the
  same level. Files in the directory hierarchy above the working directory
  load at launch; files in subdirectories load when a file in them is read.
- `AGENTS.md` and `.claude/AGENTS.md` are read **only when no `CLAUDE.md`,
  `.claude/CLAUDE.md`, or `CLAUDE.local.md` exists in the working directory or
  above it**. When one does, the `AGENTS.md` is not read at all unless the
  **Project instructions** setting is changed. This is why the command reports
  an `AGENTS.md` as `unknown` when a project instruction file sits beside it:
  those two files in one directory is a real conflict, and the documentation
  says which one stops loading.
- `.claude/rules/*.md` is discovered recursively. A rule **without** a `paths`
  field loads at launch; a rule **with** one loads when Claude reads a
  matching file.
- If a rule's YAML frontmatter does not parse, the documented behaviour is to
  ignore the frontmatter and load the rule as though it had no `paths`. So an
  unreadable rule is reported as `automatic`, which is the documented
  fallback, not as `unknown`.
- Imports use `@path/to/file` inside a memory file, relative paths resolving
  against the file that holds the import, **recursively, to a maximum of four
  hops**, skipping markdown code spans and fenced code blocks. A path wrapped
  in backticks is text, not an import, which is why the parser strips code
  spans before it looks for `@` tokens.
- An import that resolves outside the working directory is external, and the
  first such import in a project prompts for approval. The command prints it
  as `referenced` rather than following it, because the documented state is
  "not loaded until approved".
- Documented and not modelled: user, project, and managed settings
  (`claudeMdExcludes`, `--setting-sources`, the **Project instructions**
  setting) can add or remove files from the surfaces above. Settings files are
  not read, and the report says so. `AGENTS.local.md` and `AGENTS.override.md`
  are documented as **not** read, so neither is listed.

### Cursor

Source: **Rules**, <https://cursor.com/docs/context/rules>.

- Project rules live in `.cursor/rules` and must use the `.mdc` extension. A
  plain `.md` file there is documented as ignored, so it is reported as
  `unknown` with that reason, and a finding in one is `stored` rather than
  assumed to load.
- Only the rules directory at the project root is modelled. The reference
  describes `.cursor/rules` and organizing rules into folders inside it, and
  says nothing about a second rules directory further down a tree, so a file in
  one is not called loaded. The report says a nested rules directory is present
  and unmodelled when it finds one.
- The frontmatter combination decides the mode: `alwaysApply: true` is
  included in every session; `alwaysApply: false` with `globs` is auto-attached
  when a matching file is in context; with only a `description` the agent
  decides; with neither, the rule loads only when `@`-mentioned.
- The last two are `unknown`, because in both the decision belongs to the
  model. A rule the agent pulls in when it judges it relevant is not a
  deterministic surface, and calling it loaded would be exactly the claim this
  command exists to avoid.
- A rule whose frontmatter cannot be read is `unknown`. Cursor documents an
  activation mode per frontmatter combination and no fallback for a file that
  cannot be read.
- `AGENTS.md` is supported in the project root and in subdirectories, with
  nested files applying when work is in that directory or below, and the more
  specific instructions taking precedence.
- `.cursorrules` is reported as `unknown`, and a finding in one as `stored`.
  The current rules reference does not mention the file at all. It is widely
  described elsewhere as deprecated, which is a reason to look, not
  documentation of what loads, so the command declines to say.
- A `CLAUDE.md` in the repository is reported the same way, for the same reason.
  The page documents `AGENTS.md` as the plain-markdown instruction file and does
  not mention this one, and a name that is not on the page is not a surface.
- Documented and not modelled: team rules and user rules, which live on
  Cursor's servers and in a home directory respectively, and so are outside any
  repository.

### Codex

Source: **Custom instructions with AGENTS.md**,
<https://learn.chatgpt.com/docs/agent-configuration/agents-md>.

- Discovery starts at the project root, typically the Git root, and walks
  **down to the current working directory**. In each directory it checks
  `AGENTS.override.md`, then `AGENTS.md`, then any names in
  `project_doc_fallback_filenames`, and **includes at most one file per
  directory**. An `AGENTS.md` sitting beside an `AGENTS.override.md` is
  therefore reported as `unknown`: the documentation says the second file is not
  reached, not that it is read second.
- Files are concatenated from the root down, so a file closer to the working
  directory appears later and overrides earlier guidance.
- Subdirectories below the working directory are not read, and neither is
  anything above the project root. A nested `AGENTS.md` is therefore
  `configured` and not `automatic`: it loads when the session is working there
  or below.
- The `AGENTS.override.md` file in the Codex home directory is read first and
  can replace what the repository describes. That directory is outside any
  repository and is not read by the command.
- Codex **stops adding files once their combined size reaches
  `project_doc_max_bytes`, 32 KiB by default**. A file can be on a surface and
  still be past the cap, so the report says so when it matters.
- `project_doc_fallback_filenames` lives in the user's own configuration, not
  in a repository. A repository that relies on it is under-reported, and the
  report says that too.

### GitHub Copilot

Source: **Adding repository custom instructions**,
<https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions>.

- `.github/copilot-instructions.md` is the repository-wide file.
- Path-specific instructions are `*.instructions.md` files inside or below
  `.github/instructions`, scoped by an `applyTo` glob in their frontmatter.
  Path-specific instructions are documented as reaching the cloud agent and
  code review. A file with no `applyTo` is `unknown`, because the pattern is
  what scopes it and there is no documented default.
- `excludeAgent` withdraws a path-specific file from `code-review` or
  `cloud-agent`. The command reads `applyTo` and not `excludeAgent`, so it
  reports such a file by its path and says so in the limits.
- `AGENTS.md` files are agent instructions, and the nearest file in the
  directory tree takes precedence. A single root `CLAUDE.md` or `GEMINI.md` is
  documented as an alternative to `AGENTS.md`; the command reports one as
  `unknown` when an `AGENTS.md` is present anywhere in scope, because the
  documentation presents them as alternatives rather than as a precedence
  order.
- Copilot reads instructions for code review from the **head branch of the
  pull request**, not from the branch a scan ran on. A report describes the
  tree it was run against.

### generic

The `generic` model covers `AGENTS.md` at the project root and in
subdirectories, per the format's own site, <https://agents.md/>. It exists so
that a repository using the shared instruction file can be reported on without
asserting anything about a specific tool's private surfaces. Every other
tool's own surfaces are out of scope for it by definition, and a file with no
surface is `unknown` rather than unexposed.

## Fail open

A configuration the command cannot parse is reported, never guessed at, and
never a hard failure:

- Frontmatter that does not open or does not close is `unknown`, with the
  reason stated in the row. Where a tool documents a fallback for unparseable
  frontmatter, that fallback is used and named instead.
- A path that cannot be resolved against a repository is printed as written
  and marked as resolving outside the tree, rather than silently dropped.
- A tool that is not one of the five is refused with a usage error before any
  scanning happens. There is no default tool, because the tools document
  different surfaces and a default would invent an answer for whichever one
  the user did not choose.
- Exit status is `0` for any report that ran. Only a usage error exits `2`.

## What this command is not

- It does not observe a session, read a model's context, or read a transcript.
  Every statement it makes is a property of a path in a repository.
- It does not read settings files, environment variables, or a home directory.
- It does not claim a file was loaded because the file exists, and it does not
  claim a finding was ignored because no surface reaches it. `stored` means
  nothing documented here reaches it, and a tool's undocumented behaviour is
  not something a scanner can see either way.
- It does not make network requests, install anything, or write anything. The
  suite asserts the read-only property by digesting the fixture tree before
  and after all five tools run.

## Adding a tool

1. Find the official documentation for the files the tool loads. Not a blog
   post, not a summary, not this document.
2. Add the tool to `HYG_EXPOSURE_TOOLS` in `lib/exposure.sh` and give it an
   entry in the usage text.
3. Add its rows to `lib/exposure-surfaces.tsv`, narrowest pattern first. The
   first row whose pattern matches wins.
4. Add its limitations to `lib/exposure-limits.tsv`. A limitation that is
   false for every repository makes a report longer without making it more
   accurate, so prefer a `present` row over an `always` row where the
   limitation only applies when a file is there.
5. Add a synthetic repository for it under `test/exposure/` and cases to
   `test/run`. The negative cases matter more than the positive ones: a file
   the command calls loaded when the documentation does not say so is the
   worst bug this feature can have.
6. Cite the documentation in this file, with a URL, and say what the page does
   and does not establish.
