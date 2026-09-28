# skills-library

Skills kept as files, not registered with the agent.

A registered skill costs context in **every** session — its name and description sit
in the roster whether or not it is ever used. That cost is O(n) in the number of
skills, and it is also an instruction surface: the agent reads those descriptions and
they shape what it considers doing.

A skill in here costs nothing until something reads it. Point an agent at the file,
or expose a single dispatch command; do not register one command per skill, which
rebuilds the roster under a different name.

| | |
|---|---|
| `handoff/` | write the prompt that starts the next session |
| `hygiene/` | scan usage, blocked-action protocol, rulings, and controlled memory |

## Using one

Two ways, and the right one depends on whether this repo lives at a stable path.

**Symlink — tracks updates.** Correct when you cloned to somewhere permanent, e.g.
`~/.hygiene`. `git pull` updates the skill everywhere, with nothing to re-run:

```sh
ln -sfn ~/.hygiene/skills-library/handoff ~/.claude/skills-library/handoff
```

**Copy — pins a version.** Correct when this checkout is a working directory that
may move or be renamed, or when you want the skill to stay put while you edit here:

```sh
cp -R skills-library/handoff ~/.claude/skills-library/handoff
```

A symlink into a directory you are still moving around will break silently — the
skill just stops existing. That is the only real trap.

Note the directory: `~/.claude/skills-library`, **not** `~/.claude/skills`. The
second is registered and appears in every session's roster. The first is inert
until something opens it, which is the entire point.
