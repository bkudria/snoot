# frozen_string_literal: true

require "spec_helper"

# Spec source: pure Ruby module -- ResultMapping converts third-party
# analyser outputs (Reek warnings, Flog totals entries, Flay items) into
# Snoot value objects. No Allium contract; tested as a Ruby module.
RSpec.describe Snoot::AnalyserOrchestration::ResultMapping do
  describe ".smell_from_reek_warning" do
    subject(:smell) { described_class.smell_from_reek_warning(warning) }

    let(:warning) do
      double(
        smell_type: "FeatureEnvy",
        source: "lib/foo.rb",
        lines: [10, 20],
        context: "Foo#bar",
        message: "envies another object"
      )
    end

    it { is_expected.to be_a(Snoot::Smell) }

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

  describe ".complexity_hit_from_flog_entry" do
    let(:entry) do
      described_class.complexity_hit_from_flog_entry(
        class_method: "Foo#bar", score: 12.5, raw_location: "lib/foo.rb:42"
      )
    end

    it "constructs a ComplexityHit" do
      expect(entry).to be_a(Snoot::ComplexityHit)
    end

    it "parses location from 'file:line'" do
      expect(entry.location).to eq(
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/foo.rb"), line_start: 42, line_end: 42)
      )
    end

    it "carries class_method as method_name" do
      expect(entry.method_name).to eq("Foo#bar")
    end

    it "wraps score as BigDecimal" do
      expect(entry.score).to eq(BigDecimal("12.5"))
    end

    it "accepts 'file:line-line_max' (uses line for both start and end)" do
      hit = described_class.complexity_hit_from_flog_entry(
        class_method: "Foo#bar", score: 5, raw_location: "lib/foo.rb:42-50"
      )
      expect(hit.location.line_start).to eq(42).and eq(hit.location.line_end)
    end

    it "returns nil when raw_location is missing" do
      expect(
        described_class.complexity_hit_from_flog_entry(class_method: "main#none", score: 1, raw_location: nil)
      ).to be_nil
    end

    it "returns nil when raw_location lacks a colon-separated range" do
      expect(
        described_class.complexity_hit_from_flog_entry(class_method: "main#none", score: 1, raw_location: "no_range")
      ).to be_nil
    end
  end

  describe ".duplication_cluster_from_flay_item" do
    subject(:cluster) { described_class.duplication_cluster_from_flay_item(item) }

    let(:flay_location_a) { double(file: "lib/a.rb", line: 5) }
    let(:flay_location_b) { double(file: "lib/b.rb", line: 17) }
    let(:item) do
      double(structural_hash: 4242, locations: [flay_location_a, flay_location_b])
    end
    let(:expected_locations) do
      Set[
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/a.rb"), line_start: 5, line_end: 5),
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/b.rb"), line_start: 17, line_end: 17)
      ]
    end

    it { is_expected.to be_a(Snoot::DuplicationCluster) }

    it "stringifies item.structural_hash into the signature" do
      expect(cluster.signature).to eq("4242")
    end

    it "maps every flay location into a Snoot::Location with line_start = line_end" do
      expect(cluster.locations).to eq(expected_locations)
    end
  end
end
