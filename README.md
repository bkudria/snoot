# snoot

A Ruby gem that orchestrates `reek`, `flog`, and `flay` over a configured path set and emits a single agent-targeted report describing one finding.

The report is centred on an LLM coding agent as the reader: each run produces one of two report shapes -- header, remaining, instances, tuning and doc for smell findings, or header, remaining, finding context and doc for complexity and duplication findings (for complexity, the context splits the score into flog's dimensions and shows the method's code; for duplication, it lists every copy's span and shows the code of up to three copies) -- or acknowledges that nothing was worth reporting, or signals analyser failure. Every report's doc opens with a `## Reference` heading and runs from the first such line to the status line, so an agent can cut the reference material there. The remaining line counts the other significant findings snoot is holding back and states the significance cutoffs that applied; the nothing-to-report line states the cutoffs too.

## Status

Pre-1.0. Three analysers (Reek / Flog / Flay) are used, and `snoot <paths>` drives the full pipeline end-to-end: it reports a single finding to stdout, an acknowledgement when nothing is worth reporting, or a failure line on stderr. With no positional arguments, `snoot` scans the current directory. The exit code is `1` when a finding is rendered, `0` when there is nothing to report, `2` when analysis fails, `64` for a usage error, and `70` for an internal error. The last stdout line is a status line for scripts (see [Output for scripts](#output-for-scripts)).

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
    snoot -- -odd-name.rb       # arguments after -- are always paths

`snoot` emits a single agent-targeted finding to stdout and exits with:

- `0` — nothing worth reporting,
- `1` — a finding was rendered,
- `2` — analysis failed (failure line on stderr),
- `64` — usage error (unknown flag or missing path; details on stderr),
- `70` — internal error (a bug in snoot; details and backtrace on stderr).

At any outcome, reek, flog and flay can write their own diagnostics to stderr
as they run, such as a file they skipped (unreadable, unparseable, or
slow to parse) or flog's advice to rerun with `--continue`, which
does not apply to snoot. snoot passes these through unchanged; for flay
and some flog parse errors they are the only sign that a file went
unanalysed.

## Output for scripts

Every run that gets past argument checking ends stdout with one status
line: `snoot-status: `, the outcome, then `key=value` fields whose values
never contain spaces.

    snoot-status: finding_rendered category=smell type=FeatureEnvy remaining=4
    snoot-status: finding_rendered category=duplication remaining=2
    snoot-status: finding_rendered category=complexity remaining=0
    snoot-status: nothing_to_report
    snoot-status: analysis_failed analyser=reek
    snoot-status: internal_error error=NoMethodError

`category` is `smell`, `duplication` or `complexity`; `type` names the
smell type and appears only for smells; `remaining` counts the
significant findings behind this one (the "Also significant" totals).
On `analysis_failed` the status line is all of stdout. Usage errors,
`--help` and `--version` print no status line. A gate can read the exit
code or `tail -n 1` of stdout:

    snoot lib | tail -n 1

Exit `1` means a finding is waiting;
`2`, `64` and `70` mean snoot could not judge the code, so a gate
should read them as neither clean nor a finding.

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

flay skips files matched by `.flayignore` in the current directory,
using flay's own patterns: a whole directory needs `dir/**/*.rb`, since
`dir` or `dir/` alone does not exclude its subdirectories.
flog has no way to exclude files.

The "Also significant" line and the "nothing to report" line both name
the smell types below the cutoff, so a type shows up before it counts.
After its instances, a smell report says how to configure that smell's
detector: under `detectors:` in `.reek.yml`, keyed by the smell type's
name.

## Privacy

`snoot` runs entirely locally. It analyses source on disk with the bundled
`reek`, `flog`, and `flay` libraries and writes its single finding to stdout —
no source code, findings, or telemetry are sent over the network.

## License

snoot is MIT-licensed; see [`LICENSE`](LICENSE).

The reek smell-documentation files vendored under [`data/reek_docs/`](data/reek_docs/) are reproduced from [troessner/reek](https://github.com/troessner/reek) (Copyright © 2008, 2009 Kevin Rutherford) under the MIT license; see [`data/reek_docs/LICENSE`](data/reek_docs/LICENSE). Re-syncing those files with `rake docs:sync` also refreshes the bundled license notice.
