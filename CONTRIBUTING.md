# Contributing

MIT licensed. Contributions welcome, and the bar is low for two things in
particular: false-positive reports and new negative tests.

## How to contribute

Use an issue for bug reports, false positives, scan feedback, and feature
requests. For a code change:

1. Fork the repository and create a focused branch from `main`.
2. Make one coherent change and add the relevant positive and negative tests.
3. Run `./test/run` and `./test/invariants` locally.
4. Open a pull request describing the problem, the resulting behavior, and the
   commands used to verify it.

Contributors do not need, and are not given, direct push access to `main`.
Changes enter through reviewed pull requests after the required checks pass.

## Run the tests first

```sh
./test/run
./test/invariants
```

The precision suite has no dependencies beyond bash and git (the hook tests skip if
python3 is absent). It sandboxes everything under `mktemp -d` and refuses to write
outside it — an earlier version relied on a `cd` inside a subshell and committed
fixtures into the repo it was run from, which is why the guard exists.
`test/invariants` is the static half: it greps the executable surface for
network primitives and off-allowlist imports, and CI runs both on Linux and
macOS.

## The most valuable bug report is a false positive

Precision *is* the product. A scanner that flags an ordinary codebase gets
uninstalled the same day, and then nothing it catches matters. **A false positive
is a worse bug here than a miss**, and it is the one thing we cannot find without
you — we have a handful of repos, you have yours.

Open an issue with the flagged line, the file extension, and what the code was
actually doing. That is enough.

## Adding or changing a pattern

**Write the test first.** Every pattern change needs both:

- a **positive** test — the thing it should catch
- a **negative** test — the nearest ordinary code that must still pass

The negative is the one that matters. `never change this file` must be caught;
`a CDN outage can never block a deploy` must not. That pair is the whole design,
and `lib/patterns.sh` splits case-sensitive from case-insensitive matching
precisely to keep it — shouting is a signal, and `grep -i` destroys it.

If you cannot write a negative test that passes, the pattern is too broad.

## Scope — what belongs here

**Yes:** checks that can fail. Detection, enforcement, better precision, more
languages, more comment syntaxes, fewer dependencies.

**No:** rule packs, style doctrine, opinions about how anyone should write code.
This tool exists because agents accumulate rules faster than anyone deletes them.
A tool that ships its own doctrine to fix that is the disease wearing a helpful
face, and it is the single most likely way this project goes wrong.

If a proposed feature makes a repo carry *more* prose, it is probably out of scope.

## Security is scope too

This tool installs hooks that run on every commit and, in the Claude layer, on
every tool call — so its security promises are part of its scope, and they are
deliberately short and checkable (see `SECURITY.md`): no network, no
dependencies, writes only to its own paths, hooks fail open, nothing updates
itself.

**A PR that grows the tool's privileges is declined by default** — network
access, a new dependency, a new write path, a new hook event — whatever the
feature on top of it. If you believe an exception is warranted, open an issue
and make the case before writing the code.

Changes under `claude/`, `hooks/`, `lib/`, or the installers get the slowest
and most suspicious review, because that is where users are most exposed. A
small diff there is reviewable; a large one is a reason for closure, not a
harder review.

Vulnerabilities go through GitHub's private reporting, not public issues.

## AI-assisted contributions

Welcome — this project would be in a strange position minding them. The review
values your judgment, not your tool's fluency:

- **disclose it** in the PR description;
- **you must be able to explain and defend every line** without asking the
  tool, and review questions will assume you can;
- **keep the diff small enough to hold in one head** — one concern per PR;
- **bug and vulnerability reports must be reproduced by you** before filing,
  with the actual command and output.

Large undisclosed machine-written diffs and unreproduced vulnerability reports
are closed without detailed review. That is a review-bandwidth policy, not a
judgment of tools.

## Review pace

One maintainer, reviewing on the assumption that any PR could be hostile —
which is nothing personal; it is the correct assumption for a tool that
installs hooks. Expect days, sometimes longer. Boring, small, well-tested PRs
merge fastest.

Maintainer approval is required before merge. A passing CI run is necessary,
but it does not replace review of behavior, precision, or security impact.

## House style

The repo runs its own hooks. Install them and they apply to your contribution:

```sh
./install .
git config core.hooksPath .githooks
```

So: conventional commit subjects, no session handoffs in commit messages, and no
governance in comments. Comments explain what the code does. If you find yourself
writing a rule into one, that constraint wants a check instead.

POSIX-ish bash, no runtime dependencies for the git-level tooling. python3 is
allowed only in `claude/`, which is optional by design.

## Reporting the thing itself

If you ran `hygiene scan` on a real project, the numbers are useful even when
they are boring — especially when they are boring. "My repo came back clean" is
data. The claim that this is widespread is not yet established, and it should be
tested rather than assumed.
