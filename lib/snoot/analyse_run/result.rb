# frozen_string_literal: true

module Snoot
  module AnalyseRun
    # Result is the value returned by AnalyseRun.invoke: the terminal Run,
    # the audit events emitted along the way, and the smells the
    # orchestration produced (forwarded to RenderReport, which filters
    # by selected smell_type when building the per-file Instances list).
    # smells is empty when analysis failed (no Sources were produced).
    Result = Data.define(:run, :events, :smells)
  end
end
