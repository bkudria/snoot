# snoot

A Ruby gem that orchestrates `reek`, `flog`, and `flay` over a configured path set and emits a single agent-targeted report describing one finding.

The report is centred on an LLM coding agent as the reader: each run produces a four-section report (header, finding context, doc, framing) for one selected finding, or acknowledges that nothing was worth reporting, or signals analyser failure.

## Status

Early-stage. The behavioural specification lives in [`snoot.allium`](snoot.allium); the implementation is not yet in place.

## Usage

CLI usage is not yet implemented. See `snoot.allium` for the intended surface and run outcomes.
