# snoot

A Ruby gem that orchestrates `reek`, `flog`, and `flay` over a configured path set and emits a single agent-targeted report describing one finding.

The report is centred on an LLM coding agent as the reader: each run produces a four-section report (header, finding context, doc, framing) for one selected finding, or acknowledges that nothing was worth reporting, or signals analyser failure.

## Status

Pre-1.0. Reek integration is wired (slice 10A); Flog and Flay arrive in slice 10B. The pipeline-driving CLI (`snoot <paths>`) is not yet implemented; today the executable supports `--version` and `--help` only. The behavioural specification lives in [`snoot.allium`](snoot.allium).

## Install

From a local checkout:

    bundle install
    rake build
    gem install pkg/snoot-0.1.0.gem

After install, `snoot --version` and `snoot --help` are available on PATH.

## Library usage

    require "snoot"

    adapter = Snoot::AnalyserOrchestration::Default.new
    paths   = Set[Snoot::Path.new(raw: "lib/foo.rb")]
    Snoot::CLI.for(Snoot::Operator.new).run_invoked(
      paths, orchestration: adapter
    )
