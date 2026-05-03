require "spec_helper"

# Spec source: snoot.allium -- value Path { raw: String }
RSpec.describe "Path value" do
  it "value-equality.Path: structural equality on raw" do
    skip "bridge: Snoot::Path not implemented"
    a = Snoot::Path.new(raw: "lib/foo.rb")
    b = Snoot::Path.new(raw: "lib/foo.rb")
    expect(a).to eq(b)
    expect(a).to eql(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.Path: declares raw as String" do
    skip "bridge: Snoot::Path not implemented"
    p = Snoot::Path.new(raw: "lib/foo.rb")
    expect(p.raw).to eq("lib/foo.rb")
    expect(p.raw).to be_a(String)
  end
end
