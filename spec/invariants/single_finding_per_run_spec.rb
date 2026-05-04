# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SingleFindingPerRun
#   for r in Runs:
#     r.outcome = finding_rendered implies r.selected_finding != null
RSpec.describe "Invariant: SingleFindingPerRun" do
  describe "invariant.SingleFindingPerRun" do
    it "every persisted Run with outcome=finding_rendered has a non-nil selected_finding" do
      skip "bridge: Run audit / persistence not implemented"
      Snoot::Run.all.each do |run|
        next unless run.outcome == :finding_rendered

        expect(run.selected_finding).not_to be_nil
      end
    end

    it "holds after every state-changing rule that touches Run", :pbt do
      skip "bridge: PBT framework + transition action map not wired"
      # Plan: walk the declared transition graph (pending -> {finding_rendered,
      # nothing_to_report, analysis_failed}) via AnalyseRun, asserting the
      # implication after each transition.
    end
  end
end
