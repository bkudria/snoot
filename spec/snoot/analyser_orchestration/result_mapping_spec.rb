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
    subject(:cluster) { described_class.duplication_cluster_from_flay_item(item, nodes:, file_lines:) }

    let(:flay_location_a) { double(file: "lib/a.rb", line: 2) }
    let(:flay_location_b) { double(file: "lib/b.rb", line: 3) }
    let(:item) do
      double(structural_hash: 4242, name: :defn, identical?: nil, mass: 44,
             locations: [flay_location_a, flay_location_b])
    end
    let(:nodes) { [double(file: "lib/b.rb", line: 3, line_max: 4), double(file: "lib/a.rb", line: 2, line_max: 3)] }
    let(:file_lines) { { "lib/a.rb" => %w[a1 a2 a3 a4], "lib/b.rb" => %w[b1 b2 b3 b4] } }

    def location(raw, line_start, line_end)
      Snoot::Location.new(path: Snoot::Path.new(raw:), line_start:, line_end:)
    end

    def copy_texts(cluster)
      cluster.copies.map { |copy| [copy.location.description, copy.source_lines.map(&:text)] }
    end

    it { is_expected.to be_a(Snoot::DuplicationCluster) }

    it "stringifies item.structural_hash into the signature" do
      expect(cluster.signature).to eq("4242")
    end

    it "spans each location to its node's last line" do
      expect(cluster.locations).to eq(Set[location("lib/a.rb", 2, 3), location("lib/b.rb", 3, 4)])
    end

    it "falls back to a one-line span when no node matches a location" do
      cluster = described_class.duplication_cluster_from_flay_item(item)
      expect(cluster.locations).to eq(Set[location("lib/a.rb", 2, 2), location("lib/b.rb", 3, 3)])
    end

    it "keeps flay's node type and total mass" do
      expect([cluster.node_type, cluster.mass]).to eq(["defn", 44])
    end

    it "divides the mass by the copy count for similar copies" do
      expect([cluster.identical, cluster.copy_mass]).to eq([false, 22])
    end

    it "divides the mass by the copy count twice for identical copies, as flay multiplies it twice" do
      allow(item).to receive_messages(identical?: "*2", mass: 76)
      expect([cluster.identical, cluster.copy_mass]).to eq([true, 19])
    end

    it "holds each copy's span text, ordered by path then line" do
      expect(copy_texts(cluster)).to eq([["lib/a.rb:2-3", %w[a2 a3]], ["lib/b.rb:3-4", %w[b3 b4]]])
    end

    it "leaves a copy's text nil when its file couldn't be read" do
      cluster = described_class.duplication_cluster_from_flay_item(item, nodes:)
      expect(cluster.copies.flat_map(&:source_lines).map(&:text)).to all(be_nil)
    end
  end
end
