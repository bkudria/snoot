# snoot

A Ruby gem that orchestrates `reek`, `flog`, and `flay` over a configured path set and emits a single agent-targeted report describing one finding.

The report is centred on an LLM coding agent as the reader: each run produces one of two report shapes -- header, remaining, instances and doc for smell findings, or header, remaining, finding context and doc for complexity and duplication findings -- or acknowledges that nothing was worth reporting, or signals analyser failure. The remaining line counts the other significant findings snoot is holding back and states the significance cutoffs that applied; the nothing-to-report line states the cutoffs too.

## Status

Pre-1.0. Three analysers (Reek / Flog / Flay) are used, and `snoot <paths>` drives the full pipeline end-to-end: it reports a single finding to stdout, an acknowledgement when nothing is worth reporting, or a failure line on stderr. With no positional arguments, `snoot` scans the current directory. The exit code is `1` when a finding is rendered, `0` when there is nothing to report, and `2` when analysis fails.

## Specification

The behaviour is specified in [`snoot.allium`](snoot.allium) (the Allium
behavioural contract); [`GOALS.md`](GOALS.md) records the design rationale.
The spec, the implementation in `lib/`, and the tests in `spec/` are peer
artifacts and are kept in sync — see [`CLAUDE.md`](CLAUDE.md).

## Installation

Requires Ruby 4.0 or later.

    gem install snoot

## Usage

After install, the `snoot` executable is available on PATH:

    snoot --version
    snoot --help
    snoot lib/foo.rb            # analyse a specific path
    snoot                       # scan the current directory

`snoot` emits a single agent-targeted finding to stdout and exits with:

- `0` — nothing worth reporting,
- `1` — a finding was rendered,
- `2` — analysis failed (failure line on stderr),
- `64` — usage error (unknown flag or missing path; details on stderr).

## How snoot picks a finding

Each run reports one finding. A smell finding lists
every instance of its type across the scanned files, so one run is a
batch of same-type fixes. Fix them, then run `snoot` again to see the next finding; the
report's "Also significant" line counts what is still waiting.

Running reek, flog or flay directly skips the cutoffs and the doc-less
skip described below, so it lists a different set from the one snoot
draws its finding from.

Only findings above snoot's significance cutoffs are candidates --
cutoffs: smell types need 2+ instances; complexity hits need score 25+; duplication clusters have no cutoff.
Duplication still passes through flay's own mass threshold (16).

Among the candidates, smells outrank duplication clusters, which outrank
complexity hits. Within a category the largest wins:

- smells: the smell type with the most instances; ties break by smell
  type name, then path, then line;
- duplication clusters: the most locations; ties break by signature,
  then first path, then first line;
- complexity hits: the highest score; ties break by path, then line.

Smell types with no bundled reek documentation are skipped. When the
skipped type would have been the top finding, snoot prints a warning on
stderr.

Reek reads `.reek.yml` from the current directory or its nearest
ancestor, falling back to `~/.reek.yml`; it configures reek's detectors
and `exclude_paths`. flog and flay do not read it.

## Privacy

`snoot` runs entirely locally. It analyses source on disk with the bundled
`reek`, `flog`, and `flay` libraries and writes its single finding to stdout —
no source code, findings, or telemetry are sent over the network.

## License

snoot is MIT-licensed; see [`LICENSE`](LICENSE).

The reek smell-documentation files vendored under [`data/reek_docs/`](data/reek_docs/) are reproduced from [troessner/reek](https://github.com/troessner/reek) (Copyright © 2008, 2009 Kevin Rutherford) under the MIT license; see [`data/reek_docs/LICENSE`](data/reek_docs/LICENSE). Re-syncing those files with `rake docs:sync` also refreshes the bundled license notice.
