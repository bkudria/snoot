# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Invariant: SingleFindingPerRun" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.SingleFindingPerRun" do
    it "holds after AnalyseRun for arbitrary inputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        expect(run.selected_finding).not_to be_nil if run.outcome == :finding_rendered
      end
    end
  end
end
