# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- value SmellType { name: String }
RSpec.describe Snoot::SmellType do
  it "value-equality.SmellType: structural equality on name" do
    a = described_class.new(name: "FeatureEnvy")
    b = described_class.new(name: "FeatureEnvy")
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.SmellType: declares name as String" do
    s = described_class.new(name: "FeatureEnvy")
    expect(s.name).to eq("FeatureEnvy")
    expect(s.name).to be_a(String)
  end
end
