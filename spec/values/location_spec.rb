require "spec_helper"

# Spec source: snoot.allium -- value Location { path: Path, line_start: Integer, line_end: Integer }
RSpec.describe "Location value" do
  it "value-equality.Location: structural equality on (path, line_start, line_end)" do
    skip "bridge: Snoot::Location not implemented"
    path = Snoot::Path.new(raw: "lib/foo.rb")
    a = Snoot::Location.new(path: path, line_start: 10, line_end: 20)
    b = Snoot::Location.new(path: path, line_start: 10, line_end: 20)
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.Location: declares path, line_start, line_end" do
    skip "bridge: Snoot::Location not implemented"
    path = Snoot::Path.new(raw: "lib/foo.rb")
    loc = Snoot::Location.new(path: path, line_start: 10, line_end: 20)
    expect(loc.path).to eq(path)
    expect(loc.line_start).to eq(10)
    expect(loc.line_end).to eq(20)
    expect(loc.line_start).to be_a(Integer)
    expect(loc.line_end).to be_a(Integer)
  end
end
