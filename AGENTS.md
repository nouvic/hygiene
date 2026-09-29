# AGENTS.md

## Which of these two jobs is yours

**Two different jobs bring an agent to this file. Decide which one is yours
before you follow anything below.**

**A. Install Hygiene into another repository.** You were asked to add Hygiene to
a project that is not this one. Continue to the installation instructions below
and follow them exactly.

**B. Work on Hygiene itself.** You are contributing to, fixing, or maintaining
this repository. This is a different job with different instructions.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) first. It is short, and it is the
  contribution guide.
- Run `./test/run` and `./test/invariants`. That is what CI runs.
- **Do not install Hygiene into this repository as part of a development
  task.** This repository is the tool, not a project that consumes it, and no
  change here should add, refresh, or re-commit `.githooks/`. The hooks that
  check contributions are a maintainer's local setup, described under House
  style in CONTRIBUTING.md, and they are not a change to commit.
- The installation instructions below are written for other people's projects.
  Do not follow them against this checkout.

---

# Installing this — instructions for an agent

You have been asked to install `hygiene` into a project. Follow these exactly.
Every command is non-interactive and safe to re-run.

## 1. Find this repo

You are reading `AGENTS.md` at its root. Call that `$HYG`.

## 2. Report before changing anything

```sh
"$HYG/bin/hygiene" scan /path/to/project
```

Read-only, always exits 0. **Show the output to the user before installing.** They
may not know their repo is affected, and the report is the reason to proceed.

## 3. Install

```sh
"$HYG/bin/hygiene" install /path/to/project
```

Copies `pre-commit`, `commit-msg`, the read-only `scan`, and `lib/patterns.sh`
into `<project>/.githooks/`, writes `.hygieneignore` if absent, and sets
`core.hooksPath`. Idempotent.

## 4. Verify

```sh
git -C /path/to/project config --get core.hooksPath    # expect: .githooks
cat /path/to/project/.githooks/VERSION                 # expect: a version string
```

## 5. Commit the hooks

They must be committed to reach anyone else who clones.

```sh
git -C /path/to/project add .githooks .hygieneignore
git -C /path/to/project commit -m "build: add governance hygiene hooks"
```

**The subject must be a conventional commit.** `commit-msg` is live from the moment
you install, so `chore: stuff`, `wip`, `update` or `Handoff: …` will be rejected —
including on this very commit. That is the hook working, not a failure.

## 6. Tell the user two things

- Anyone else cloning the repo runs `git config core.hooksPath .githooks` once.
  Git does not activate hooks on clone, by design. This cannot be automated away.
- `HYGIENE_SKIP=1 git commit …` bypasses one commit.

## Updating

Never automatic. When the user asks:

```sh
git -C "$HYG" pull
"$HYG/bin/hygiene" update /path/to/project
```

Re-run per project. `install` reports `updated 0.1.0 -> 0.2.0`, or says it is
already current. Then commit the changed `.githooks/` as in step 5.

## Removing

```sh
"$HYG/bin/hygiene" uninstall /path/to/project
```

Deletes `.githooks/`, unsets `core.hooksPath`, leaves `.hygieneignore`.

## Expected friction, not bugs

**A commit is rejected for a comment.** Working as intended. The comment contains a
rule, a ruling, or session/decision history. Move the constraint to something
that can fail — a check, a test, a type — and delete the comment. Do not reach for
`HYGIENE_SKIP`.

**A commit is rejected for its message.** Rewrite it as `type(scope): subject`.

**An existing file trips it.** Hooks inspect **staged** files only, so pre-existing
comments block nothing until that file is next edited. Fix them as you go.

**Prose is flagged wrongly.** `content/`, `locales/`, `i18n/`, `legal*`, conventional
test/fixture directories, `.test.*`/`.spec.*` files, and generated output are already exempt. Add a path
regex to `.hygieneignore` rather than weakening the patterns — and report it,
because a false positive is a bug here.

## What not to do

Do not edit `lib/patterns.sh` to make a commit pass. Do not set `HYGIENE_SKIP=1` in
the environment permanently. Do not add `.githooks/` to `.gitignore`. Each of those
silently disables the thing the user asked you to install.
