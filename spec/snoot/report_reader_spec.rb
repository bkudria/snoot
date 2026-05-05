# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- surface ReportReader
#   facing reader: ReportConsumer
#   context run: Run where outcome = finding_rendered
#   exposes: run.selected_finding, run.selected_finding.kind
RSpec.describe Snoot::ReportReader do
  describe "surface-actor.ReportReader" do
    it "is accessible to a ReportConsumer when run.outcome = finding_rendered" do
      reader_actor = build_report_consumer
      run = build_run_at(:finding_rendered, with_finding: build_smell_with_doc)
      expect(described_class.for(reader_actor, run: run)).not_to be_nil
    end

    it "is absent (no instance) when run.outcome != finding_rendered" do
      reader_actor = build_report_consumer
      %i[pending nothing_to_report analysis_failed].each do |state|
        run = build_run_at(state)
        expect(described_class.for(reader_actor, run: run)).to be_nil
      end
    end
  end

  describe "surface-exposure.ReportReader" do
    it "exposes run.selected_finding and run.selected_finding.kind", :aggregate_failures do
      reader_actor = build_report_consumer
      run = build_run_at(:finding_rendered, with_finding: build_smell_with_doc)
      reader = described_class.for(reader_actor, run: run)
      expect(reader.selected_finding).to eq(run.selected_finding)
      expect(reader.kind).to eq(run.selected_finding.kind)
    end
  end
end
