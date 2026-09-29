# Context rot, context bloat, and instruction residue

If a coding agent starts ignoring instructions, repeating rejected approaches, or
referring to deleted architecture, it is tempting to call the whole problem
“context rot.” That phrase describes a symptom family, not a single diagnosis.

## The terms are related, but different

| Term | Useful meaning | Can Hygiene establish it? |
|---|---|---|
| Context bloat | Too much material competes for limited attention or consumes avoidable tokens | Hygiene reports repository prose volume; it does not see the active model context |
| Context drift | Current work diverges from earlier constraints or decisions | No. Hygiene can surface stored material worth checking, but cannot observe model reasoning |
| Context rot | Output quality appears to degrade as context becomes longer, noisier, or less relevant | No. This has multiple possible causes outside the repository |
| Documentation drift | Documentation no longer matches the implementation | Partly. Hygiene is not a semantic documentation-consistency checker |
| Instruction residue | Rule-like or decision-like repository text remains after its original context changes or disappears | Yes. This is Hygiene's primary inspection target |
| Phantom authority | A source comment cites a document that the scanner cannot find in the working tree | Yes, within the scanner's documented file and pattern coverage |

## Why context bloat costs more tokens

This part is not speculative. Model providers meter and price input tokens.
[Anthropic documents input-token pricing and higher rates for long-context
requests](https://docs.anthropic.com/en/docs/about-claude/pricing), and
[OpenAI prices model input per token](https://platform.openai.com/pricing).
More material included in a request means more input tokens processed, subject to
provider-specific caching and pricing rules.

A 2026 ETH Zurich study, [Evaluating AGENTS.md: Are Repository-Level Context Files
Helpful for Coding Agents?](https://arxiv.org/abs/2602.11988), found over 20% higher
inference cost from context files in its evaluated settings. That result is direct
evidence for those experiments, not a universal savings estimate for Hygiene.

Hygiene reports repository prose volume and residue candidates. It does not yet
measure which material a particular agent loaded or calculate tokens saved after
cleanup.

## Symptoms that justify a repository scan

Run a scan when Claude Code, Cursor, Codex, Copilot, or another coding agent:

- appears to follow an old project decision;
- repeats an approach that was previously rejected;
- cites a document or architecture that no longer exists;
- behaves as if a source comment were a permanent policy;
- works in a repository whose instruction files and Markdown have only grown;
- seems to receive conflicting repository guidance.

Hygiene was created after accumulated residue in a real repository produced these
kinds of friction in later AI-assisted work; cleaning it improved that workflow.
That case makes a read-only inventory a practical diagnostic step. The result of
one scan still cannot attribute every model response to a specific finding.

```sh
./bin/hygiene scan /path/to/your-project
```

## What to do with a finding

1. Read the finding in its current code context.
2. Decide whether the text still explains a mechanism or preserves an expired decision.
3. If it is a real invariant, prefer a test, type, check, or hook that can fail.
4. If it is historical discussion, move useful rationale to an appropriate decision record or remove it.
5. If it is an ordinary comment, report the false positive so the pattern can become more precise.

Do not delete useful documentation merely to reduce a count. Hygiene reports
candidates for human review, not a target score.

## What a scan cannot tell you

A scan cannot show which files an agent loaded, measure the model's context window,
attribute a hallucination to one comment, guarantee instruction compliance, or
calculate token savings. Session history, compaction, tool behavior, model changes,
and conflicting user prompts can produce similar symptoms.

The originating project provides direct case evidence that repository residue can
create friction and unintended governance. Hygiene shows whether the same stored
conditions are present elsewhere. Broader trials are needed to measure how often
cleanup changes agent behavior and by how much.
