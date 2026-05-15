# Releasing

This document describes how to cut a release of the `snoot` gem.

## Prerequisites

- Push access to the `main` branch on GitHub.
- A RubyGems account with push access to the `snoot` gem.
- RubyGems MFA enabled (`rubygems_mfa_required` is set in the gemspec).
- A clean working tree on an up-to-date `main`.

## Steps

1. **Decide the new version** following [Semantic Versioning](https://semver.org/spec/v2.0.0.html):
   - `MAJOR` for incompatible API changes.
   - `MINOR` for backwards-compatible feature additions.
   - `PATCH` for backwards-compatible bug fixes.

2. **Bump the version** in [`lib/snoot/version.rb`](lib/snoot/version.rb).

3. **Update [`CHANGELOG.md`](CHANGELOG.md)**:
   - Rename the `[Unreleased]` heading to `[<new-version>] - YYYY-MM-DD`.
   - Add a fresh empty `[Unreleased]` section above it.
   - Update the version-comparison links at the bottom of the file.

4. **Re-sync vendored reek docs** so the gem ships docs matching the
   bundled reek version:

   ```sh
   bundle exec rake docs:sync
   git status data/reek_docs/
   ```

   Stage any resulting changes; they belong in the release commit.

5. **Verify the suite is green**:

   ```sh
   bundle exec rspec
   bundle exec rubocop
   ```

6. **Commit the bump** (Conventional Commits, see [CONTRIBUTING.md](CONTRIBUTING.md)):

   ```sh
   git commit -m "chore(release): v<new-version>"
   ```

7. **Publish** using the Bundler-provided rake task:

   ```sh
   bundle exec rake release
   ```

   `rake release` (from `bundler/gem_tasks`) will:
   - tag the current commit as `v<new-version>`,
   - push the commit and tag to the remote,
   - build the gem, and
   - push the gem to RubyGems.

8. **Verify** that the new version appears on [rubygems.org/gems/snoot](https://rubygems.org/gems/snoot)
   and that the tag is present on GitHub.
