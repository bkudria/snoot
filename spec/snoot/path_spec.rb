# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- value Path { raw: String }
RSpec.describe Snoot::Path do
  it "value-equality.Path: structural equality on raw", :aggregate_failures do
    a = described_class.new(raw: "lib/foo.rb")
    b = described_class.new(raw: "lib/foo.rb")
    expect(a).to eq(b)
    expect(a).to eql(b)
    expect(a.hash).to eq(b.hash)
  end

  it "entity-fields.Path: declares raw as String", :aggregate_failures do
    p = described_class.new(raw: "lib/foo.rb")
    expect(p.raw).to eq("lib/foo.rb")
    expect(p.raw).to be_a(String)
  end
end
