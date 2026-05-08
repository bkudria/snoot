# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- invariant SignificantFindingsOnly
#   for r in Runs:
#     for s in Smells: r.selected_finding = s implies s ∈ significant_smells(r.smells)
#     for c in ComplexityHits: r.selected_finding = c implies c ∈ significant_complexities({c})
#     for d in DuplicationClusters: r.selected_finding = d implies d ∈ significant_duplications({d})
#
# This complements SelectedFindingsAreRenderable (which guards vendored docs)
# with the "warrants addressing" gate. Floors live in
# AnalyserOrchestration::Default. The smell branch uses r.smells because
# Default's smell-significance policy is collection-relative (count-based);
# complexity and duplication adapters are per-instance, so the singleton
# {f} suffices for those.
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

  describe "invariant.SignificantFindingsOnly" do
    it "drops a singleton smell + a sub-floor complexity to nothing_to_report" do
      orch = default_significance_class.new(smells: Set[singleton_smell], complexities: Set[sub_floor_hit],
                                            vendored_docs: { "FeatureEnvy" => "## doc" })
      run, = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "the selected finding survives its variant's significance check", :pbt do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      forall(analyse_run_inputs_gen) do |inputs|
        smells, complexities, duplications, _raise = inputs
        orch = default_significance_class.new(smells: smells, complexities: complexities,
                                              duplications: duplications, vendored_docs: real_reek_doc_map)
        run, = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)
        next unless run.outcome == :finding_rendered

        default = Snoot::AnalyserOrchestration::Default
        case run.selected_finding
        when Snoot::Smell
          expect(default.significant_smells(run.smells)).to include(run.selected_finding)
        when Snoot::ComplexityHit
          expect(default.significant_complexities(Set[run.selected_finding])).to include(run.selected_finding)
        when Snoot::DuplicationCluster
          expect(default.significant_duplications(Set[run.selected_finding])).to include(run.selected_finding)
        end
      end
    end
  end
end
