# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- rule AnalyseRun emits SkippedDocLessSmellWarned;
# the implementation also surfaces an AnalysisFailed audit record for the
# analysis_failed branch. AnalyseRun::Event is the marker module sum-typing
# both records.
RSpec.describe Snoot::AnalyseRun::Event do
  describe "sum-type-variant.AnalysisFailed" do
    it "AnalysisFailed is a member of the AnalyseRun::Event sum type", :aggregate_failures do
      run = build_run_at(:analysis_failed)
      ev = Snoot::AnalyseRun::AnalysisFailed.new(run: run)
      expect(ev).to be_a(Snoot::AnalyseRun::AnalysisFailed)
      expect(ev).to be_a(described_class)
    end
  end

  describe "sum-type-variant.SkippedDocLessSmellWarned" do
    let(:ev) do
      Snoot::AnalyseRun::SkippedDocLessSmellWarned.new(
        run: build_run_at(:nothing_to_report),
        smell_type: build_smell_type(name: "Undocumented")
      )
    end

    it "SkippedDocLessSmellWarned is a member of the AnalyseRun::Event sum type", :aggregate_failures do
      expect(ev).to be_a(Snoot::AnalyseRun::SkippedDocLessSmellWarned)
      expect(ev).to be_a(described_class)
    end
  end
end
