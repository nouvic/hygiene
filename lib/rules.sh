#!/usr/bin/env bash
# The rule registry. Sourced by bin/scan, bin/explain and the benchmark.
#
# Rule identifiers are stable and are never reused. The shape is
# HYG-<CATEGORY>-<NNN>, where the category is the kind of stored condition and
# the number distinguishes mechanisms inside it. Adding a rule means adding a
# number, not renumbering an existing one.
#
# Every rule describes a condition stored in the repository. None of them
# describes a model's context, and none of them is evidence that a reader
# loaded, followed, or was influenced by anything.

HYG_RULES='HYG-GOV-001
HYG-ARG-001
HYG-ARG-002
HYG-PHA-001
HYG-PHA-002
HYG-PHA-003
HYG-VOL-001
HYG-HIS-001'

hyg_rule_exists() {
  printf '%s\n' "$HYG_RULES" | grep -qx "$1"
}

# The rule that owns a category, for the text report headings.
hyg_rule_category() {
  case "$1" in
    HYG-GOV-*) printf 'governance\n' ;;
    HYG-ARG-*) printf 'argument-residue\n' ;;
    HYG-PHA-*) printf 'phantom-reference\n' ;;
    HYG-VOL-*) printf 'prose-volume\n' ;;
    HYG-HIS-*) printf 'history-residue\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

hyg_rule_severity() {
  case "$1" in
    HYG-GOV-*|HYG-ARG-*|HYG-PHA-*) printf 'warning\n' ;;
    *) printf 'info\n' ;;
  esac
}

hyg_rule_title() {
  case "$1" in
    HYG-GOV-001) printf 'Governance in a source comment\n' ;;
    HYG-ARG-001) printf 'Argument residue in a source comment\n' ;;
    HYG-ARG-002) printf 'Argument residue in repository prose\n' ;;
    HYG-PHA-001) printf 'Reference to a document that does not exist\n' ;;
    HYG-PHA-002) printf 'Reference to a repository path that does not resolve\n' ;;
    HYG-PHA-003) printf 'Symbolic link whose target does not resolve\n' ;;
    HYG-VOL-001) printf 'Source file that is mostly comment\n' ;;
    HYG-HIS-001) printf 'Deleted prose still retrievable from Git history\n' ;;
    *) printf 'Unknown rule\n' ;;
  esac
}

# One sentence, for SARIF result messages and JSON findings.
hyg_rule_message() {
  case "$1" in
    HYG-GOV-001) printf 'A source comment states a rule, a ruling, or an authority that a reader is expected to obey.\n' ;;
    HYG-ARG-001) printf 'A source comment records a past disagreement rather than describing the code.\n' ;;
    HYG-ARG-002) printf 'Repository prose records a past disagreement rather than describing the system.\n' ;;
    HYG-PHA-001) printf 'A source comment cites a document that this repository does not contain.\n' ;;
    HYG-PHA-002) printf 'A document, an agent instruction file, or agent configuration references a repository path that does not resolve.\n' ;;
    HYG-PHA-003) printf 'A symbolic link stored in this repository points at a target that does not resolve.\n' ;;
    HYG-VOL-001) printf 'A source file carries a high proportion of comment, which is a size signal and not a quality score.\n' ;;
    HYG-HIS-001) printf 'Prose that is no longer in the tree can still be retrieved from Git history.\n' ;;
    *) printf 'Unknown rule.\n' ;;
  esac
}

# A machine-readable name for the rule, for SARIF reportingDescriptor.name.
# Letters and digits only, so it is a valid identifier in any consumer.
hyg_rule_name() {
  case "$1" in
    HYG-GOV-001) printf 'GovernanceInSourceComment\n' ;;
    HYG-ARG-001) printf 'ArgumentResidueInSourceComment\n' ;;
    HYG-ARG-002) printf 'ArgumentResidueInRepositoryProse\n' ;;
    HYG-PHA-001) printf 'PhantomDocumentReference\n' ;;
    HYG-PHA-002) printf 'UnresolvedRepositoryReference\n' ;;
    HYG-PHA-003) printf 'BrokenRepositorySymlink\n' ;;
    HYG-VOL-001) printf 'CommentHeavySourceFile\n' ;;
    HYG-HIS-001) printf 'DeletedProseInGitHistory\n' ;;
    *) printf 'UnknownRule\n' ;;
  esac
}

