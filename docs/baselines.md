# Baselines

A baseline records the findings that exist now, so that a later run can report
only what is new. It exists for the repository that cannot fix everything at
once but still wants to stop the pile from growing.

    hygiene scan --write-baseline PATH    record what is there now
    hygiene scan --new --baseline PATH    report only what is not in it

Both paths default to `.hygiene-baseline` in the scanned directory.

## A baseline is written, never silently

`--new` without `--write-baseline` still writes nothing. The scanner's
read-only contract is intact: the only file Hygiene ever writes is the one you
name on the command line, and `--write-baseline` says so out loud on stderr
with the number of findings it recorded.

`--new` without a baseline is an error, not an empty baseline. An unreadable
or absent baseline that means "nothing is suppressed" would report every
existing finding as new, which is the opposite of what the flag is for. The
scanner exits 2 and says why.

`--new` and `--write-baseline` together are also an error. They are two
answers to the same question and neither order of operations is obviously
right.

## Matching is by fingerprint, not by line

The baseline file is tab-separated and carries a schema line:

    # hygiene baseline: schema 1
    # rule	fingerprint	file
    HYG-GOV-001	HYG-GOV-001:m:3212936031	src/legacy.ts

A finding is matched when its fingerprint is already in the file. The
fingerprint is:

- `RULE:m:CHECKSUM` for a finding attached to a line, where the checksum is
  taken over the matched text after trimming, dropping one leading comment
  marker, and collapsing runs of whitespace.
- `RULE:p:CHECKSUM` for a finding that belongs to a whole file, taken over the
  file path. Comment-volume findings have no line to hash, so the file is the
  thing that is baselined: adding comments to a file already carrying too many
  does not produce a new finding, which is the intent.

The consequence, and the reason it is not a line number:

| change | what happens |
| --- | --- |
| code above the finding is added or removed | line number moves, fingerprint does not, no new finding |
| the file is moved or renamed | a line finding's text is unchanged, so it still matches; a file-level finding does not, and reports as new once |
| the matched line is reworded | fingerprint changes, reports as new. This is deliberate: the text is what the rule is about |
| the finding is gone | nothing is reported. A stale baseline row is inert |
| a genuinely new finding appears | not in the baseline, reported |

The baseline is not garbage-collected. Rows for findings that no longer exist
stay until someone rewrites the file, because a row that no longer matches
costs nothing and rewriting a baseline automatically would hide the moment a
finding disappeared.

## The schema line

The first line names the schema version. A baseline written by a different
schema is rejected rather than interpreted, because the fields moved between
versions is exactly the kind of silent misreading a schema line prevents. The
scanner tells you the version it found and the version it wanted, and exits 2.

Fingerprints are checksums of text, not cryptographic digests. They are
designed to be stable and cheap on a machine that has nothing installed, not
to resist an adversary. A baseline is a local convenience, not a security
control.

## Baselines and .hygieneignore are different tools

They are easy to confuse because both reduce what is reported. They act at
different stages and mean different things.

| | `.hygieneignore` | a baseline |
| --- | --- | --- |
| what it says | do not look here at all | this was already there when we started |
| scope | path patterns | individual findings, by fingerprint |
| written | by hand, into the repository | by `--write-baseline`, usually once |
| applies to | every run, always | only runs given `--baseline` |
| a new finding matching it | never reported | reported |
| the right use | generated code, fixtures, translations — a path class where prose is not authority | an existing backlog you intend to shrink |

Ignoring a path is a statement about the path. Baselining a finding is a
statement about a moment in time. A path that should never be scanned belongs
in `.hygieneignore`, which is checked into the repository and reviewed like
code. A backlog belongs in a baseline.

Baselines do not accumulate silently into an ignore list. Because they only
apply when `--baseline` names them, a repository can keep one and still see
everything with a plain `hygiene scan`.

## In CI

    hygiene scan --new --baseline .hygiene-baseline --format sarif > hygiene.sarif

reports only what this change introduced. The log still explains the
suppressed count in `baseline.suppressed`, so a reader can tell the difference
between a clean repository and a repository with a large baseline.
