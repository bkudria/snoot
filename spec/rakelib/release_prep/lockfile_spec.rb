# frozen_string_literal: true

require "spec_helper"
require_relative "../../../rakelib/release_prep"

RSpec.describe ReleasePrep::Lockfile do
  let(:lockfile) do
    <<~LOCK
      PATH
        remote: .
        specs:
          snoot (0.1.0)
            reek (~> 6.5)

      GEM
        remote: https://rubygems.org/
        specs:
          reek (6.5.0)
          snoot-extras (0.1.0)

      CHECKSUMS
        reek (6.5.0) sha256=abc
        snoot (0.1.0)
        snoot-extras (0.1.0) sha256=def
    LOCK
  end

  it "rewrites the gem's own PATH and CHECKSUMS entries, not similarly named gems" do
    bumped = described_class.bump(lockfile, gem: "snoot", version: "0.2.0")
    expect(bumped.lines.grep(/snoot/)).to eq(
      ["    snoot (0.2.0)\n", "    snoot-extras (0.1.0)\n", "  snoot (0.2.0)\n", "  snoot-extras (0.1.0) sha256=def\n"]
    )
  end

  it "refuses a lockfile with no entry for the gem" do
    expect { described_class.bump(lockfile, gem: "other", version: "0.2.0") }
      .to raise_error(ReleasePrep::Error, /other/)
  end
end
