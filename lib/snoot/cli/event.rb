# frozen_string_literal: true

module Snoot
  module CLI
    # RunInvoked carries the (possibly defaulted) path set at the
    # moment the surface is entered.
    RunInvoked = Data.define(:paths)

    # ReportEmitted carries the terminal Run, the selected Finding, and
    # the rendered sections produced by RenderReport.
    ReportEmitted = Data.define(:run, :finding, :sections)
  end
end
