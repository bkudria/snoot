# frozen_string_literal: true

module Snoot
  module RenderReport
    # The sections of a ComplexityHit report. The context shows the span,
    # the score split into flog's three dimensions, and the method's code.
    module ComplexitySections
      DIMENSION_LABELS = {
        calls: "Calls and other (C)", branching: "Branching (B)", assignments: "Assignments (A)"
      }.freeze
      LABEL_WIDTH = DIMENSION_LABELS.values.map(&:size).max
      TOP_OPERATIONS = 4
      DOC = "High complexity hits indicate a method or class doing too much. " \
            "Consider extracting helpers, simplifying conditionals, or " \
            "splitting the responsibility across smaller units."

      module_function

      def build(hit)
        location = hit.location.description
        name = hit.method_name
        score = RenderReport.format_score(hit.score.round(2))
        {
          header: "High complexity in #{name} at #{location} (score: #{score})",
          finding_context: context(hit, location, name, score),
          doc: DOC
        }
      end

      def context(hit, location, name, score)
        formula = "Score: #{score} = √(A² + B² + C²)"
        summary = ["#{location}\n", "Method: #{name}", formula, *dimension_lines(hit.breakdown)]
        code = SourceExcerpt.block(hit.source_lines)
        (code.empty? ? summary : [*summary, "", *code]).join("\n")
      end

      def dimension_lines(breakdown)
        rows = ranked_dimensions(breakdown)
        totals = rows.map { |_, contributions| one_decimal(contributions.sum(&:score)) }
        width = totals.map(&:size).max
        rows.zip(totals).map do |(label, contributions), total|
          dimension_line(label, total.rjust(width), contributions)
        end
      end

      # Highest total first; ties keep DIMENSION_LABELS order.
      def ranked_dimensions(breakdown)
        rows = DIMENSION_LABELS.map { |key, label| [label, breakdown.public_send(key)] }
        rows.each_with_index.sort_by { |(_, contributions), order| [-contributions.sum(&:score), order] }.map(&:first)
      end

      def dimension_line(label, total, contributions)
        line = "  #{label.ljust(LABEL_WIDTH)} #{total}"
        contributions.empty? ? line : "#{line}  (#{operations(contributions)})"
      end

      def operations(contributions)
        shown = contributions.take(TOP_OPERATIONS).map do |contribution|
          "#{contribution.operation} #{one_decimal(contribution.score)}"
        end
        contributions.size > TOP_OPERATIONS ? [*shown, "…"].join(", ") : shown.join(", ")
      end

      def one_decimal(score)
        format("%.1f", score)
      end
    end
  end
end
