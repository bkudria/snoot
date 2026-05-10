# frozen_string_literal: true

module Snoot
  module AnalyseRun
    # Result is the value returned by AnalyseRun.invoke: the terminal Run,
    # the audit events emitted along the way, and the smells whose
    # smell_type matches the selected_finding's (forwarded to RenderReport
    # so it can build the per-file Instances list). matching_smells is
    # empty when the selected finding is not a Smell or no finding was
    # selected.
    Result = Data.define(:run, :events, :matching_smells)
  end
end
