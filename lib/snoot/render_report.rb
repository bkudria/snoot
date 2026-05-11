# frozen_string_literal: true

module Snoot
  # RenderReport is the rule from snoot.allium that, given a Run whose
  # outcome is :finding_rendered, produces a Report. For Smell findings
  # the Report has two sections (doc, instances) -- the doc comes from
  # the orchestration's vendored_doc and instances enumerates every
  # Smell of the selected type grouped by file, ordered by descending
  # count then alphabetical path. For ComplexityHit and DuplicationCluster
  # findings the three-section shape (header, finding_context, doc) is
  # preserved.
  module RenderReport
    # Report is the value returned by RenderReport.invoke: the source
    # Run, the selected Finding it was built from, and the ordered
    # sections hash that CLI joins into stdout output.
    Report = Data.define(:run, :finding, :sections)

    module_function

    def invoke(run, smells:, orchestration:)
      finding = run.selected_finding
      sections = if finding.is_a?(Smell)
                   smell_sections(smells, finding, orchestration)
                 else
                   non_smell_sections(finding)
                 end
      Report.new(run: run, finding: finding, sections: sections)
    end

    def smell_sections(smells, smell, orchestration)
      matching = smells.select { |s| s.smell_type == smell.smell_type }
      {
        doc: orchestration.vendored_doc(smell.smell_type),
        instances: render_instances(matching)
      }
    end

    def non_smell_sections(finding)
      case finding
      when ComplexityHit then complexity_hit_sections(finding)
      when DuplicationCluster then duplication_cluster_sections(finding)
      end
    end

    def complexity_hit_sections(hit)
      loc = hit.location.description
      score = hit.score.to_s("F")
      {
        header: "High complexity in #{hit.method_name} at #{loc} (score: #{score})",
        finding_context: "#{loc}\n\nMethod: #{hit.method_name}\nScore: #{score}",
        doc: "High complexity hits indicate a method or class doing too much. " \
             "Consider extracting helpers, simplifying conditionals, or " \
             "splitting the responsibility across smaller units."
      }
    end

    def duplication_cluster_sections(cluster)
      rendered_locations = cluster.locations.map(&:description)
      {
        header: "Structural duplication: #{cluster.locations.size} locations (signature: #{cluster.signature})",
        finding_context: "Locations:\n#{rendered_locations.join("\n")}",
        doc: "Structural duplication suggests an extracted abstraction is missing. " \
             "Consider whether the duplicated shape belongs to a single helper, " \
             "module, or value type."
      }
    end

    def render_instances(smells)
      groups = smell_groups_by_path(smells)
      "## Instances\n\n#{groups.map { |path, group| render_instance_group(path, group) }.join("\n\n")}"
    end

    def smell_groups_by_path(smells)
      smells.group_by { |smell| smell.location.path.raw }
            .sort_by { |path, group| [-group.size, path] }
    end

    def render_instance_group(path, smells)
      lines = smells.map { |smell| "  Line #{smell.location.line_start}: #{smell.message}" }
      "#{path}\n#{lines.join("\n")}"
    end
  end
end
