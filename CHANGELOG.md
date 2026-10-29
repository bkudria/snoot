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

## [0.1.0] - 2026-05-14

### Added

- Initial release.
- `snoot` CLI that orchestrates reek, flog, and flay over a given path
  set (or the current directory when no paths are given) and emits a
  single agent-targeted finding to stdout.

[Unreleased]: https://github.com/bkudria/snoot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bkudria/snoot/releases/tag/v0.1.0
