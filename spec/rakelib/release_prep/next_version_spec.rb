# frozen_string_literal: true

require "spec_helper"
require_relative "../../../rakelib/release_prep"

RSpec.describe ReleasePrep::NextVersion do
  def suggest(current, *messages)
    described_class.suggest(current: current, commit_messages: messages)
  end

  context "when below 1.0.0" do
    it "bumps minor for a feat" do
      expect(suggest("0.1.0", "fix: a", "feat(cli): b")).to eq("0.2.0")
    end

    it "bumps minor, not major, for a breaking change" do
      expect(suggest("0.1.3", "refactor(cli)!: drop flag")).to eq("0.2.0")
    end

    it "bumps patch when nothing is a feat or breaking" do
      expect(suggest("0.1.0", "fix: a", "docs(cli): b", "chore: c")).to eq("0.1.1")
    end
  end

  context "when at or above 1.0.0" do
    it "bumps major for a ! subject" do
      expect(suggest("1.4.2", "feat!: new output")).to eq("2.0.0")
    end

    it "bumps major for a BREAKING CHANGE footer" do
      expect(suggest("1.4.2", "fix: a\n\nBREAKING CHANGE: exit codes differ")).to eq("2.0.0")
    end

    it "bumps minor for a feat" do
      expect(suggest("1.4.2", "feat: a")).to eq("1.5.0")
    end

    it "bumps patch otherwise" do
      expect(suggest("1.4.2", "fix: a")).to eq("1.4.3")
    end
  end

  it "ignores a type word that isn't the subject's prefix" do
    expect(suggest("1.0.0", "docs: mention feat: syntax")).to eq("1.0.1")
  end

  it "treats a non-conventional message as a patch" do
    expect(suggest("1.0.0", "Merge branch 'topic'")).to eq("1.0.1")
  end

  it "refuses when there are no commits to release" do
    expect { suggest("0.1.0") }.to raise_error(ReleasePrep::Error, /no commits/)
  end
end
