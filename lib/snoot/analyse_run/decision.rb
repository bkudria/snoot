# frozen_string_literal: true

module Snoot
  module AnalyseRun
    # Internal collaborator: bundles an AnalyserOrchestration with the
    # Sources it produced so the chained selection helpers can share
    # both as state instead of threading the pair through every call.
    class Decision
      def initialize(orchestration:, sources:)
        @orchestration = orchestration
        @sources = sources
      end

      def resolve(run)
        pool = candidates
        selected = AnalyseRun.select_top_finding(pool)
        terminal = if selected
                     run.transition_to(:finding_rendered, selected_finding: selected)
                   else
                     run.transition_to(:nothing_to_report)
                   end
        Result.new(run: terminal, events: doc_less_events(terminal), smells: @sources.smells,
                   remaining: remaining(pool, selected))
      end

      private

      def remaining(pool, selected)
        others = pool - [selected]
        selected_type = selected.smell_type if selected.is_a?(Smell)
        RemainingFindings.new(
          smell_types: (others.grep(Smell).map(&:smell_type).uniq - [selected_type]).size,
          duplication_clusters: others.grep(DuplicationCluster).size,
          complexity_hits: others.grep(ComplexityHit).size,
          below_cutoff_smell_types: below_cutoff_smell_types
        )
      end

      def below_cutoff_smell_types
        smells = @sources.smells
        significant = @orchestration.significant_smells(smells).map(&:smell_type)
        (smells.map(&:smell_type).uniq - significant).sort_by(&:name)
      end

      def candidates
        documented = @orchestration.significant_smells(@sources.smells)
                                   .select { |smell| @orchestration.vendored_doc(smell.smell_type) }
                                   .to_set
        documented |
          @orchestration.significant_complexities(@sources.complexities) |
          @orchestration.significant_duplications(@sources.duplications)
      end

      def top_significant_smell
        significant = @orchestration.significant_smells(@sources.smells)
        AnalyseRun.top_smell(significant) if significant.any?
      end

      def doc_less_smell_type
        smell = top_significant_smell
        return nil unless smell

        smell_type = smell.smell_type
        return nil if @orchestration.vendored_doc(smell_type)

        smell_type
      end

      def doc_less_events(run)
        smell_type = doc_less_smell_type
        return [] unless smell_type

        [SkippedDocLessSmellWarned.new(run: run, smell_type: smell_type)]
      end
    end
  end
end
