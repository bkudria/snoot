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

      def smell_from_reek_warning(warning)
        lines = warning.lines
        Smell.new(
          smell_type: SmellType.new(name: warning.smell_type),
          location: Location.new(
            path: Path.new(raw: warning.source),
            line_start: lines.first,
            line_end: lines.last
          ),
          message: "#{warning.context} #{warning.message}"
        )
      end

      # Flog stores method locations as "file:line" or "file:line-line_max".
      # Returns nil when the entry is missing (e.g. main#none) so callers
      # can skip top-level expressions that lack a method-level location.
      def complexity_hit_from_flog_entry(class_method:, score:, raw_location:)
        file, range = raw_location.to_s.split(":", 2)
        return unless file && range

        line_start, = range.split("-", 2).map(&:to_i)
        ComplexityHit.new(
          location: Location.new(path: Path.new(raw: file), line_start: line_start, line_end: line_start),
          method_name: class_method,
          score: BigDecimal(score.to_s)
        )
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
