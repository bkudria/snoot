# frozen_string_literal: true

module Snoot
  module AnalyseRun
    # Result is the value returned by AnalyseRun.invoke: the terminal Run,
    # the audit events emitted along the way, and the raw smell set the
    # orchestration produced (forwarded to RenderReport so it can build
    # the per-file Instances list).
    Result = Data.define(:run, :events, :smells)
  end
end
