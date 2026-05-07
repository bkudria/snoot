# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant FailurePresentOnFailedRuns
#   for r in Runs:
#     r.outcome = analysis_failed implies r.failure != null
RSpec.describe "Invariant: FailurePresentOnFailedRuns" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.FailurePresentOnFailedRuns" do
    it "is enforced at construction" do
      expect do
        Snoot::Run.new(paths: Set[], outcome: :analysis_failed, failure: nil)
      end.to raise_error(Snoot::StateError, /failure/)
    end

    it "holds after AnalyseRun for arbitrary inputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        expect(run.failure).not_to be_nil if run.outcome == :analysis_failed
      end
    end
  end
end
