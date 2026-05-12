# frozen_string_literal: true

require "spec_helper"

RSpec.describe Snoot::Location do
  describe "#description" do
    it "renders 'path:line_start-line_end'" do
      loc = described_class.new(path: Snoot::Path.new(raw: "lib/x.rb"), line_start: 10, line_end: 20)
      expect(loc.description).to eq("lib/x.rb:10-20")
    end
  end
end
