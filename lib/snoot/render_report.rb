# frozen_string_literal: true

module Snoot
  # Given a finding_rendered Run, produces a Report. Smell findings get
  # two sections (doc, instances); ComplexityHit and DuplicationCluster
  # get three (header, finding_context, doc). Per-section content is
  # built by the helpers below.
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
      smell_type = smell.smell_type
      matching = smells.select { |s| s.smell_type == smell_type }
      {
        doc: orchestration.vendored_doc(smell_type),
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
      name = hit.method_name
      {
        header: "High complexity in #{name} at #{loc} (score: #{score})",
        finding_context: "#{loc}\n\nMethod: #{name}\nScore: #{score}",
        doc: "High complexity hits indicate a method or class doing too much. " \
             "Consider extracting helpers, simplifying conditionals, or " \
             "splitting the responsibility across smaller units."
      }
    end

    def duplication_cluster_sections(cluster)
      locations = cluster.locations
      rendered_locations = locations.map(&:description)
      {
        header: "Structural duplication: #{locations.size} locations (signature: #{cluster.signature})",
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
