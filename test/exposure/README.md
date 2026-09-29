# Exposure fixtures

One synthetic repository per agent tool, plus one that is deliberately
ambiguous. Together they are the evidence that `hygiene exposure` classifies a
path by what the tool's own documentation says and by nothing else.

    hygiene exposure --tool <tool> test/exposure/<repo>

`expected.tsv` is the assertion list: one row per (repository, tool, path)
triple, giving the loading surface the report must return and the verdict for
the first finding in that file. The fixture section of `test/run` copies each
repository to a temporary directory and walks the file. Nothing here is checked
in prose alone: a row that stops passing fails the suite.

| column | meaning |
| --- | --- |
| `repo` | directory beside this file |
| `tool` | the `--tool` value to run with |
| `path` | repository-relative path, relative to the fixture repository |
| `surface` | `automatic`, `configured`, `referenced`, `unknown`, or `not-listed` |
| `exposure` | `likely exposed`, `loading unknown`, `stored`, `none`, or `-` |

`not-listed` means no surface file names the path and it holds no finding, which
is the answer for most files in most repositories. `none` means the file must
hold no finding at all. `-` asserts the surface only, for a file no finding can
sit in.

## What each repository is for

- `claude-code/` — project instructions, a nested import, a scoped rule, a rule
  with no frontmatter, and a prose file on no documented surface.
- `cursor/` — a rule of each activation mode, a plain `.md` in the rules
  directory, a `.cursorrules`, and a `CLAUDE.md` the rules reference does not
  mention. All three of the last are paths the documentation names only to
  exclude, so a finding in one is `stored` with the reason beside it.
- `codex/` — an `AGENTS.override.md` beside the `AGENTS.md` it displaces, and a
  nested one. The displaced file is reported as `unknown`: the documentation
  says Codex includes at most one file per directory.
- `copilot/` — the repository-wide file, a path-specific file with and without
  `applyTo`, and a `CLAUDE.md` that is an alternative to `AGENTS.md` rather
  than a second surface.
- `generic/` — the shared instruction file only, so a repository can be
  reported on without asserting anything about a private tool.
- `ambiguous/` — a repository holding both instruction files in one directory,
  which is the case where a tool's documentation decides and a guess would not.

Rows with a tool that differs from the repository's name check that no tool's
surfaces leak into another's report: a `.cursor/rules` file is on no Codex
surface, and a `CLAUDE.md` is on no generic one.

## Adding a fixture

1. Add the repository directory with the files the case needs.
2. Add its rows to `expected.tsv`.
3. Run `./test/run`. A row that fails is either a bug in the model or a wrong
   expectation; decide which before changing either.

Planting a finding in a fixture is what makes the verdict checkable, and every
sentence used for that is an argument-residue sentence from
`benchmark/cases/`. The fixtures are not scored by the benchmark: the corpus
there is a separate, reviewed set.
