# snoot

A Ruby gem that orchestrates `reek`, `flog`, and `flay` over a configured path set and emits a single agent-targeted report describing one finding.

The report is centred on an LLM coding agent as the reader: each run produces one of two report shapes -- a doc + instances pair for smell findings, or a header + finding context + doc trio for complexity and duplication findings -- or acknowledges that nothing was worth reporting, or signals analyser failure.

## Status

Pre-1.0. Three analysers (Reek / Flog / Flay) are used, and `snoot <paths>` drives the full pipeline end-to-end: it reports a single finding to stdout, an acknowledgement when nothing is worth reporting, or a failure line on stderr. With no positional arguments, `snoot` scans the current directory. The exit code is `1` when a finding is rendered, `0` when there is nothing to report, and `2` when analysis fails.

## Specification

The behaviour is specified in [`snoot.allium`](snoot.allium) (the Allium
behavioural contract); [`GOALS.md`](GOALS.md) records the design rationale.
The spec, the implementation in `lib/`, and the tests in `spec/` are peer
artifacts and are kept in sync — see [`CLAUDE.md`](CLAUDE.md).

## Installation

From a local checkout:

    bundle install
    rake build
    gem install pkg/snoot-0.1.0.gem

Once published to RubyGems, you will be able to install it directly with:

    gem install snoot

Or, from a Gemfile:

    gem "snoot"

## Usage

After install, the `snoot` executable is available on PATH:

    snoot --version
    snoot --help
    snoot lib/foo.rb            # analyse a specific path
    snoot                       # scan the current directory

`snoot` emits a single agent-targeted finding to stdout and exits with:

- `0` — nothing worth reporting,
- `1` — a finding was rendered,
- `2` — analysis failed (failure line on stderr).

## License

snoot is MIT-licensed; see [`LICENSE`](LICENSE).

The reek smell-documentation files vendored under [`data/reek_docs/`](data/reek_docs/) are reproduced from [troessner/reek](https://github.com/troessner/reek) (Copyright © 2008, 2009 Kevin Rutherford) under the MIT license; see [`data/reek_docs/LICENSE`](data/reek_docs/LICENSE). Re-syncing those files with `rake docs:sync` also refreshes the bundled license notice.
