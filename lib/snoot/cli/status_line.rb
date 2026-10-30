# frozen_string_literal: true

module Snoot
  module CLI
    # The last stdout line of every accepted invocation: a fixed prefix,
    # the outcome name, then key=value fields whose values never contain
    # spaces, so a script can split it without parsing the report.
    module StatusLine
      PREFIX = "snoot-status: "
      CATEGORIES = { Smell => "smell", DuplicationCluster => "duplication", ComplexityHit => "complexity" }.freeze

      module_function

      def for_run(run, remaining)
        case run.outcome
        when :finding_rendered then line(:finding_rendered, **finding_fields(run.selected_finding, remaining))
        when :analysis_failed then line(:analysis_failed, analyser: run.failure.analyser)
        else line(run.outcome)
        end
      end

      def internal_error(error)
        line(:internal_error, error: error.class.name)
      end

      def finding_fields(finding, remaining)
        type = finding.smell_type.name if finding.is_a?(Smell)
        { category: CATEGORIES.fetch(finding.class), type:, remaining: remaining_total(remaining) }.compact
      end

      def remaining_total(remaining)
        remaining.smell_types + remaining.duplication_clusters + remaining.complexity_hits
      end

      def line(outcome, **fields)
        [PREFIX + outcome.to_s, *fields.map { |key, value| "#{key}=#{value}" }].join(" ") << "\n"
      end
    end
  end
end
