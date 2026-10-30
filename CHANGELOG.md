# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- flay skips files matched by `.flayignore` in the current directory,
  as the `flay` command does. The README and `--help` say a whole
  directory needs `dir/**/*.rb`, and that flog has no way to exclude
  files.
- Every run that gets past argument checking ends stdout with a status
  line for scripts: `snoot-status: <outcome>` followed by `key=value`
  fields (`snoot-status: finding_rendered category=smell
  type=FeatureEnvy remaining=4`, `snoot-status: nothing_to_report`,
  `snoot-status: analysis_failed analyser=reek`). On an analysis
  failure it is the only stdout output. `--help` and the README
  describe the format, and the README says which exit codes mean
  snoot could not judge the code.
- `snoot --help` and the README explain how snoot picks its one
  finding: category priority, ranking and tie-breaks, significance
  cutoffs, `.reek.yml` scope, and the fix-and-rerun loop.
- `snoot --help` and the README say a smell finding lists every
  instance of its type, and that running reek, flog or flay directly
  lists a different set.
- Every report's second line counts the significant findings snoot
  isn't showing, per category, and states the significance cutoffs
  that applied (`Also significant: 4 smell types, 0 duplication
  clusters, 0 complexity hits (cutoffs: …)`). The nothing-to-report
  line states the cutoffs too.
- The "Also significant" and nothing-to-report lines name the smell
  types still below the cutoff (`; 1 smell type below cutoff:
  TooManyStatements`), so a type shows up before it counts.
- Smell reports carry a fix-first tuning section between the instances
  and reek's doc: fix and rerun, or configure the detector in
  `.reek.yml` under `detectors:`, keyed by the smell type's name.

### Changed

- Duplication reports lead with flay's own description instead of an
  opaque signature (`Similar code (:defn) in 3 locations, mass 78 (26
  per copy)`), list each copy's full line span (`sample.rb:2-10`
  instead of `2-2`), and show the code: the first copy when the copies
  are identical, otherwise up to three copies, each up to 20 lines.
- Complexity reports show the method's full line span (`sample.rb:4-24`
  instead of `4-4`), round the score to two decimals, split it into
  flog's three dimensions (assignments, branching, and calls and other)
  with each one's top operations, and show the method's code: up to 50
  lines, common indentation removed.
- Smell instances list every line reek flagged (`Lines 12, 15: …`)
  instead of only the first, each followed by its source code
  (`12 | x.foo(bar)`), so the agent sees the code without opening the
  file. Up to five code lines are shown per instance; the rest are
  listed by number, and lines over 160 characters are cut. Control
  characters in the code are replaced with `�`, so a scanned file can't
  send escape sequences to the terminal.
- Smell reports lead with a one-line header naming the smell type
  with its instance and file counts, followed by the instances and
  then reek's doc. Previously the doc came first and the instances
  last.

- A rejected option is named on stderr (`snoot: unknown option:
  <arg>`, then `Try 'snoot --help' for usage.`) instead of the full
  usage text. Unknown options and missing paths are reported together.
- `--help` and `--version` print and exit 0 wherever they appear in
  argv, and `--` ends options so later arguments are always paths.

### Fixed

- An analysis-failure message names the line and reason when a source
  file can't be parsed or read (`… syntax error in the source file.
  (lib/a.rb:2:9: error: unexpected token tINTEGER)`), and always fits on
  one line. Previously reek's message named only the file.
- An unexpected internal error exits 70 with `snoot: internal error:
  <class>: <message>` and the backtrace on stderr, and an
  `internal_error` status line on stdout. Previously it exited 1, the
  same code as a rendered finding.
- A path argument that doesn't exist is rejected with exit 64 and a
  `snoot: no such file or directory: <path>` line on stderr. Previously
  flog and flay silently scanned the current directory instead.

## [0.1.0] - 2026-05-14

### Added

- Initial release.
- `snoot` CLI that orchestrates reek, flog, and flay over a given path
  set (or the current directory when no paths are given) and emits a
  single agent-targeted finding to stdout.

[Unreleased]: https://github.com/bkudria/snoot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bkudria/snoot/releases/tag/v0.1.0
