# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- value Location { path: Path, line_start: Integer, line_end: Integer }
RSpec.describe Snoot::Location do
  let(:path) { Snoot::Path.new(raw: "lib/foo.rb") }

  it "value-equality.Location: structural equality on (path, line_start, line_end)", :aggregate_failures do
    a = described_class.new(path: path, line_start: 10, line_end: 20)
    b = described_class.new(path: path, line_start: 10, line_end: 20)
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.Location: declares path, line_start, line_end", :aggregate_failures do
    loc = described_class.new(path: path, line_start: 10, line_end: 20)
    expect(loc.path).to eq(path)
    expect(loc.line_start).to eq(10).and(be_a(Integer))
    expect(loc.line_end).to eq(20).and(be_a(Integer))
  end

  describe "#description" do
    it "renders 'path:line_start-line_end'" do
      loc = described_class.new(path: Snoot::Path.new(raw: "lib/x.rb"), line_start: 10, line_end: 20)
      expect(loc.description).to eq("lib/x.rb:10-20")
    end
  end
end
