# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SelectedFindingsAreRenderable
#   for r in Runs:
#     for s in Smells:
#       (r.outcome = finding_rendered and r.selected_finding = s)
#         implies vendored_doc(s.smell_type) != null
RSpec.describe "Invariant: SelectedFindingsAreRenderable" do
  describe "invariant.SelectedFindingsAreRenderable" do
    it "every rendered Smell selection has a vendored doc available" do
      skip "bridge: Run audit + vendored_doc lookup not implemented"
      Snoot::Run.all.each do |run|
        next unless run.outcome == :finding_rendered

        finding = run.selected_finding
        next unless finding.is_a?(Snoot::Smell)

        expect(Snoot.vendored_doc(finding.smell_type)).not_to be_nil
      end
    end

    it "holds after AnalyseRun for arbitrary analyser outputs", :pbt do
      skip "bridge: PBT framework + AnalyseRun action not wired"
      # Plan: generate arbitrary mixes of (doc-having, doc-less) smells plus
      # complexity hits and duplication clusters, run AnalyseRun, check the
      # implication on the resulting Run.
    end
  end
end
