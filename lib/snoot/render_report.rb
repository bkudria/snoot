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

    # Report is the value returned by RenderReport.invoke: the source
    # Run, the selected Finding it was built from, and the ordered
    # sections hash that CLI joins into stdout output.
    Report = Data.define(:run, :finding, :sections)

    module_function

    def invoke(run, orchestration:)
      finding = run.selected_finding
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

    def non_smell_sections(finding, _orchestration)
      {
        header: render_header(finding),
        finding_context: render_finding_context(finding),
        doc: finding.doc,
        framing: FRAMING_PLACEHOLDER
      }
    end

    def render_instances(run, selected)
      groups = matching_smell_groups(run, selected)
      "## Instances\n\n#{groups.map { |path, smells| render_instance_group(path, smells) }.join("\n\n")}"
    end

    def matching_smell_groups(run, selected)
      matching = run.smells.select { |smell| smell.smell_type == selected.smell_type }
      matching.group_by { |smell| smell.location.path.raw }
              .sort_by { |path, smells| [-smells.size, path] }
    end

    def render_instance_group(path, smells)
      lines = smells.map { |smell| "  Line #{smell.location.line_start}: #{smell.message}" }
      "#{path}\n#{lines.join("\n")}"
    end

    def render_header(finding)
      loc = finding.location.description unless finding.is_a?(DuplicationCluster)
      case finding
      when Smell
        "#{finding.smell_type.name} at #{loc}"
      when ComplexityHit
        "High complexity in #{finding.method_name} at #{loc} (score: #{finding.score.to_s('F')})"
      when DuplicationCluster
        "Structural duplication: #{finding.locations.size} locations (signature: #{finding.signature})"
      end
    end

    def render_finding_context(finding)
      loc = finding.location.description unless finding.is_a?(DuplicationCluster)
      case finding
      when Smell
        "#{loc}\n\n#{finding.message}"
      when ComplexityHit
        "#{loc}\n\nMethod: #{finding.method_name}\nScore: #{finding.score.to_s('F')}"
      when DuplicationCluster
        rendered = finding.locations.map(&:description)
        "Locations:\n#{rendered.join("\n")}"
      end
    end
  end
end
