# frozen_string_literal: true

require "spec_helper"
require_relative "../../../rakelib/release_prep"

RSpec.describe ReleasePrep::VersionFile do
  let(:source) do
    <<~RUBY
      module Snoot
        VERSION = "0.1.0"
      end
    RUBY
  end

  it "reads the current version" do
    expect(described_class.current(source)).to eq("0.1.0")
  end

  it "rewrites only the version string" do
    expect(described_class.bump(source, "0.2.0")).to eq(source.sub("0.1.0", "0.2.0"))
  end

  it "refuses a source with no VERSION constant" do
    expect { described_class.current("module Snoot; end") }
      .to raise_error(ReleasePrep::Error, /VERSION/)
  end
end
