# frozen_string_literal: true

module Snoot
  module CLI
    # Event is the marker module sum-typing the two audit records the
    # CLI surface emits: RunInvoked at the entry point and
    # ReportEmitted on a finding_rendered outcome. AnalyseRun's events
    # are forwarded into the same returned list but live under a
    # parallel marker (Snoot::AnalyseRun::Event).
    module Event
    end

    # RunInvoked carries the (possibly defaulted) path set at the
    # moment the surface is entered.
    RunInvoked = Data.define(:paths) do
      include Event
    end

    # ReportEmitted carries the terminal Run, the selected Finding, and
    # the rendered sections produced by RenderReport.
    ReportEmitted = Data.define(:run, :finding, :sections) do
      include Event
    end
  end
end
