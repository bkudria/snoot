# frozen_string_literal: true

module Snoot
  module AnalyseRun
    # SourcesView wraps a Snoot::Sources value with the orchestration
    # that produced it, so downstream phases can ask for derived views
    # (`significant_union`, `candidates`) and consult `vendored_doc?`
    # without re-threading orchestration through every helper. The
    # underlying Sources is the spec-level value type returned by
    # AnalyserOrchestration#analyse.
    SourcesView = Data.define(:sources, :orchestration) do
      def smells = sources.smells
      def complexities = sources.complexities
      def duplications = sources.duplications

      def significant_union
        significant_smells | significant_complexities | significant_duplications
      end

      def candidates
        documented = significant_smells.select { |smell| vendored_doc(smell.smell_type) }.to_set
        documented | significant_complexities | significant_duplications
      end

      def significant_smells = orchestration.significant_smells(smells)
      def significant_complexities = orchestration.significant_complexities(complexities)
      def significant_duplications = orchestration.significant_duplications(duplications)

      def vendored_doc(smell_type)
        orchestration.vendored_doc(smell_type)
      end
    end
  end
end
