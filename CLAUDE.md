# snoot — agent guide

## Specification

The behavioural spec lives in [`snoot.allium`](snoot.allium). It is the source
of truth for runtime behaviour; treat it as a contract, not documentation.
When implementation and spec disagree, the spec wins until the spec is
amended.

## Test layout

`spec/` mirrors the Allium element kinds in `snoot.allium`:

- `spec/values/` — value-type specs (`Path`, `Location`, `SmellType`)
- `spec/rules/` — rule specs (`AnalyseRun`, `RenderReport`)
- `spec/surfaces/` — surface specs (`CLI`, `ReportReader`)
- `spec/invariants/` — invariant specs (`SingleFindingPerRun`,
  `SelectedFindingsAreRenderable`)
- `spec/*_spec.rb` — entity specs at the top level (`Finding`, `Run`)

When adding a new spec, place it under the directory matching its Allium
element kind. New entities go at the top level.

## Commands

- `bundle exec rspec` — run the suite
- `bundle install` — install dependencies
- `bundle exec rubocop` — lint
- `bundle exec rubocop -A` — format (safe + unsafe autocorrect); RuboCop
  is the project's formatter, configured via `.rubocop.yml`

## Commit conventions

See [CONTRIBUTING.md](CONTRIBUTING.md) for the commit-message convention.

## Project state

`lib/` does not exist yet. `spec/spec_helper.rb` is wired to load it once it
does (the `require "snoot"` line is currently commented out). The project is
in a spec-first phase: tests are pending until the implementation lands.
