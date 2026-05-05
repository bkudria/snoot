# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant Smell : Finding
RSpec.describe Snoot::Smell do
  describe ".from_reek_warning" do
    subject(:smell) { described_class.from_reek_warning(warning) }

    let(:warning) do
      double(
        smell_type: "FeatureEnvy",
        source: "lib/foo.rb",
        lines: [10, 20],
        context: "Foo#bar",
        message: "envies another object"
      )
    end

    it { is_expected.to be_a(described_class) }

    it "carries the smell_type from warning.smell_type" do
      expect(smell.smell_type).to eq(Snoot::SmellType.new(name: "FeatureEnvy"))
    end

    it "carries the location from warning.source/.lines" do
      expect(smell.location).to eq(
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/foo.rb"), line_start: 10, line_end: 20)
      )
    end

    it "joins warning.context and warning.message into the message" do
      expect(smell.message).to eq("Foo#bar envies another object")
    end
  end
end