# The three sections together, for a consumer that shows one block of help.
hyg_rule_help() {
  hyg_rule_why "$1"
  printf '\n'
  hyg_rule_limits "$1"
  printf '\n'
  hyg_rule_remediation "$1"
}

hyg_rule_why() {
  case "$1" in
    HYG-GOV-001) printf '%s\n' \
      'Comments travel with the code and are read as context. A comment that' \
      'states who decided something, what must never be touched, or which' \
      'document governs can outlive the decision itself, and then it is' \
      'enforced by nobody in particular. The constraint usually still exists;' \
      'it has just moved somewhere nothing checks.' ;;
    HYG-ARG-001|HYG-ARG-002) printf '%s\n' \
      'A record of who wanted, rejected, corrected, or gave up on something is' \
      'history. In a comment or a document it reads as a standing position, and' \
      'a later reader inherits a debate they were not part of and cannot close.' ;;
    HYG-PHA-001) printf '%s\n' \
      'A citation implies a source exists. When the document is gone, moved, or' \
      'never written, the citation keeps pointing at authority that cannot be' \
      'consulted, and the claim behind it becomes unfalsifiable.' ;;
    HYG-PHA-002) printf '%s\n' \
      'A reference implies a target. A link, an import, or a configured path' \
      'that no longer resolves sends a reader to nothing, and it keeps asserting' \
      'that the thing it names is there. What this rule reports is a reference' \
      'the repository is itself storing and cannot deliver, which is the one' \
      'kind of broken reference a single checkout can demonstrate on its own.' \
      'A path that points somewhere else on your machine is a different' \
      'question, and this rule does not answer it.' ;;
    HYG-PHA-003) printf '%s\n' \
      'A link that does not resolve is a path the repository stores and cannot' \
      'deliver. It reads as present in a listing and fails the moment anything' \
      'opens it, and because it is checked in, every clone inherits the same' \
      'failure.' ;;
    HYG-VOL-001) printf '%s\n' \
      'The proportion of a file that is comment is a size signal. A file that is' \
      'mostly explanation is carrying prose that has no other home, and prose' \
      'has no compiler to contradict it.' ;;
    HYG-HIS-001) printf '%s\n' \
      'Deleting prose stops it being read from the working tree. It does not' \
      'remove it from the repository, and any agent with Git access can' \
      'retrieve it.' ;;
    *) printf '\n' ;;
  esac
}

