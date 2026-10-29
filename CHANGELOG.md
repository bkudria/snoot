# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

### Changed

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
