---
name: handoff
description: Write a location-free prompt for continuing the current repository in a new session. Use when the user says handoff, wrap up, continue next session, or requests a context reset. Keep projects strictly isolated; if the session involved multiple repositories and the target is ambiguous, ask the user to focus one workspace and invoke handoff again.
---

# Handoff

Write the next session's opening instruction, not a report of the previous session.
Preserve only intent that the repository and Git cannot reconstruct.

## Establish one scope

Resolve the current repository once:

```sh
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
git -C "$ROOT" status --short
git -C "$ROOT" diff --name-only HEAD
```

Use those commands only to verify that the intended work belongs to this repository. Do
not copy their paths, names, or branch into the handoff.

If there is no current repository, do not write a handoff. If the session involved more
than one repository and the target is not unambiguous from the current workspace, ask the
user to focus the intended workspace and invoke handoff again. Do not name the candidate
projects, write multiple handoffs, or carry work between them.

## Write only unrecoverable intent

Overwrite only `## Next` in the current repository's `CONTEXT.md`. Keep it short and
imperative. Include only:

- the unfinished outcome and the next action;
- an omission that was deliberate and still matters;
- a blocker or user decision that must be resolved before continuing.

Write nothing when Git and the artifact already reveal everything needed.

## Keep the handoff location-free

The containing repository supplies all identity and location. Never put any of the
following in the handoff:

- project, repository, client, product, or workspace names;
- paths, filenames, extensions, line numbers, links, URLs, or file identifiers;
- branch, worktree, remote, commit, issue, task, or external-system identifiers;
- another project's work, state, decisions, or existence;
- session history, completed-work inventories, rationale, disagreements, or rejected
  alternatives;
- machine-global state or instructions for another checkout.

Do not disguise forbidden location information with shortened paths or vague references.
Omit it.

## Shape

```markdown
## Next

Continue the unfinished false-positive fix. Confirm that removing an offending line is
allowed while inserting one remains blocked.

### Decide first

- Should the local-only specification material ship publicly?
```

Omit `Decide first` when no answer is required.

## Validate before writing

Reject the draft and rewrite it if any sentence:

1. identifies where the work lives;
2. identifies which project the work belongs to;
3. could cause a new session to open, inspect, or mention another project;
4. records information recoverable from the current repository or Git;
5. describes the previous session instead of instructing the next one.

If removing those sentences leaves no unrecoverable instruction, write nothing.
