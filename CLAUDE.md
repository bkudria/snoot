# snoot — agent guide

## Specification

The behavioural spec lives in [`snoot.allium`](snoot.allium). It is the source
of truth for runtime behaviour; treat it as a contract, not documentation.
When implementation and spec disagree, the spec wins until the spec is
amended.

## Test layout

`spec/` follows a hybrid convention: namespace-mirroring for class specs,
Allium-concept directories for everything else.

- `spec/snoot/` — specs that describe a Ruby class. Path mirrors the
  namespace (`Snoot::Finding` → `spec/snoot/finding_spec.rb`,
  `Snoot::CLI::Argv` → `spec/snoot/cli/argv_spec.rb`). This satisfies
  `RSpec/SpecFilePathFormat`.
- `spec/contracts/` — Allium contract specs (`RSpec.describe` a contract
  string, e.g. `"AnalyserOrchestration::Default"`).
- `spec/invariants/` — Allium invariant specs (`RSpec.describe` an invariant
  string, e.g. `"Invariant: SingleFindingPerRun"`).
- `spec/support/` — shared helpers (factories, fakes, tempfile/IO scaffolding).
- `spec/*_spec.rb` — top-level specs that aren't a class (e.g.
  `exe_snoot_spec.rb`, `version_spec.rb`).

When adding a spec for a Ruby class, place it under `spec/snoot/` mirroring
its namespace. Allium contract/invariant specs (which `RSpec.describe` a
descriptive string) live under `spec/contracts/` or `spec/invariants/`.

## Commands

- `bundle exec rspec` — run the suite
- `bundle install` — install dependencies
- `bundle exec rubocop` — lint
- `bundle exec rubocop -A` — format (safe + unsafe autocorrect); RuboCop
  is the project's formatter, configured via `.rubocop.yml`

## Commit conventions

See [CONTRIBUTING.md](CONTRIBUTING.md) for the commit-message convention.

## Project state

`lib/` holds the implementation, loaded by `spec/spec_helper.rb` via
`require "snoot"`. The gem version lives in `lib/snoot/version.rb`,
and the Ruby toolchain is pinned via `.ruby-version`. See
[`README.md`](README.md) for what the gem does and [`GOALS.md`](GOALS.md)
for the design rationale.
