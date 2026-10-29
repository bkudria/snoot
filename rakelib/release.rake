# frozen_string_literal: true

require "date"
require_relative "release_prep"

namespace :release do
  desc "Bump VERSION, promote CHANGELOG's Unreleased section, then commit and tag the release"
  task :prepare, [:version] do |_, args|
    ReleasePrep::Run.new(root: Rake.application.original_dir, input: $stdin, output: $stdout, today: Date.today)
                    .call(args[:version])
  rescue ReleasePrep::Error => error
    abort "release:prepare: #{error.message}"
  end

  desc "Print a version's CHANGELOG section, for release notes"
  task :notes, [:version] do |_, args|
    version = args[:version] or abort "usage: rake release:notes[X.Y.Z]"
    puts ReleasePrep::Changelog.notes(File.read(File.join(Rake.application.original_dir, "CHANGELOG.md")), version)
  rescue ReleasePrep::Error => error
    abort "release:notes: #{error.message}"
  end
end
