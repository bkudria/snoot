module Snoot
  # RenderReport is the rule from snoot.allium that, given a Run whose
  # outcome is :finding_rendered, emits a Report describing the four
  # structural sections in declared order. Section content is the
  # responsibility of a later slice; this slice carries the structural
  # contract only.
  module RenderReport
    SECTIONS = %i[header finding_context doc framing].freeze

    Report = Data.define(:run, :finding, :sections)

    module_function

    def invoke(run)
      finding = run.selected_finding
      raise StateError, "selected_finding is required for RenderReport (got nil)" if finding.nil?

      Report.new(run: run, finding: finding, sections: SECTIONS)
    end
  end
end
