# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- contract AnalyserOrchestration#vendored_doc
# surfaced at module scope as Snoot.vendored_doc.
RSpec.describe Snoot do
  describe ".vendored_doc" do
    it "returns the reek-bundled doc for a known smell type" do
      expect(described_class.vendored_doc(Snoot::SmellType.new(name: "FeatureEnvy"))).not_to be_nil
    end

    it "returns nil for an unknown smell type" do
      expect(described_class.vendored_doc(Snoot::SmellType.new(name: "NotASmell"))).to be_nil
    end
  end
end
