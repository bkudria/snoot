# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- value AnalyserFailure { analyser, message }
# Carries the failed analyser tag (one of :reek, :flog, :flay) and the
# human-readable error message surfaced on outcome = analysis_failed.
RSpec.describe Snoot::AnalyserFailure do
  describe "value-fields.AnalyserFailure" do
    it "exposes analyser as a Symbol and message as a String", :aggregate_failures do
      failure = described_class.new(analyser: :reek, message: "boom")
      expect(failure.analyser).to eq(:reek)
      expect(failure.message).to eq("boom")
    end

    it "accepts each canonical analyser tag (:reek, :flog, :flay)", :aggregate_failures do
      %i[reek flog flay].each do |tag|
        failure = described_class.new(analyser: tag, message: "x")
        expect(failure.analyser).to eq(tag)
      end
    end
  end

  describe "value-equality.AnalyserFailure" do
    it "compares equal when analyser and message match" do
      a = described_class.new(analyser: :flog, message: "score too high")
      b = described_class.new(analyser: :flog, message: "score too high")
      expect(a).to eq(b)
    end

    it "compares unequal when analyser differs" do
      a = described_class.new(analyser: :reek, message: "x")
      b = described_class.new(analyser: :flog, message: "x")
      expect(a).not_to eq(b)
    end

    it "compares unequal when message differs" do
      a = described_class.new(analyser: :reek, message: "x")
      b = described_class.new(analyser: :reek, message: "y")
      expect(a).not_to eq(b)
    end
  end
end
