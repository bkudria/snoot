# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

# Spec source: snoot.allium -- variant ComplexityHit : Finding
RSpec.describe Snoot::ComplexityHit do
  describe ".from_flog_entry" do
    let(:entry) do
      described_class.from_flog_entry(
        class_method: "Foo#bar", score: 12.5, raw_location: "lib/foo.rb:42"
      )
    end

    it "constructs a ComplexityHit" do
      expect(entry).to be_a(described_class)
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
      hit = described_class.from_flog_entry(
        class_method: "Foo#bar", score: 5, raw_location: "lib/foo.rb:42-50"
      )
      expect(hit.location.line_start).to eq(42).and eq(hit.location.line_end)
    end

    it "returns nil when raw_location is missing" do
      expect(
        described_class.from_flog_entry(class_method: "main#none", score: 1, raw_location: nil)
      ).to be_nil
    end

    it "returns nil when raw_location lacks a colon-separated range" do
      expect(
        described_class.from_flog_entry(class_method: "main#none", score: 1, raw_location: "no_range")
      ).to be_nil
    end
  end
end
