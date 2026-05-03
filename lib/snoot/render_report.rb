module Snoot
  # RenderReport is the rule from snoot.allium that, given a Run whose
  # outcome is :finding_rendered, produces a Report containing four
  # ordered sections (header, finding_context, doc, framing). Section
  # content varies by Finding variant. The orchestration supplies
  # describe_location and vendored_doc; non-Smell variants take their
  # doc from in-module prose constants.
  module RenderReport
    SECTION_ORDER = %i[header finding_context doc framing].freeze

    FRAMING_PLACEHOLDER = "[framing prose: see snoot.allium open question]".freeze

    COMPLEXITY_DOC =
      "High complexity hits indicate a method or class doing too much. " \
      "Consider extracting helpers, simplifying conditionals, or " \
      "splitting the responsibility across smaller units.".freeze

    DUPLICATION_DOC =
      "Structural duplication suggests an extracted abstraction is missing. " \
      "Consider whether the duplicated shape belongs to a single helper, " \
      "module, or value type.".freeze

    Report = Data.define(:run, :finding, :sections)

    module_function

    def invoke(run, orchestration:)
      finding = run.selected_finding
      raise StateError, "selected_finding is required for RenderReport (got nil)" if finding.nil?

      sections = {
        header: render_header(finding, orchestration),
        finding_context: render_finding_context(finding, orchestration),
        doc: render_doc(finding, orchestration),
        framing: FRAMING_PLACEHOLDER
      }
      Report.new(run: run, finding: finding, sections: sections)
    end

    def render_header(finding, orch)
      case finding
      when Smell
        "#{finding.smell_type.name} at #{orch.describe_location(finding.location)}"
      when ComplexityHit
        "High complexity in #{finding.method_name} at " \
        "#{orch.describe_location(finding.location)} (score: #{finding.score.to_s('F')})"
      when DuplicationCluster
        "Structural duplication: #{finding.locations.size} locations " \
        "(signature: #{finding.signature})"
      end
    end

    def render_finding_context(finding, orch)
      case finding
      when Smell
        "#{orch.describe_location(finding.location)}\n\n#{finding.message}"
      when ComplexityHit
        "#{orch.describe_location(finding.location)}\n\n" \
        "Method: #{finding.method_name}\nScore: #{finding.score.to_s('F')}"
      when DuplicationCluster
        "Locations:\n#{finding.locations.map { |l| orch.describe_location(l) }.join("\n")}"
      end
    end

    def render_doc(finding, orch)
      case finding
      when Smell then orch.vendored_doc(finding.smell_type)
      when ComplexityHit then COMPLEXITY_DOC
      when DuplicationCluster then DUPLICATION_DOC
      end
    end
  end
end
