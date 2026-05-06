# frozen_string_literal: true

module Snoot
  # AnalyserFailure is the value type from snoot.allium surfaced on
  # outcome = analysis_failed. The `analyser` tag (one of :reek, :flog,
  # :flay) names which of the three analysers failed in canonical
  # order; `message` is the human-readable error detail carried on
  # stderr. Produced by AnalyserOrchestration#first_failure.
  AnalyserFailure = Data.define(:analyser, :message)
end
