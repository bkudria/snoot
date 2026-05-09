# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- surface CLI provides RunInvoked and ReportEmitted.
# CLI::Event is the marker module sum-typing the two CLI-emitted audit records.
RSpec.describe Snoot::CLI::Event do
  describe "sum-type-variant.RunInvoked" do
    it "RunInvoked is a member of the Event sum type", :aggregate_failures do
      ev = Snoot::CLI::RunInvoked.new(operator: build_operator, paths: Set[])
      expect(ev).to be_a(Snoot::CLI::RunInvoked)
      expect(ev).to be_a(described_class)
      expect(ev.name).to eq(:run_invoked)
    end
  end

  describe "sum-type-variant.ReportEmitted" do
    let(:smell) { build_smell }
    let(:run) { build_run_with_finding(smell) }
    let(:ev) do
      Snoot::CLI::ReportEmitted.new(operator: build_operator, paths: run.paths,
                                    run: run, finding: smell, sections: { doc: "x" })
    end

    it "ReportEmitted is a member of the Event sum type", :aggregate_failures do
      expect(ev).to be_a(Snoot::CLI::ReportEmitted)
      expect(ev).to be_a(described_class)
      expect(ev.name).to eq(:report_emitted)
    end
  end
end
