# frozen_string_literal: true

require "spec_helper"
require "open3"
require "stringio"
require "tmpdir"
require_relative "../../../rakelib/release_prep"

RSpec.describe ReleasePrep::Run do
  let(:root) { Dir.mktmpdir }
  let(:output) { StringIO.new }

  after { FileUtils.remove_entry(root) }

  def git(*args)
    stdout, status = Open3.capture2e("git", *args, chdir: root)
    raise "git #{args.join(' ')} failed: #{stdout}" unless status.success?

    stdout
  end

  def write(path, content)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def read(path) = File.read(File.join(root, path))

  def commit(subject)
    git("commit", "--allow-empty", "-q", "-m", subject)
  end

  def run_prep(version = nil, input: "\n")
    described_class.new(root: root, input: StringIO.new(input), output: output, today: Date.new(2026, 10, 29))
                   .call(version)
  end

  before do
    git("init", "-q", "-b", "main")
    git("config", "user.name", "Test")
    git("config", "user.email", "test@example.com")
    git("config", "commit.gpgSign", "false")
    git("config", "tag.gpgSign", "false")
    git("config", "core.hooksPath", File::NULL)
    write("lib/snoot/version.rb", %(module Snoot\n  VERSION = "0.1.0"\nend\n))
    write("CHANGELOG.md", <<~MD)
      # Changelog

      ## [Unreleased]

      ### Added

      - A thing.

      ## [0.1.0] - 2026-05-14

      - Initial release.

      [Unreleased]: https://github.com/o/r/compare/v0.1.0...HEAD
      [0.1.0]: https://github.com/o/r/releases/tag/v0.1.0
    MD
    git("add", ".")
    commit("chore(release): v0.1.0")
    git("tag", "-m", "Version 0.1.0", "v0.1.0")
    commit("fix: a bug")
    commit("feat(cli): a thing")
  end

  context "when the suggested version is accepted" do
    before { run_prep }

    it "bumps VERSION" do
      expect(read("lib/snoot/version.rb")).to include(%(VERSION = "0.2.0"))
    end

    it "promotes the Unreleased entries" do
      expect(read("CHANGELOG.md")).to include("## [Unreleased]\n\n## [0.2.0] - 2026-10-29\n\n### Added")
    end

    it "commits both files as a release commit" do
      expect(git("show", "--stat", "--format=%s", "HEAD"))
        .to start_with("chore(release): v0.2.0").and include("CHANGELOG.md", "lib/snoot/version.rb")
    end

    it "tags the release commit the way Bundler's release task would" do
      expect(git("tag", "-l", "--format=%(objecttype) %(contents:subject) %(*objectname)", "v0.2.0").strip)
        .to eq("tag Version 0.2.0 #{git('rev-parse', 'HEAD').strip}")
    end

    it "shows the commits it weighed, the suggestion, and the push command" do
      expect(output.string).to include("feat(cli): a thing", "fix: a bug", "[0.2.0]", "git push origin main v0.2.0")
    end
  end

  it "uses a version typed at the prompt" do
    run_prep(input: "0.3.0\n")
    expect(git("describe", "--tags").strip).to eq("v0.3.0")
  end

  it "skips the prompt when given a version" do
    run_prep("1.0.0", input: "")
    expect(git("describe", "--tags").strip).to eq("v1.0.0")
  end

  it "refuses a version that isn't above the current one" do
    expect { run_prep("0.1.0") }.to raise_error(ReleasePrep::Error, /0\.1\.0.*not above.*0\.1\.0/)
  end

  it "refuses a version that isn't X.Y.Z" do
    expect { run_prep(input: "two\n") }.to raise_error(ReleasePrep::Error, /"two"/)
  end

  it "reports the failing git command when there's no previous release tag" do
    git("tag", "-d", "v0.1.0")
    expect { run_prep }.to raise_error(ReleasePrep::Error, /git describe failed/)
  end

  it "refuses uncommitted changes" do
    write("stray.txt", "x")
    expect { run_prep }.to raise_error(ReleasePrep::Error, /uncommitted/)
  end

  it "refuses to release from a branch other than main" do
    git("switch", "-q", "-c", "topic")
    expect { run_prep }.to raise_error(ReleasePrep::Error, /main.*topic/)
  end

  it "leaves the repo untouched when it refuses", :aggregate_failures do
    expect { run_prep("0.0.9") }.to raise_error(ReleasePrep::Error)
    expect(git("status", "--porcelain")).to be_empty
  end
end
