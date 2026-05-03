require "spec_helper"

# Spec source: snoot.allium -- value SmellType { name: String }
RSpec.describe "SmellType value" do
  it "value-equality.SmellType: structural equality on name" do
    skip "bridge: Snoot::SmellType not implemented"
    a = Snoot::SmellType.new(name: "FeatureEnvy")
    b = Snoot::SmellType.new(name: "FeatureEnvy")
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.SmellType: declares name as String" do
    skip "bridge: Snoot::SmellType not implemented"
    s = Snoot::SmellType.new(name: "FeatureEnvy")
    expect(s.name).to eq("FeatureEnvy")
    expect(s.name).to be_a(String)
  end
end
