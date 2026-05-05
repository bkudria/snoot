# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SignificantFindingsOnly
#   for r in Runs:
#     r.outcome = finding_rendered implies
#       r.selected_finding ∈ (significant_smells ∪ significant_complexities ∪ significant_duplications)
#
# This complements SelectedFindingsAreRenderable (which guards vendored docs)
# with the "warrants addressing" gate. Floors live in
# AnalyserOrchestration::Default; the invariant is over the contract methods,
# not specific thresholds.
RSpec.describe "Invariant: SignificantFindingsOnly" do # rubocop:disable RSpec/DescribeClass
  let(:default_significance_class) do
    Class.new(Snoot::Spec::FakeOrchestration) do
      def significant_smells(smells)
        Snoot::AnalyserOrchestration::Default.significant_smells(smells)
      end

      def significant_complexities(complexities)
        Snoot::AnalyserOrchestration::Default.significant_complexities(complexities)
      end

      def significant_duplications(duplications)
        Snoot::AnalyserOrchestration::Default.significant_duplications(duplications)
      end
    end
  end

  let(:singleton_smell) { build_smell(smell_type: build_smell_type(name: "FeatureEnvy")) }
  let(:sub_floor_hit) { build_complexity_hit(score: BigDecimal("24.0")) }

  def significant_union(smells, complexities, duplications)
    default = Snoot::AnalyserOrchestration::Default
    default.significant_smells(smells).to_a +
      default.significant_complexities(complexities).to_a +
      default.significant_duplications(duplications).to_a
  end

  describe "invariant.SignificantFindingsOnly" do
    it "drops a singleton smell + a sub-floor complexity to nothing_to_report" do
      orch = default_significance_class.new(smells: Set[singleton_smell], complexities: Set[sub_floor_hit],
                                            vendored_docs: { "FeatureEnvy" => "## doc" })
      run, = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "selects a finding only from the significant union when finding_rendered", :pbt do # rubocop:disable RSpec/ExampleLength
      forall(analyse_run_inputs_gen) do |inputs|
        smells, complexities, duplications, _raise = inputs
        orch = default_significance_class.new(smells: smells, complexities: complexities,
                                              duplications: duplications, vendored_docs: real_reek_doc_map)
        run, = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)
        next unless run.outcome == :finding_rendered

        expect(significant_union(smells, complexities, duplications)).to include(run.selected_finding)
      end
    end
  end
end
