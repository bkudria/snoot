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

    def unordered_warning
      double(smell_type: "FeatureEnvy", source: "lib/foo.rb", lines: [3, 1, 2, 1], context: "C", message: "m")
    end

    it "lists every flagged line once, ascending, with its text from the file lines" do
      smell = described_class.smell_from_reek_warning(unordered_warning, %w[one two three])
      expect(smell.source_lines).to eq(
        [[1, "one"], [2, "two"], [3, "three"]].map { |number, text| Snoot::SourceLine.new(number:, text:) }
      )
    end

    it "leaves each flagged line's text nil when no file lines are given" do
      smell = described_class.smell_from_reek_warning(unordered_warning)
      expect(smell.source_lines.map(&:text)).to eq([nil, nil, nil])
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

    def spanning_hit(**)
      described_class.complexity_hit_from_flog_entry(
        class_method: "Foo#bar", score: 5, raw_location: "lib/foo.rb:42-44", **
      )
    end

    def contributions(*pairs)
      pairs.map { |operation, score| Snoot::ScoreContribution.new(operation:, score: BigDecimal(score.to_s)) }
    end

    it "spans 'file:line-line_max' from line to line_max" do
      expect(spanning_hit.location).to have_attributes(line_start: 42, line_end: 44)
    end

    it "carries every line of the span with the file's text" do
      file_lines = Array.new(41, "") + ["def bar", "  1", "end"]
      expect(spanning_hit(file_lines:).source_lines.map(&:to_h)).to eq(
        [{ number: 42, text: "def bar" }, { number: 43, text: "  1" }, { number: 44, text: "end" }]
      )
    end

    it "leaves source text nil when the file wasn't read" do
      expect(spanning_hit.source_lines.map(&:text)).to eq([nil, nil, nil])
    end

    it "groups flog's per-operation scores the way flog's formula does, each descending" do
      calls = { assignment: 2.0, branch: 1.5, block_call: 3.0, each: 1.0, magic_number: 2.5 }
      expect(spanning_hit(calls:).breakdown.to_h).to eq(
        assignments: contributions(["assignment", 2.0]), branching: contributions(["block_call", 3.0], ["branch", 1.5]),
        calls: contributions(["magic_number", 2.5], ["each", 1.0])
      )
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
