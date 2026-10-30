# Contributing

## Commit conventions

This repository follows [Conventional Commits](https://www.conventionalcommits.org/).

Subject format: `<type>(<scope>)?!?: <subject>`. Allowed types:

```
feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
```

Examples:

```
feat: add init command
fix(check): treat empty config as a block
refactor(rewrite)!: change signature policy default
```

Enforced by git hook specified in .git/config

## Changelog entries

Every `feat` or `fix` PR, and every PR marked breaking with `!`, adds a
user-facing entry under `## [Unreleased]` in `CHANGELOG.md`. CI checks
this using the PR title. Label a PR `no-changelog` to opt out.

## Releasing

1. On an up-to-date, clean `main`, run `bundle exec rake release:prepare`.
   It lists the commits since the last tag and suggests a version from
   their Conventional Commit types: below 1.0.0, a `feat` or breaking
   change bumps the minor version and anything else bumps the patch.
   Press Enter to accept, or type a different version. Pass a version to
   skip the prompt: `bundle exec rake "release:prepare[0.3.0]"`.
2. It sets `VERSION` (and snoot's own entry in `Gemfile.lock`), moves the
   `[Unreleased]` entries under a dated heading, commits
   `chore(release): vX.Y.Z`, and creates the `vX.Y.Z` tag.
3. Push both: `git push origin main vX.Y.Z`.
4. The Release workflow checks that the tag matches `VERSION`, is on
   `main`, and has a changelog section, then runs the suite. Approve the
   `release` environment deployment to publish to RubyGems through
   trusted publishing and create the GitHub Release from the changelog
   section.

`bundle exec rake release:notes[X.Y.Z]` prints a version's changelog
section.
