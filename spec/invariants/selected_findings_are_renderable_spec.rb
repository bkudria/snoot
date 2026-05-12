# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Invariant: SelectedFindingsAreRenderable" do # rubocop:disable RSpec/DescribeClass
  describe "invariant.SelectedFindingsAreRenderable" do
    it "AnalyseRun's selection ensures any rendered Smell has a vendored doc" do
      real_type = Snoot::SmellType.new(name: "FeatureEnvy")
      smell = build_smell(smell_type: real_type)
      orch = fake_orchestration(smells: Set[smell], vendored_docs: { "FeatureEnvy" => "## doc" })
      Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch) => { run: }

      expect(Snoot::AnalyserOrchestration::Default.vendored_doc(run.selected_finding.smell_type)).not_to be_nil
    end

    it "holds after AnalyseRun for arbitrary analyser outputs", :pbt do
      forall(analyse_run_inputs_gen) do |inputs|
        run = run_analyse_with_inputs(inputs)
        next unless run.outcome == :finding_rendered && run.selected_finding.is_a?(Snoot::Smell)

        expect(Snoot::AnalyserOrchestration::Default.vendored_doc(run.selected_finding.smell_type)).not_to be_nil
      end
    end
  end
end
