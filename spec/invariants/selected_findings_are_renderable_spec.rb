# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SelectedFindingsAreRenderable
#   for r in Runs:
#     for s in Smells:
#       (r.outcome = finding_rendered and r.selected_finding = s)
#         implies vendored_doc(s.smell_type) != null
RSpec.describe "Invariant: SelectedFindingsAreRenderable" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.SelectedFindingsAreRenderable" do
    it "AnalyseRun's selection ensures any rendered Smell has a vendored doc" do
      real_type = Snoot::SmellType.new(name: "FeatureEnvy")
      smell = build_smell(smell_type: real_type)
      orch = fake_orchestration(smells: Set[smell], vendored_docs: { "FeatureEnvy" => "## doc" })
      run, _events = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)

      expect(Snoot.vendored_doc(run.selected_finding.smell_type)).not_to be_nil
    end

    it "holds after AnalyseRun for arbitrary analyser outputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        next unless run.outcome == :finding_rendered && run.selected_finding.is_a?(Snoot::Smell)

        expect(Snoot.vendored_doc(run.selected_finding.smell_type)).not_to be_nil
      end
    end
  end
end
