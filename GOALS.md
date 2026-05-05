# Goals

## Why this exists

Existing Ruby static-analysis tools — reek, flog, flay — produce verbose
reports designed for a human reader sweeping a list. snoot orchestrates
the same analysers but emits a single finding shaped for a different
reader: an LLM coding agent that needs enough inlined context to act on
exactly one issue, without sweeping or follow-up tool calls.

## Who it's for

- **Primary:** an LLM coding agent that reads the report and acts on
  the finding it describes.
- **Secondary:** a developer skimming the same report at a terminal.
  The format is identical; the design centre is the agent.

## What success looks like

- An agent receives one finding per run, with sufficient inlined
  context to act without follow-up tool calls.
- The report is parseable by structural landmarks (header, finding
  context, doc), not by analyser name.
- "Nothing to report" is a first-class run outcome, not an empty
  report.
- Analyser failures are surfaced as a distinct outcome, not as a
  misleading "no findings".

## What this is not

snoot is deliberately narrow. It is not:

- a CI gate (no exit-code-by-severity policy is part of the goal)
- a diff-aware linter
- a JSON or MCP surface
- a pre-commit hook
- a multi-finding report

The single-finding, agent-targeted shape is a deliberate constraint,
not a stepping stone toward a larger tool. Proposals that broaden the
output beyond one finding, or reorient the report toward a non-agent
reader, conflict with intent.

## Pointer to the spec

The behavioural contract — what a run does and what its outcomes mean
— lives in [`snoot.allium`](snoot.allium). GOALS captures the *why*;
the spec captures the *how*.