hyg_rule_limits() {
  case "$1" in
    HYG-GOV-001) printf '%s\n' \
      'This is a pattern match on comment text. It does not establish that the' \
      'rule is wrong, that anyone follows it, or that any agent read it. A' \
      'comment describing a mechanism can share the vocabulary of a rule.' ;;
    HYG-ARG-001|HYG-ARG-002) printf '%s\n' \
      'The match is lexical. It does not reconstruct what happened, and a' \
      'specification or a design rationale can legitimately describe a rejected' \
      'alternative.' ;;
    HYG-PHA-001) printf '%s\n' \
      'The check is existence by basename, not a link resolver. A document with' \
      'the same basename anywhere in the repository satisfies it, and a' \
      'reference to a section, an external URL, or a file outside the repository' \
      'is not modeled.' ;;
    HYG-PHA-002) printf '%s\n' \
      'Resolution follows the path as written, from the file that carries it, and' \
      'a same-named file elsewhere in the repository does not satisfy it. Only' \
      'the carriers the project models are read: Markdown link and image' \
      'destinations, the local import syntax of the agent tools named in the' \
      'exposure documentation, and path-bearing permission expressions in the' \
      'project settings files those tools document. The import syntax is read' \
      'narrowly, because an at-sign also opens an address, a handle and a package' \
      'scope: the token has to start where an import starts, carry no second' \
      'at-sign, and end in a file extension, so an extensionless import and one' \
      'whose spaces are backslash-escaped are not read, and neither is anything' \
      'after an at-sign in an address. A path written as an example,' \
      'a placeholder or a template, an external URL, a fragment on its own, a' \
      'glob, and a target outside the repository are not read at all. The' \
      'fragment and heading of a link are not checked, only the file. The rule' \
      'answers only for paths the scanned repository holds, so a reference' \
      'outside it is outside the rule: an absolute path above the root, and a' \
      'path written with a leading tilde, is not opened, not resolved and not' \
      'reported. A tool may document exactly such a path for material it keeps' \
      'with the machine rather than with any checkout, and an absent one is not' \
      'distinguished from a present one, because neither is read. None of this' \
      'establishes that the referenced material is needed.' ;;
    HYG-PHA-003) printf '%s\n' \
      'The test is whether the target resolves, and the target is never opened.' \
      'A link that resolves outside the repository is reported as resolving; the' \
      'check does not ask where it points or whether that is appropriate for' \
      'this repository. The filesystem resolves the chain, so a loop and a chain' \
      'both terminate, and a loop is reported as one more link that does not' \
      'resolve. An ignored path is not an input, the contents of a linked' \
      'directory are never walked, and where readlink is unavailable the link is' \
      'still reported with an empty matched target.' ;;
    HYG-VOL-001) printf '%s\n' \
      'Volume is not quality. A dense, accurate comment block scores the same as' \
      'a dense, stale one. Thresholds are advisory and are shown with the' \
      'finding so you can judge the file yourself.' ;;
    HYG-HIS-001) printf '%s\n' \
      'The content is retrievable, not loaded. Nothing here claims an agent read' \
      'the history, and history is legitimately retrievable for real work.' ;;
    *) printf '\n' ;;
  esac
}

hyg_rule_remediation() {
  case "$1" in
    HYG-GOV-001) printf '%s\n' \
      'Move the constraint to something that can fail: a test, a check, a type,' \
      'a schema. Keep the comment only where it explains the code. If the rule' \
      'is yours and belongs to you, record it as a ruling rather than leaving it' \
      'in a file that changes with the code.' ;;
    HYG-ARG-001|HYG-ARG-002) printf '%s\n' \
      'Delete it. The Git history already holds the record, and it is the right' \
      'place for it. If the outcome still matters, write it as a present-tense' \
      'reason about the system, or as a check.' ;;
    HYG-PHA-001) printf '%s\n' \
      'Delete the citation and keep the part of the comment that explains the' \
      'code; that is the usual fix, because a citation to a document that is gone' \
      'is usually a citation nothing depends on any more. If the citation is' \
      'still valid, point it at the document that actually exists. Do not write' \
      'a document only to clear the finding: the finding says the reference is' \
      'stale, not that the material is wanted.' ;;
    HYG-PHA-002) printf '%s\n' \
      'Delete the reference if the thing it named is gone and nothing depends on' \
      'it, which is the usual fix. If the reference is still meant to resolve,' \
      'point it at the file that exists in this repository. Do not create a file' \
      'only to clear the finding.' ;;
    HYG-PHA-003) printf '%s\n' \
      'Remove the link if its target is gone for good. If the link is still' \
      'wanted, point it at a target that exists in this repository, or commit' \
      'the real file in its place. Restoring the target on your own machine does' \
      'not fix the finding, because every other clone is still broken. Nothing' \
      'is deleted or rewritten for you.' ;;
    HYG-VOL-001) printf '%s\n' \
      'Read the file and decide which comments are load-bearing. Explanation that' \
      'belongs in a document should move there; explanation that is really a rule' \
      'should become a check. Nothing is rewritten for you.' ;;
    HYG-HIS-001) printf '%s\n' \
      'Decide whether the material is still true. If it is, put it back somewhere' \
      'a reader will find it. If it is not, treat its retrievability as accepted' \
      'history rather than as a finding that needs action.' ;;
    *) printf '\n' ;;
  esac
}
