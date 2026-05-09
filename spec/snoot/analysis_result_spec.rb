# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- entity AnalysisResult + variants Sources | AnalyserFailure
RSpec.describe Snoot::AnalysisResult do
  describe "sum-type-variant.Sources" do
    it "Sources is a member of the AnalysisResult sum type", :aggregate_failures do
      sources = Snoot::Sources.new(smells: Set[], complexities: Set[], duplications: Set[])
      expect(sources).to be_a(Snoot::Sources)
      expect(sources).to be_a(described_class)
    end
  end

  describe "sum-type-variant.AnalyserFailure" do
    it "AnalyserFailure is a member of the AnalysisResult sum type", :aggregate_failures do
      failure = build_analyser_failure
      expect(failure).to be_a(Snoot::AnalyserFailure)
      expect(failure).to be_a(described_class)
    end
  end
end
