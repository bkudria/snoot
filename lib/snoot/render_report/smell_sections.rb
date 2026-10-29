# frozen_string_literal: true

module Snoot
  module RenderReport
    # The header, instances, tuning and doc sections of a Smell report.
    module SmellSections
      module_function

      def build(smells, smell, orchestration)
        smell_type = smell.smell_type
        matching = smells.select { |instance| instance.smell_type == smell_type }
        doc = orchestration.vendored_doc(smell_type)
        {
          header: header(smell_type, matching),
          instances: instances(matching),
          tuning: tuning(smell_type, doc),
          doc: doc
        }
      end

      def header(smell_type, smells)
        instances = RenderReport.count_of(smells.size, :instance)
        files = RenderReport.count_of(smells.map { |smell| smell.location.path.raw }.uniq.size, :file)
        "#{humanize(smell_type.name)}: #{instances} across #{files}"
      end

      def humanize(pascal_case)
        pascal_case.gsub(/([a-z])([A-Z])/) { "#{Regexp.last_match(1)} #{Regexp.last_match(2).downcase}" }
      end

      def tuning(smell_type, doc)
        options_pointer = doc.include?("## Configuration") ? " (the reek doc below lists its options)" : ""
        advice = "Fix every instance, then rerun snoot. If the detector's settings don't suit this codebase, " \
                 "configure it in .reek.yml#{options_pointer}:"
        example = <<~YAML.chomp.gsub(/^/, "    ")
          detectors:
            #{smell_type.name}:
              <option>: <value>
        YAML
        "#{advice}\n\n#{example}"
      end

      def instances(smells)
        groups = groups_by_path(smells)
        "## Instances\n\n#{groups.map { |path, group| instance_group(path, group) }.join("\n\n")}"
      end

      def groups_by_path(smells)
        smells.group_by { |smell| smell.location.path.raw }
              .sort_by { |path, group| [-group.size, path] }
      end

      def instance_group(path, smells)
        lines = smells.map { |smell| "  Line #{smell.location.line_start}: #{smell.message}" }
        "#{path}\n#{lines.join("\n")}"
      end
    end
  end
end
