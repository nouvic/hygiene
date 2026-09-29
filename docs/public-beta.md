# The public beta

Hygiene is at v0.1.1 and in public beta. The tool works and is tested; what is
unproven is the **prevalence** of the problem it looks for and the **effect** of
cleaning it up. Those two things cannot be settled by writing more code, so the
beta is a request for evidence.

What the beta is trying to learn:

- How often instruction-like residue in comments and prose appears in real
  repositories, and in which languages and file types.
- How many of Hygiene's findings a careful reviewer judges true, and what the
  false positives have in common.
- Whether cleaning the findings up changes anything anyone can observe.

## How to send one

There is no form to fill in and no data leaving your machine unless you send it.
Three kinds of submission, in increasing order of value:

1. **A scan result.** One command's output, or even one line of it. Use the
   [scan feedback issue
   template](https://github.com/nouvic/hygiene/issues/new?template=scan-feedback.md).
   A clean scan is welcome: a repository where nothing fired is data.
2. **A false positive.** The single most useful thing you can report. [Open an
   issue](https://github.com/nouvic/hygiene/issues/new?template=scan-feedback.md)
   with the comment, the file extension, and what the comment actually does.
   False positives become benchmark cases and pattern fixes.
3. **A case study.** One repository's experience end to end, using the
   [template](case-study-template.md). Longer, and worth more, because it is the
   only shape that can say anything about cleanup.

An issue is public from the moment you open it. The only private channel this
project has is the one in [SECURITY.md](../SECURITY.md), which exists for
security reports; a scan result is not one, so the right move for something
sensitive is to reduce what you send until it is safe to post in the open, or to
describe the finding instead of pasting it.

## Anonymizing

You never need to send a repository, a URL, or access to anything. Hygiene runs
locally and reads locally, and nobody needs to reproduce your tree to act on a
report.

- Replace names with roles: a colleague becomes "a reviewer", a customer becomes
  "the account team".
- Keep the file extension, the rule identifier, and the shape of the comment.
  That is what makes a report checkable, and it is not identifying.
- Drop paths above the repository root, employer names, and hostnames.
- Keep only the example line you are comfortable publishing. One line is enough;
  a whole file is usually more than is needed.
- Do not send tokens, keys, internal URLs, or customer data, even redacted. If a
  finding is next to a secret, describe it instead of pasting it.

The raw JSON report contains file paths and matched lines. Read it before you
attach it, and if a finding near the top is sensitive, paste the individual rows
rather than the document.

## What Hygiene does not collect

- No telemetry. Nothing in this repository phones home, and no command makes a
  network request. `./test/invariants` enforces both with a tripwire that fails
  the suite if a network call is added to the scanner or the hooks.
- No automatic upload. A report goes to stdout or to a file you name.
- No account, no key, no license check, and nothing to sign up for.
- No repository access, ever, and no request to run anything on your machine.

## What happens next

1. A submission is triaged as a bug report about the tool first: a false positive
   is a defect in Hygiene, not in your repository.
2. Findings from feedback are added to the labeled corpus in `benchmark/` when
   they can be turned into a case that is not someone's private code, and the
   numbers in `benchmark/RESULTS.md` are regenerated from the corpus rather than
   adjusted by hand.
3. A case study is published only with your consent, credited the way you asked,
   and edited only for length and for anything identifying. It is removed on
   request, and issues you opened are yours to edit or delete.
4. If a finding is a genuine explanation rather than residue, the fix is to the
   detector, and the report is closed as fixed rather than as a disagreement.

## What the beta cannot settle

- Reports arrive because someone chose to send them, so the sample is not a
  prevalence estimate. It is a set of examples a reader can inspect.
- A result in one repository does not transfer to another, in a different
  language, with a different team and a different agent.
- Anyone who reports is more likely to be someone who cared enough to look, which
  is selection, not bias to be corrected for, just a limit to state.
