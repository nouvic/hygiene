# When Hygiene blocks a commit

A block is a diagnostic result, not a request to find another route to the same
commit. Moving the text, changing a few words, unstaging the file, adding an
exemption, or switching tools preserves the underlying problem.

## The safe response

1. Read the category and every reported line.
2. Run the bundled project-wide scanner from the repository root:

   ```sh
   .githooks/scan .
   ```

   On an older installation without the bundled project scanner, use
   `~/.claude/hygiene/bin/scan .` and update the project hooks afterward.

3. Separate behavior from narrative:
   - Preserve behavior in code, a test, a type, or a check.
   - Remove dates, incident history, past-session narrative, and reader-directed
     rules when the artifact already proves the behavior.
4. Re-run the relevant tests, then scan and commit again.

The scanner is read-only and always exits successfully. It is safe to run without
changing the working tree. A repository-wide cleanup is a separate scope: show
the scan result and obtain approval before changing unrelated files.

## When it may be a false positive

Do not decide from the inconvenience of the block. Compare the exact line with
the category first.

It is probably a real finding when the line:

- tells a future reader what must never be changed;
- records session, argument, or decision history;
- explains that a rule exists because of earlier failures;
- repeats behavior already enforced by the surrounding test or code.

It may be a false positive when ordinary descriptive code happens to use the
same language. Stop before retrying and present the category, path, exact line,
and intended meaning to the user. If confirmed, add the narrowest path expression
to `.hygieneignore` and report the example upstream so detection can improve.

## Proxy profiles and missing protection

A shared `CLAUDE.md` supplies shared instructions. Hooks are registered separately
in `settings.json`. Check both symlink targets when using another Claude config
directory. Shared settings can point to the same installed Hygiene scripts.

From the project directory, `git config --get core.hooksPath` should report
`.githooks`, and `.githooks/pre-commit` should be executable. A directory containing
only Git's `*.sample` hooks provides no commit protection.

The governance PreToolUse hook covers `Write`, `Edit`, and `MultiEdit`. Shell writes
are not covered by that hook; the Git hook checks staged content regardless of
which tool wrote it. The persistence hook covers some recognizable shell writes,
but it is not comprehensive enforcement of governance comments.

The scanner includes tracked and untracked files, respects Git ignores for
untracked files, and applies Hygiene path exemptions. Findings need review:
uppercase words can describe domain behavior, and a regex match does not establish
that a comment is an instruction to an agent.

## Tests and hardcoded dates

A fixed date used to create deterministic fixture data is legitimate and is not
governance. Conventional `test/`, `tests/`, `spec/`, `__tests__/`, fixture, and
`.test.*`/`.spec.*` paths are exempt. ISO dates are ordinary data in production
code too, and never contribute to a Hygiene finding. If a dated comment is
blocked, some other instruction, authority, process, document-reference, or
conversation-residue pattern caused the finding.

Whether a fixture should instead use a controlled test clock is a test-design
decision, not something this governance hook should infer or enforce.

## About the bypass

`HYGIENE_SKIP=1` is a human-owned, one-commit escape hatch. An agent must not use
it autonomously, recommend it as the first response, or invoke it after a block.
Use it only after a person has reviewed the exact finding and deliberately chosen
to accept it.

## Agent decision table

| Situation | Next action |
|---|---|
| The reported line is clearly narrative or governance | Remove it while preserving behavior mechanically |
| The block suggests the problem exists elsewhere | Run `.githooks/scan .`, report the totals, and request approval before repository-wide cleanup |
| The classification remains uncertain | Ask the user with the exact evidence; make no alternative write |
| The same content could be moved or rephrased | Do not retry; that is a workaround |
| A person explicitly approves one bypass | Apply it once and report exactly what was bypassed |
