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
        terminal = transition(run, selected_candidate)
        Result.new(
          run: terminal,
          events: doc_less_events(terminal),
          smells: @sources.smells
        )
      end

      private

      def selected_candidate
        AnalyseRun.select_top_finding(candidates)
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

      def transition(run, selected)
        return run.transition_to(:nothing_to_report) if selected.nil?

        run.transition_to(:finding_rendered, selected_finding: selected)
      end

      def doc_less_events(run)
        smell_type = doc_less_smell_type
        return [] unless smell_type

        [SkippedDocLessSmellWarned.new(run: run, smell_type: smell_type)]
      end
    end
  end
end
