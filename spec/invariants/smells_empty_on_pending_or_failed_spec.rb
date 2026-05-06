# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SmellsEmptyOnPendingOrFailed
#   for r in Runs:
#     r.outcome in {pending, analysis_failed} implies r.smells.count = 0
#
# AnalyseRun never collects smells on the failure branch (first_failure
# aborts before reek_analyse runs); :pending Runs are constructed empty
# and only gain smells transiently in decide_outcome before transition.
# This invariant is observed against terminal Runs returned by
# AnalyseRun.invoke.
RSpec.describe "Invariant: SmellsEmptyOnPendingOrFailed" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.SmellsEmptyOnPendingOrFailed" do
    it "holds for analysis_failed runs" do
      run = invoke_analyse_run(orchestration: fake_orchestration(reek_raises: StandardError.new("boom")))
      expect(run.smells).to be_empty
    end

    it "holds for terminal runs returned by AnalyseRun under arbitrary inputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        expect(run.smells).to be_empty if %i[pending analysis_failed].include?(run.outcome)
      end
    end
  end
end
