# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SingleFindingPerRun
#   for r in Runs:
#     r.outcome = finding_rendered implies r.selected_finding != null
RSpec.describe "Invariant: SingleFindingPerRun" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.SingleFindingPerRun" do
    it "is enforced at construction" do
      expect do
        Snoot::Run.new(paths: Set[], outcome: :finding_rendered, selected_finding: nil)
      end.to raise_error(Snoot::StateError, /selected_finding/)
    end

    it "holds after AnalyseRun for arbitrary inputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        expect(run.selected_finding).not_to be_nil if run.outcome == :finding_rendered
      end
    end
  end
end
