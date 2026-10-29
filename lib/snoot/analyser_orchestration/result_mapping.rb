# frozen_string_literal: true

require "bigdecimal"

module Snoot
  module AnalyserOrchestration
    # ResultMapping converts third-party analyser outputs (Reek warnings,
    # Flog totals entries, Flay items) into Snoot value objects. Pure: no
    # IO, no third-party invocation. Default consumes these mappers
    # internally as it drives reek/flog/flay; tests target this module's
    # public surface directly with input doubles.
    module ResultMapping
      module_function

      def smell_from_reek_warning(warning, file_lines = nil)
        lines = warning.lines
        Smell.new(
          smell_type: SmellType.new(name: warning.smell_type),
          location: Location.new(path: Path.new(raw: warning.source), line_start: lines.first, line_end: lines.last),
          message: "#{warning.context} #{warning.message}",
          source_lines: source_lines_for(lines, file_lines)
        )
      end

      def source_lines_for(numbers, file_lines)
        numbers.uniq.sort.map { |number| SourceLine.new(number:, text: file_lines&.[](number - 1)) }
      end

      # Flog stores method locations as "file:line" or "file:line-line_max".
      # Returns nil when the entry is missing (e.g. main#none) so callers
      # can skip top-level expressions that lack a method-level location.
      def complexity_hit_from_flog_entry(class_method:, score:, raw_location:, calls: {}, file_lines: nil)
        file, range = raw_location.to_s.split(":", 2)
        return unless file && range

        line_start, line_max = range.split("-", 2).map(&:to_i)
        line_end = line_max || line_start
        ComplexityHit.new(
          location: Location.new(path: Path.new(raw: file), line_start:, line_end:),
          method_name: class_method, score: BigDecimal(score.to_s),
          breakdown: breakdown_from_flog_calls(calls),
          source_lines: source_lines_for((line_start..line_end).to_a, file_lines)
        )
      end

      BRANCHING_OPERATIONS = %w[branch block_call].freeze

      # Mirrors Flog#score_method's grouping of operations into A, B and C.
      def breakdown_from_flog_calls(calls)
        branching, others = score_contributions(calls).partition do |contribution|
          BRANCHING_OPERATIONS.include?(contribution.operation)
        end
        assignments, calls_and_other = others.partition { |contribution| contribution.operation == "assignment" }
        ComplexityBreakdown.new(assignments:, branching:, calls: calls_and_other)
      end

      def score_contributions(calls)
        calls.map { |operation, score| ScoreContribution.new(operation: operation.to_s, score: BigDecimal(score.to_s)) }
             .sort_by { |contribution| [-contribution.score, contribution.operation] }
      end

      def duplication_cluster_from_flay_item(item)
        locations = item.locations.each_with_object(Set[]) do |loc, set|
          line = loc.line
          set << Location.new(path: Path.new(raw: loc.file), line_start: line, line_end: line)
        end
        DuplicationCluster.new(signature: item.structural_hash.to_s, locations: locations)
      end
    end
  end
end
