# frozen_string_literal: true

module Snoot
  # RenderReport is the rule from snoot.allium that, given a Run whose
  # outcome is :finding_rendered, produces a Report. For Smell findings
  # the Report has two sections (doc, instances) -- the doc comes from
  # the orchestration's vendored_doc and instances enumerates every
  # Smell of the selected type grouped by file, ordered by descending
  # count then alphabetical path. For ComplexityHit and DuplicationCluster
  # findings the four-section shape (header, finding_context, doc,
  # framing) is preserved.
  module RenderReport
    FRAMING_PLACEHOLDER = "[framing prose: see snoot.allium open question]"

    COMPLEXITY_DOC =
      "High complexity hits indicate a method or class doing too much. " \
      "Consider extracting helpers, simplifying conditionals, or " \
      "splitting the responsibility across smaller units."

    DUPLICATION_DOC =
      "Structural duplication suggests an extracted abstraction is missing. " \
      "Consider whether the duplicated shape belongs to a single helper, " \
      "module, or value type."

    # Report is the value returned by RenderReport.invoke: the source
    # Run, the selected Finding it was built from, and the ordered
    # sections hash that CLI joins into stdout output.
    Report = Data.define(:run, :finding, :sections)

    module_function

    def invoke(run, orchestration:)
      finding = run.selected_finding
      raise StateError, "selected_finding is required for RenderReport (got nil)" if finding.nil?

      sections = build_sections(run, finding, orchestration)
      Report.new(run: run, finding: finding, sections: sections)
    end

    def build_sections(run, finding, orchestration)
      return smell_sections(run, finding, orchestration) if finding.is_a?(Smell)

      non_smell_sections(finding, orchestration)
    end

    def smell_sections(run, smell, orchestration)
      {
        doc: orchestration.vendored_doc(smell.smell_type),
        instances: render_instances(run, smell)
      }
    end

    def non_smell_sections(finding, orchestration)
      {
        header: render_header(finding, orchestration),
        finding_context: render_finding_context(finding, orchestration),
        doc: render_doc(finding, orchestration),
        framing: FRAMING_PLACEHOLDER
      }
    end

    def render_instances(run, selected)
      groups = matching_smell_groups(run, selected)
      "## Instances\n\n#{groups.map { |path, smells| render_instance_group(path, smells) }.join("\n\n")}"
    end

    def matching_smell_groups(run, selected)
      matching = run.smells.select { |s| s.smell_type == selected.smell_type }
      matching.group_by { |s| s.location.path.raw }.sort_by { |path, smells| [-smells.size, path] }
    end

    def render_instance_group(path, smells)
      lines = smells.map { |s| "  Line #{s.location.line_start}: #{s.message}" }
      "#{path}\n#{lines.join("\n")}"
    end

    def render_header(finding, orch)
      loc = orch.describe_location(finding.location) unless finding.is_a?(DuplicationCluster)
      case finding
      when Smell
        "#{finding.smell_type.name} at #{loc}"
      when ComplexityHit
        "High complexity in #{finding.method_name} at #{loc} (score: #{finding.score.to_s('F')})"
      when DuplicationCluster
        "Structural duplication: #{finding.locations.size} locations (signature: #{finding.signature})"
      end
    end

    def render_finding_context(finding, orch)
      loc = orch.describe_location(finding.location) unless finding.is_a?(DuplicationCluster)
      case finding
      when Smell
        "#{loc}\n\n#{finding.message}"
      when ComplexityHit
        "#{loc}\n\nMethod: #{finding.method_name}\nScore: #{finding.score.to_s('F')}"
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
