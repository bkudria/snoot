# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- value Sources { smells, complexities, duplications }
RSpec.describe Snoot::Sources do
  subject(:sources) do
    described_class.new(smells: Set[smell], complexities: Set[complexity], duplications: Set[duplication])
  end

  let(:smell)       { build_smell }
  let(:complexity)  { build_complexity_hit }
  let(:duplication) { build_duplication_cluster }

  it "entity-fields.Sources: exposes smells, complexities, duplications", :aggregate_failures do
    expect(sources.smells).to eq(Set[smell])
    expect(sources.complexities).to eq(Set[complexity])
    expect(sources.duplications).to eq(Set[duplication])
  end

  it "value-equality.Sources: structural equality on the three fields" do
    a = described_class.new(smells: Set[smell], complexities: Set[], duplications: Set[])
    b = described_class.new(smells: Set[smell], complexities: Set[], duplications: Set[])
    expect(a).to eq(b)
  end

  it "immutability.Sources: with(...) yields a new value, leaving the original intact", :aggregate_failures do
    original = described_class.new(smells: Set[], complexities: Set[], duplications: Set[])
    updated = original.with(smells: Set[smell])
    expect(updated.smells).to eq(Set[smell])
    expect(original.smells).to eq(Set[])
  end
end
