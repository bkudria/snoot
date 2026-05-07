# frozen_string_literal: true

module Snoot
  # ReportReader is the surface from snoot.allium that exposes a
  # finding-rendered Run's selected_finding (and its kind) to a
  # ReportConsumer. .for returns a Reader when run.outcome is
  # :finding_rendered, or nil otherwise.
  module ReportReader
    # Reader is the view returned by ReportReader.for: a projection of
    # the surface's exposes fields (selected_finding and its kind). It
    # does not hold a reference to the underlying Run, so consumers
    # cannot reach Run fields the surface does not advertise.
    Reader = Data.define(:selected_finding, :kind)

    module_function

    def for(_consumer, run:)
      return nil unless run.outcome == :finding_rendered

      finding = run.selected_finding
      Reader.new(selected_finding: finding, kind: finding.kind)
    end
  end
end
